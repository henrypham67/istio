resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      "topology.istio.io/network" = "istio-system"
    }
  }
}

resource "kubernetes_secret" "cert-manager-vault-token_2" {
  metadata {
    name      = "cert-manager-vault-token"
    namespace = kubernetes_namespace_v1.istio_system.metadata[0].name
  }
  data = {
    "token" = "root"
  }
}

resource "kubernetes_manifest" "vault_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Issuer"
    "metadata" = {
      "name"      = "vault"
      "namespace" = kubernetes_namespace_v1.istio_system.metadata[0].name
    }
    "spec" = {
      "vault" = {
        "server" = "http://${var.vault_dns}:8200"
        "path"   = "pki_int1_istio-cluster1/sign/istio-ca-istio-cluster1"
        "auth" = {
          "tokenSecretRef" = {
            "name" = "cert-manager-vault-token"
            "key"  = "token"
          }
        }
      }
    }
  }
}

resource "helm_release" "istio_csr" {
  depends_on = [kubernetes_manifest.vault_issuer]
  chart      = "cert-manager-istio-csr"
  repository = "https://charts.jetstack.io"
  name       = "cert-manager-istio-csr"
  version    = "0.14.0"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  values = [
    templatefile("values/istio_csr.yaml", {
      CLUSTER_ID = var.cluster_name
    })
  ]
  timeout  = 600
}

resource "helm_release" "istio_base" {
  chart      = "base"
  version    = "1.25.1"
  name       = "istio-base"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  repository = "https://istio-release.storage.googleapis.com/charts"
}

# Control Plane
resource "helm_release" "istiod" {
  depends_on = [helm_release.istio_base]
  chart      = "istiod"
  version    = "1.25.1"
  repository = "https://istio-release.storage.googleapis.com/charts"
  name       = "istiod"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name

  values = [templatefile("values/istio.yaml", {
    CLUSTER_NAME = var.cluster_name
  })]
}

resource "helm_release" "istio_eastwestgateway" {
  depends_on = [helm_release.istiod]
  chart      = "gateway"
  version    = "1.25.1"
  repository = "https://istio-release.storage.googleapis.com/charts"
  name       = "istio-eastwestgateway"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name

  values = [
    yamlencode({
      labels = {
        istio                       = "eastwestgateway"
        app                         = "istio-eastwestgateway"
        "topology.istio.io/network" = var.cluster_name
      }
      env = {
        "ISTIO_META_REQUESTED_NETWORK_VIEW" = var.cluster_name
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
        }
        ports = [
          {
            name       = "tls"
            port       = 15443
            targetPort = 15443
          }
        ]
      }
    })
  ]
}