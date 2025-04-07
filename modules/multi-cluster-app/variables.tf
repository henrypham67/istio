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