output "istio_gateway_dns" {
  description = "DNS name of the Istio gateway load balancer"
  value       = data.aws_lb.istio_gateway.dns_name
}

output "argocd_release_name" {
  description = "Name of the ArgoCD Helm release"
  value       = helm_release.argocd.name
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}