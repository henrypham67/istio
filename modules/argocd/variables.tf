# modules/argocd/variables.tf

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
}

variable "argocd_helm_values" {
  description = "List of values in raw yaml to pass to ArgoCD Helm chart"
  type        = list(string)
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "app_of_apps_name" {
  description = "Name of the ArgoCD App of Apps"
  type        = string
  default     = "observability"
}

variable "app_of_apps_path" {
  description = "Path in the Git repo for the App of Apps"
  type        = string
  default     = "observability/argo/apps"
}

variable "app_of_apps_namespace" {
  description = "Destination namespace for the App of Apps"
  type        = string
  default     = "observability"
}

variable "istio_gateway" {
  description = "Istio gateway Helm release resource for dependency"
  type        = any
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}