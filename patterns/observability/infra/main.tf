module "cluster" {
  source = "../../../modules/eks"

  name     = var.cluster_name
  vpc_cidr = "10.1.0.0/16"
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
              name       = "http"
              port       = 80
              targetPort = 80
            }
          ]
        }
      }
    )
  ]
}

# resource "helm_release" "kiali" {
#   depends_on       = [module.cluster]
#   chart            = "kiali-operator"
#   name             = "kiali-operator-and-server"
#   repository       = "https://kiali.org/helm-charts"
#   namespace        = "observability"
#   create_namespace = true
#
#   values = [file("values/kiali.yaml")]
# }
#
# resource "helm_release" "elasticsearch" {
#   depends_on       = [module.cluster]
#   chart            = "elasticsearch"
#   name             = "elasticsearch"
#   repository       = "https://helm.elastic.co"
#   namespace        = "observability"
#   create_namespace = true
#   values           = [file("values/es.yaml")]
# }
#
# resource "helm_release" "fluentd" {
#   depends_on       = [module.cluster]
#   chart            = "fluentd"
#   name             = "fluentd"
#   repository       = "https://fluent.github.io/helm-charts"
#   namespace        = "observability"
#   create_namespace = true
# }
#
# resource "helm_release" "kibana" {
#   depends_on       = [module.cluster, helm_release.elasticsearch]
#   chart            = "kibana"
#   name             = "kibana"
#   repository       = "https://helm.elastic.co"
#   namespace        = "observability"
#   create_namespace = true
#   values           = [file("values/kibana.yaml")]
# }
#
# resource "helm_release" "kube-prometheus-stack" {
#   depends_on       = [module.cluster]
#   chart            = "kube-prometheus-stack"
#   name             = "kube-prometheus-stack"
#   repository       = "https://prometheus-community.github.io/helm-charts"
#   namespace        = "observability"
#   create_namespace = true
# }

# resource "helm_release" "mimir" {
#   depends_on       = [module.cluster]
#   chart            = "mimir-distributed"
#   name             = "mimnir"
#   repository       = "https://grafana.github.io/helm-charts"
#   namespace        = "observability"
#   create_namespace = true
# }

resource "helm_release" "argocd" {
  depends_on       = [module.cluster]
  chart            = "argo-cd"
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = "argocd"
  create_namespace = true

  values = [file("values/argocd.yaml")]
}

resource "kubectl_manifest" "gateway" {
  depends_on = [helm_release.istio_gateway, helm_release.argocd]
  yaml_body  = <<YAML
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*"
YAML
}

resource "kubectl_manifest" "virtual_service" {
  depends_on = [helm_release.argocd]
  yaml_body  = <<YAML
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd
  namespace: argocd
spec:
  hosts:
    - "*"
  gateways:
    - istio-system/argocd-gateway
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: argo-cd-argocd-server.argocd.svc.cluster.local
            port:
              number: 80
YAML
}

# resource "kubectl_manifest" "virtual_service_grafana" {
#   depends_on = [helm_release.istio_gateway, helm_release.argocd]
#   yaml_body  = <<YAML
# apiVersion: networking.istio.io/v1beta1
# kind: VirtualService
# metadata:
#   name: grafana
#   namespace: observability
# spec:
#   hosts:
#     - "*"
#   gateways:
#     - istio-system/argocd-gateway
#   http:
#     - match:
#         - uri:
#             prefix: /
#       route:
#         - destination:
#             host: kube-prometheus-stack-grafana.observability.svc.cluster.local
#             port:
#               number: 80
# YAML
# }