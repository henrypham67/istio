resource "kubectl_manifest" "cert-manager-vault-token" {
  count = var.enable_cert_manager ? 1 : 0

  depends_on = [module.eks]
  yaml_body  = <<YAML
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: cert-manager-vault-token
  namespace: istio-system
data:
  token: ${base64encode("root")}
YAML
}

resource "kubectl_manifest" "vault_issuer" {
  count = var.enable_cert_manager ? 1 : 0

  depends_on = [module.eks_blueprints_addons.cert_manager, vault_pki_secret_backend_role.istio_ca]
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault
  namespace: istio-system
spec:
  vault:
    server: http://${var.vault_dns_name}:8200
    path: pki_int_istio-${var.name}/sign/istio-ca
    auth:
      tokenSecretRef:
        name: cert-manager-vault-token
        key: token
YAML
}

# resource "helm_release" "istio_csr" {
#   count = var.enable_cert_manager ? 1 : 0
#
#   depends_on = [modules.eks_blueprints_addons]
#   chart      = "cert-manager-istio-csr"
#   name       = "istio-csr"
#   repository = "https://charts.jetstack.io"
#   version    = "0.14.0"
#   wait       = true
#   namespace  = "istio-system"
#
#   values = [
#     templatefile("values/istio_csr.yaml", {
#       CLUSTER_ID = var.name
#     })
#   ]
# }