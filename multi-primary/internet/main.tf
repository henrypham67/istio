variable "cluster_1" {
  type    = string
  default = "cluster-1"
}

variable "cluster_2" {
  type    = string
  default = "cluster-2"
}

variable "vpc_cidr_block_1" {
  type    = string
  default = "10.1.0.0/16"
}

variable "vpc_cidr_block_2" {
  type    = string
  default = "10.2.0.0/16"
}

module "cluster_1" {
  source = "../../modules/eks-with-istio"

  vpc_cidr = var.vpc_cidr_block_1
  name     = var.cluster_1
}

module "multi_cluster_app_1" {
  source = "../../modules/multi-cluster-app"

  other_cluster_certificate_authority_data = module.cluster_2.certificate_authority_data
  other_cluster_endpoint                   = module.cluster_2.cluster_endpoint
  other_cluster_name                       = module.cluster_2.cluster_name

  providers = {
    helm    = helm.helm_1
    kubectl = kubectl.kubectl_1
  }
}

module "cluster_2" {
  source = "../../modules/eks-with-istio"

  vpc_cidr = var.vpc_cidr_block_2
  name     = var.cluster_2

  providers = {
    aws = aws.us_west_2
  }
}

module "multi_cluster_app_2" {
  source = "../../modules/multi-cluster-app"

  other_cluster_certificate_authority_data = module.cluster_1.certificate_authority_data
  other_cluster_endpoint                   = module.cluster_1.cluster_endpoint
  other_cluster_name                       = module.cluster_1.cluster_name

  providers = {
    helm    = helm.helm_2
    kubectl = kubectl.kubectl_2
  }
}