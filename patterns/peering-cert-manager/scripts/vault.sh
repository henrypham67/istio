#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#—— CONFIG —————————————————————————————————————————————————————————
AWS_REGION="us-east-1"
VAULT_PORT=8200
ROOT_TTL="87600h"       # 10 years
INT_TTL="43800h"        # 5 years
ROLE_TTL="72h"          # 3 days
ROLE_DOMAINS="istio-ca"
ROLE_URI_SANS="spiffe://*"
CLUSTERS=( "cluster1" "cluster2" )
#———————————————————————————————————————————————————————————————

#—— DEPENDENCY CHECK ——————————————————————————————————————————————
for cmd in aws vault jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' not found in PATH. Aborting." >&2
    exit 1
  }
done

#—— HELPER LOGGING ——————————————————————————————————————————————
log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

#—— DISCOVER VAULT ADDRESS ————————————————————————————————————————
log "Fetching ELB DNS name..."
VAULT_DNS=$(aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)
export VAULT_ADDR="http://${VAULT_DNS}:${VAULT_PORT}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"
log "Using VAULT_ADDR=$VAULT_ADDR"

#—— ROOT CA SETUP ————————————————————————————————————————————————
log "Enabling PKI at path pki_root..."
vault secrets enable -path=pki_root pki
vault secrets tune -max-lease-ttl="$ROOT_TTL" pki_root

log "Generating internal Root CA (TTL=$ROOT_TTL)..."
vault write -field=certificate pki_root/root/generate/internal \
    common_name="Root CA" ttl="$ROOT_TTL" \
  > CA_cert.crt

log "Configuring issuing and CRL URLs..."
vault write pki_root/config/urls \
    issuing_certificates="http://${VAULT_DNS}:${VAULT_PORT}/v1/pki_root/ca" \
    crl_distribution_points="http://${VAULT_DNS}:${VAULT_PORT}/v1/pki_root/crl"

#—— INTERMEDIATE CA FUNCTION ——————————————————————————————————————
create_intermediate() {
  local cluster="$1"
  local path="pki_int1_istio-${cluster}"
  local csr_file="pki_intermediate1_istio_${cluster}.csr"
  local cert_file="intermediate1_istio_${cluster}.cert.pem"
  local chain_file="intermediate1_istio_${cluster}.chain.pem"
  local role_name="istio-ca-istio-${cluster}"

  log "=== Bootstrapping intermediate CA for ${cluster} ==="

  vault secrets enable -path="$path" pki
  vault secrets tune -max-lease-ttl="$INT_TTL" "$path"

  log "Generating CSR for ${path}..."
  vault write -format=json \
      "${path}/intermediate/generate/internal" \
      common_name="CA intermediate 1" \
    | jq -r '.data.csr' > "$csr_file"

  log "Signing CSR with root CA..."
  vault write -format=json \
      pki_root/root/sign-intermediate \
      csr=@"$csr_file" format=pem ttl="$INT_TTL" \
    | jq -r '.data.certificate' > "$cert_file"

  log "Building full certificate chain..."
  cat "$cert_file" > "$chain_file"
  cat CA_cert.crt >> "$chain_file"

  log "Importing signed intermediate chain into ${path}..."
  vault write "${path}/intermediate/set-signed" \
      certificate=@"$chain_file"

  log "Creating role ${role_name}..."
  vault write "${path}/roles/${role_name}" \
      allowed_domains="$ROLE_DOMAINS" \
      allow_any_name=true \
      enforce_hostnames=false \
      require_cn=false \
      allowed_uri_sans="$ROLE_URI_SANS" \
      max_ttl="$ROLE_TTL"

  log "Intermediate for ${cluster} complete."
}

#—— BOOTSTRAP ALL CLUSTERS ————————————————————————————————————————
for c in "${CLUSTERS[@]}"; do
  create_intermediate "$c"
done

log "All done!"
