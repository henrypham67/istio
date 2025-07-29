# modules/argocd/main.tf

data "aws_lb" "istio_gateway" {
  depends_on = [var.istio_gateway]
  name       = "istio-gateway-lb"
}

resource "helm_release" "argocd" {
  chart            = "argo-cd"
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = var.argocd_namespace
  create_namespace = true

  values = var.argocd_helm_values
}

resource "argocd_application" "app_of_apps" {
  depends_on = [helm_release.argocd]

  metadata {
    name      = var.app_of_apps_name
    namespace = var.argocd_namespace
  }

  spec {
    project = "default"

    source {
      repo_url        = var.git_repo_url
      path            = var.app_of_apps_path
      target_revision = "HEAD"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = var.app_of_apps_namespace
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}

resource "kubectl_manifest" "gateway" {
  depends_on = [var.istio_gateway, helm_release.argocd]

  yaml_body = <<YAML
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: shared-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 5000
        name: grafana
        protocol: HTTP
      hosts:
        - "${data.aws_lb.istio_gateway.dns_name}"
    - port:
        number: 80
        name: argocd
        protocol: HTTP
      hosts:
        - "${data.aws_lb.istio_gateway.dns_name}"
    - port:
        number: 8080
        name: test-app
        protocol: HTTP
      hosts:
        - "${data.aws_lb.istio_gateway.dns_name}"
YAML
}

resource "kubectl_manifest" "virtual_service" {
  depends_on = [helm_release.argocd]

  yaml_body = <<YAML
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: argocd
  namespace: argocd
spec:
  hosts:
    - "*"
  gateways:
    - istio-system/shared-gateway
  http:
    - match:
        - port: 80
      route:
        - destination:
            host: argo-cd-argocd-server.argocd.svc.cluster.local
            port:
              number: 80
YAML
}