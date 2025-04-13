variable "cluster_version" {
  type    = string
  default = "1.32"
}

variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "is_internet_ew_gateway" {
  description = "Whether the Istio east-west gateway should be internet-facing (true) or private/internal (false)"
  type        = bool
  default     = true
}