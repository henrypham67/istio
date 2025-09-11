variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "max_nodes" {
  type    = number
  default = 5
}

variable "min_nodes" {
  type    = number
  default = 2
}

variable "desired_nodes" {
  type    = number
  default = 3
}

variable "instance_type" {
  type    = string
  default = "t4g.medium"
}