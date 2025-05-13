resource "helm_release" "vault" {
  depends_on = [module.cluster_1]
  name       = "vault"
  namespace  = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.30.0" # Check for latest version

  create_namespace = true

  values = [
    file("${path.module}/values/vault.yaml")
  ]

  timeout  = 600
  provider = helm.helm_1
}

# data "aws_lb" "vault" {
#   depends_on = [helm_release.vault]
#   name       = "vault-lb"
# }
#
# output "vault_lb_dns_name" {
#   value = data.aws_lb.vault.dns_name
# }

# provider "vault" {
#   address = "http://${data.aws_lb.vault.dns_name}:8200"
#   token   = "root"
# }
#
# resource "vault_mount" "pki_root" {
#   provider    = vault
#   path        = "pki_root"
#   type        = "pki"
#   description = "Root PKI"
# }
#
# resource "vault_pki_secret_backend_root_cert" "root_ca" {
#   depends_on  = [vault_mount.pki_root]
#   backend     = vault_mount.pki_root.path
#   type        = "internal"
#   common_name = "Root CA"
# }
#
# # Configure URLs
# resource "vault_pki_secret_backend_config_urls" "pki_urls" {
#   backend = vault_mount.pki_root.path
#
#   issuing_certificates    = ["${data.aws_lb.vault.dns_name}:8200/v1/pki_root/ca"]
#   crl_distribution_points = ["${data.aws_lb.vault.dns_name}:8200/v1/pki_root/crl"]
# }
