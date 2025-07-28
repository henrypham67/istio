variable "cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "git_argocd_repo_url" {
  type    = string
  default = "https://github.com/henrypham67/istio"
}

variable "mimir_bucket_name" {
  description = "Name of the S3 bucket for Mimir storage"
  type        = string
  default     = "my-mimir-bucket-199907060500"
}

variable "istio_ns" {
  default = "istio-system"
}
