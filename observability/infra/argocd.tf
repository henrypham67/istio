resource "argocd_application" "app_of_apps" {
  depends_on = [helm_release.argocd]
  metadata {
    name      = "observability"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = var.git_argocd_repo_url
      path            = "observability/argo/apps"
      target_revision = "HEAD"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "observability"
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}

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

YAML
}

resource "kubectl_manifest" "virtual_service" {
  depends_on = [helm_release.argocd]
  yaml_body  = <<YAML
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

output "istio_gateway_dns" {
  value = data.aws_lb.istio_gateway.dns_name
}
