#!/bin/bash
set -euo pipefail

terraform init

terraform apply --auto-approve \
  -target=module.cluster_1 \
  -target=module.cluster_2

echo "Waiting for AWS Load Balancer to be provisioned..."

# Replace these with your values
LB_NAME_PREFIX="vault-lb"   # or any prefix used in the Kubernetes service
REGION="us-east-1"       # your AWS region

wait_for_lb() {
  local name_prefix=$1
  local timeout=300
  local interval=30
  local elapsed=0

  while true; do
    lb_arn=$(aws elbv2 describe-load-balancers \
      --region "$REGION" \
      --query "LoadBalancers[?contains(LoadBalancerName, \`$name_prefix\`)].LoadBalancerArn" \
      --output text)

    if [[ -n "$lb_arn" ]]; then
      echo "Load balancer found: $lb_arn"
      break
    fi

    if (( elapsed >= timeout )); then
      echo "Timeout waiting for Load Balancer."
      exit 1
    fi

    echo "Waiting for Load Balancer to appear... ($elapsed/$timeout)"
    sleep "$interval"
    ((elapsed+=interval))
  done

  # Wait for the LB to be active
  elapsed=0
  while true; do
    lb_state=$(aws elbv2 describe-load-balancers \
      --load-balancer-arns "$lb_arn" \
      --region "$REGION" \
      --query "LoadBalancers[0].State.Code" \
      --output text)

    if [[ "$lb_state" == "active" ]]; then
      echo "Load Balancer is active."
      break
    fi

    if (( elapsed >= timeout )); then
      echo "Timeout waiting for Load Balancer to become active."
      exit 1
    fi

    echo "Waiting for Load Balancer to become active... ($elapsed/$timeout)"
    sleep "$interval"
    ((elapsed+=interval))
  done
}

terraform apply --auto-approve -target helm_release.vault

echo "Waiting for Vault Load Balancer to be ready..."
wait_for_lb "$LB_NAME_PREFIX"  # You might need to refine the prefix if it's a different LB

source .scripts/vault.sh

terraform apply --auto-approve

echo """
  A sample app has been deploy in both clusters
  Run ../../scripts/check-cross-cluster-sync.sh to test the connectivity
"""
