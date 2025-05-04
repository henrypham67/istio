variable "other_cluster_name" {
  description = "The name of the Aurora cluster to create"
  type        = string
}

variable "other_cluster_certificate_authority_data" {
  description = "The base64-encoded certificate data required to communicate with your cluster"
  type        = string
}

variable "other_cluster_endpoint" {
  description = "The endpoint to connect to spec. Should not be recording to the cluster"
  type        = string
}

variable "service_account_token" {
  description = "The token used to authenticate the service account token for using encryption"
  type        = string
  sensitive   = true
}

variable "app_version" {
  description = "The version deployed together"
  type        = string
  default     = "v2"
}