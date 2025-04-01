variable "cluster_version" {
  type    = string
  default = "1.32"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}