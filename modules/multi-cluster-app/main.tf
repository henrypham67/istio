locals {
  namespace = "sample"
}

resource "kubectl_manifest" "sample_namespace" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.namespace}
  labels:
    istio-injection: "enabled"
YAML
}

resource "helm_release" "multicluster_gateway_n_apps" {
  name       = "multicluster-gateway-n-apps"
  repository = "${path.module}/charts"
  namespace  = local.namespace
  chart      = "multicluster-gateway-n-apps"

  set {
    name  = "version"
    value = var.app_version
  }

  set {
    name  = "clusterName"
    value = var.other_cluster_name
  }

  set {
    name  = "certificateAuthorityData"
    value = var.other_cluster_certificate_authority_data
  }

  set {
    name  = "server"
    value = var.other_cluster_endpoint
  }

  set {
    name  = "token"
    value = var.service_account_token
  }
}