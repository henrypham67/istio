module "cluster" {
  source = "../../modules/eks"

  name     = var.cluster_name
  vpc_cidr = "10.1.0.0/16"

  desired_nodes = 6
  max_nodes = 6
}

resource "helm_release" "istio_base" {
  depends_on       = [module.cluster]
  chart            = "base"
  version          = "1.25.1"
  name             = "istio-base"
  namespace        = "istio-system"
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
  namespace        = "istio-system"
  create_namespace = true

  values = [templatefile("values/istio.yaml", {
    CLUSTER_NAME = var.cluster_name
  })]
}

resource "helm_release" "istio_gateway" {
  depends_on       = [helm_release.istiod]
  chart            = "gateway"
  version          = "1.25.1"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  name             = "istio-ingress"
  namespace        = "istio-system"
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
            }
          ]
        }
      }
    )
  ]
}
