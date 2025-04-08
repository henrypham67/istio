#!/bin/bash

set -e

export CTX_CLUSTER1=`aws eks describe-cluster --name $CLUSTER1 --region us-east-1 | jq -r '.cluster.arn'`
export CTX_CLUSTER2=`aws eks describe-cluster --name $CLUSTER2 --region us-west-2 | jq -r '.cluster.arn'`

cross_cluster_sync() {
    ctx=$1
    POD_NAME=$(kubectl get pod --context=$ctx -l app=sleep -o jsonpath='{.items[0].metadata.name}' -n sample)
    istioctl --context $ctx proxy-config endpoint $POD_NAME -n sample | grep helloworld
}

for ctx in $CTX_CLUSTER1 $CTX_CLUSTER2
do
    printf "Cross cluster sync check for $ctx:"
    cross_cluster_sync $ctx
done