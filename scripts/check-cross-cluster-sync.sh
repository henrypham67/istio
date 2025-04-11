#!/bin/bash

set -e

# Setup kubecontexts from AWS EKS clusters
export CTX_CLUSTER1=$(aws eks update-kubeconfig --name "$CLUSTER1" --region us-east-1 --alias "$CLUSTER1" 2>&1 >/dev/null; echo "$CLUSTER1")
export CTX_CLUSTER2=$(aws eks update-kubeconfig --name "$CLUSTER2" --region us-west-2 --alias "$CLUSTER2" 2>&1 >/dev/null; echo "$CLUSTER2")

cross_cluster_test() {
    ctx=$1
    echo "📦 Checking cross-cluster service discovery for context: $ctx"

    POD_NAME=$(kubectl get pod --context="$ctx" -l app=sleep -n sample -o jsonpath='{.items[0].metadata.name}')

    echo "🔍 Verifying remote endpoints in Envoy config..."
    istioctl --context="$ctx" proxy-config endpoint "$POD_NAME" -n sample | grep helloworld || echo "❌ Endpoint not found"

    echo "🌐 Testing actual cross-cluster connectivity..."
    for _ in {1..5}; do
      kubectl --context="$ctx" exec -n sample "$POD_NAME" -- curl -sS helloworld.sample:5000/hello
    done
}

# Run checks for both clusters
for ctx in $CTX_CLUSTER1 $CTX_CLUSTER2; do
    echo "====================="
    cross_cluster_test "$ctx"
    echo
done