variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "mimir_bucket_name" {
  description = "Name of the S3 bucket for Mimir storage"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring"
  type        = string
  default     = "monitoring"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for Mimir"
  type        = string
  default     = "mimir-sa"
}

variable "force_destroy" {
  description = "Force destroy the S3 bucket on deletion"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "iam_policy_name" {
  description = "Name of the IAM policy for Mimir S3 access"
  type        = string
  default     = "MimirS3Access" # Matches your original
}

variable "iam_role_name" {
  description = "Name of the IAM role for Mimir pod identity"
  type        = string
  default     = "MimirPodIdentityRole" # Matches your original
}