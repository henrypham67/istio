
resource "vault_mount" "pki_int" {
  count = var.enable_cert_manager ? 1 : 0

  provider    = vault
  path        = "pki_int_istio-${var.name}"
  type        = "pki"
  description = "Intermediate PKI"
}

resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate_ca_csr" {
  count = var.enable_cert_manager ? 1 : 0

  backend     = vault_mount.pki_int[0].path
  common_name = "Intermediate CA Cert for ${var.name}"
  type        = "internal"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "signed_ca" {
  count = var.enable_cert_manager ? 1 : 0

  backend     = var.vault_pki_root_path
  csr         = vault_pki_secret_backend_intermediate_cert_request.intermediate_ca_csr[0].csr
  common_name = "Intermediate CA Cert for ${var.name}"
  ttl         = 87600
}

resource "vault_pki_secret_backend_intermediate_set_signed" "submit" {
  count = var.enable_cert_manager ? 1 : 0

  backend     = vault_mount.pki_int[0].path
  certificate = vault_pki_secret_backend_root_sign_intermediate.signed_ca[0].certificate_bundle
}

# Create a PKI Role (used by cert-manager or Istio)
resource "vault_pki_secret_backend_role" "istio_ca" {
  count = var.enable_cert_manager ? 1 : 0

  backend           = vault_mount.pki_int[0].path
  name              = "istio-ca"
  allowed_domains   = ["istio-ca"]
  allow_any_name    = true
  require_cn        = false
  enforce_hostnames = false
  allowed_uri_sans  = ["spiffe://*"]
}