variable "cluster_1" {
  type = string
}

variable "cluster_2" {
  type = string
}

module "cluster_1" {
  source = "./eks-with-istio"

  vpc_cidr = "10.1.0.0/16"
  name     = var.cluster_1
}

module "cluster_2" {
  source = "./eks-with-istio"

  vpc_cidr = "10.2.0.0/16"
  name     = var.cluster_2
}

resource "aws_vpc_peering_connection" "foo" {
  peer_owner_id = module.cluster_1.vpc_owner_id
  peer_vpc_id   = module.cluster_1.vpc_id
  vpc_id        = module.cluster_2.vpc_id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between ${var.cluster_1} and ${var.cluster_2}"
  }
}
