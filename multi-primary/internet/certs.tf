# --- Local values to reduce duplication ---
locals {
  intermediate_ca_common_name = "intermediate.multicluster.istio.io"
  root_ca_common_name         = "multicluster.istio.io"
  validity_hours              = 87600

  ca_cert_pem    = tls_locally_signed_cert.intermediate_ca_cert.cert_pem
  ca_key_pem     = tls_private_key.intermediate_ca_key.private_key_pem
  root_cert_pem  = tls_self_signed_cert.root_ca.cert_pem
  cert_chain_pem = format("%s\n%s", local.ca_cert_pem, local.root_cert_pem)

  cacerts_data_encoded = {
    ca-cert.pem    = base64encode(local.ca_cert_pem)
    ca-key.pem     = base64encode(local.ca_key_pem)
    root-cert.pem  = base64encode(local.root_cert_pem)
    cert-chain.pem = base64encode(local.cert_chain_pem)
  }

  # Helper to render the secret in YAML
  render_cacerts_yaml = templatefile("${path.root}/templates/cacerts-secret.yaml.tpl", {
    data = local.cacerts_data_encoded
  })
}

# --- Root CA ---
resource "tls_private_key" "root_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "root_ca" {
  private_key_pem   = tls_private_key.root_ca_key.private_key_pem
  is_ca_certificate = true

  subject {
    common_name = local.root_ca_common_name
  }

  validity_period_hours = local.validity_hours

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

# --- Intermediate CA ---
resource "tls_private_key" "intermediate_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "intermediate_ca_csr" {
  private_key_pem = tls_private_key.intermediate_ca_key.private_key_pem

  subject {
    common_name = local.intermediate_ca_common_name
  }
}

resource "tls_locally_signed_cert" "intermediate_ca_cert" {
  cert_request_pem   = tls_cert_request.intermediate_ca_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = local.validity_hours
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
    "cert_signing",
  ]
}

# --- Apply Secret to Cluster 1 ---
resource "kubectl_manifest" "cacerts_cluster_1" {
  yaml_body = local.render_cacerts_yaml
  provider  = kubectl.kubectl_1
}

# --- Apply Secret to Cluster 2 ---
resource "kubectl_manifest" "cacerts_cluster_2" {
  yaml_body = local.render_cacerts_yaml
  provider  = kubectl.kubectl_2
}
