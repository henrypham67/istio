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

  providers = {
    aws = aws
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

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = module.cluster_1.vpc_id
  peer_vpc_id   = module.cluster_2.vpc_id
  peer_owner_id = module.cluster_2.vpc_owner_id
  peer_region   = "us-west-2"
  auto_accept   = false

  tags = {
    Name = "VPC Peering between ${var.cluster_1} and ${var.cluster_2}"
    Side = "Requester"
  }
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.us_west_2
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true

  tags = {
    Name = "VPC Peering between ${var.cluster_1} and ${var.cluster_2}"
    Side = "Accepter"
  }
}

# Requester side - set from default provider (assumed to be us-east-1)
resource "aws_vpc_peering_connection_options" "requester" {
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

# Accepter side - set from aws.us_west_2 provider
resource "aws_vpc_peering_connection_options" "accepter" {
  provider                  = aws.us_west_2
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "cluster-1_cluster-2" {
  route_table_id            = module.cluster_1.private_route_table_ids[0]
  destination_cidr_block    = var.vpc_cidr_block_2
  vpc_peering_connection_id = aws_vpc_peering_connection_options.requester.id
}

resource "aws_route" "cluster-2_cluster-1" {
  route_table_id            = module.cluster_2.private_route_table_ids[0]
  destination_cidr_block    = var.vpc_cidr_block_1
  vpc_peering_connection_id = aws_vpc_peering_connection_options.accepter.id

  provider = aws.us_west_2
}
