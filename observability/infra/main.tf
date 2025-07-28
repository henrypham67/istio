module "cluster" {
  source = "../../modules/eks"

  name     = var.cluster_name
  vpc_cidr = "10.1.0.0/16"

  desired_nodes = 5
  max_nodes     = 9
}

resource "helm_release" "istio_base" {
  depends_on       = [module.cluster]
  chart            = "base"
  version          = "1.25.1"
  name             = "istio-base"
  namespace        = var.istio_ns
  repository       = "https://istio-release.storage.googleapis.com/charts"
  create_namespace = true
}

# Control Plane
resource "helm_release" "istiod" {
  depends_on       = [module.cluster, helm_release.istio_base]
  chart            = "istiod"
  version          = "1.25.1"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  name             = "istiod"
  namespace        = var.istio_ns
  create_namespace = true

  values = [templatefile("values/istio.yaml", {
    CLUSTER_NAME = var.cluster_name
    ISTIO_NS = var.istio_ns
  })]
}

resource "helm_release" "istio_gateway" {
  depends_on       = [helm_release.istiod]
  chart            = "gateway"
  version          = "1.25.1"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  name             = "istio-ingress"
  namespace        = var.istio_ns
  create_namespace = true

  values = [
    yamlencode(
      {
        labels = {
          istio = "ingressgateway"
        }
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
            "service.beta.kubernetes.io/aws-load-balancer-name"            = "istio-gateway-lb"

          }
          ports = [
            {
              name       = "tls-istiod"
              port       = 15012
              targetPort = 15012
            },
            {
              name       = "tls-webhook"
              port       = 15017
              targetPort = 15017
            },
            {
              name       = "argocd"
              port       = 80
              targetPort = 80
            },
            {
              name       = "grafana"
              port       = 5000
              targetPort = 5000
            },
            {
              name       = "kiali"
              port       = 6000
              targetPort = 6000
            },
            {
              name       = "test-app"
              port       = 8080
              targetPort = 8080
            }
          ]
        }
      }
    )
  ]
}

module "mimir" {
  source = "../../modules/mimir"

  cluster_name      = var.cluster_name
  mimir_bucket_name = var.mimir_bucket_name
}

module "argocd" {
  source     = "../../modules/argocd"
  depends_on = [helm_release.istio_gateway]

  git_repo_url       = var.git_argocd_repo_url
  argocd_helm_values = [file("values/argocd.yaml")]
  istio_gateway      = helm_release.istio_gateway
}
