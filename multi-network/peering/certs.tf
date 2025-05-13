resource "tls_private_key" "intermediate_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "intermediate_ca_csr" {
  private_key_pem = tls_private_key.intermediate_ca_key.private_key_pem

  subject {
    common_name = "intermediate.multicluster.istio.io"
  }
}

resource "tls_locally_signed_cert" "intermediate_ca_cert" {
  cert_request_pem   = tls_cert_request.intermediate_ca_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = 87600
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
    "cert_signing",
  ]
}

resource "tls_private_key" "root_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "root_ca" {
  private_key_pem   = tls_private_key.root_ca_key.private_key_pem
  is_ca_certificate = true

  subject {
    common_name = "multicluster.istio.io"
  }

  validity_period_hours = 87600

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "code_signing",
    "server_auth",
    "client_auth",
    "digital_signature",
    "key_encipherment",
  ]
}

resource "kubectl_manifest" "cacerts_cluster_1" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: cacerts
  namespace: istio-system
type: Opaque
data:
  ca-cert.pem: "${base64encode(tls_locally_signed_cert.intermediate_ca_cert.cert_pem)}"
  ca-key.pem: "${base64encode(tls_private_key.intermediate_ca_key.private_key_pem)}"
  root-cert.pem: "${base64encode(tls_self_signed_cert.root_ca.cert_pem)}"
  cert-chain.pem: "${base64encode(format("%s\n%s", tls_locally_signed_cert.intermediate_ca_cert.cert_pem, tls_self_signed_cert.root_ca.cert_pem))}"
YAML

  provider = kubectl.kubectl_1
}

resource "kubectl_manifest" "cacerts_cluster_2" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: cacerts
  namespace: istio-system
type: Opaque
data:
  ca-cert.pem: "${base64encode(tls_locally_signed_cert.intermediate_ca_cert.cert_pem)}"
  ca-key.pem: "${base64encode(tls_private_key.intermediate_ca_key.private_key_pem)}"
  root-cert.pem: "${base64encode(tls_self_signed_cert.root_ca.cert_pem)}"
  cert-chain.pem: "${base64encode(format("%s\n%s", tls_locally_signed_cert.intermediate_ca_cert.cert_pem, tls_self_signed_cert.root_ca.cert_pem))}"
YAML

  provider = kubectl.kubectl_2
}