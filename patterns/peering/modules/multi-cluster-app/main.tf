resource "kubernetes_namespace_v1" "sample" {
  metadata {
    name = "sample"
  }
}

resource "helm_release" "multicluster_gateway_n_apps" {
  name       = "multicluster-gateway-n-apps"
  repository = "${path.module}/charts"
  namespace  = kubernetes_namespace_v1.sample.metadata.name
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