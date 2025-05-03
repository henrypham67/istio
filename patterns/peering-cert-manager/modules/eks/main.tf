locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  istio_chart_url     = "https://istio-release.storage.googleapis.com/charts"
  istio_chart_version = "1.25.1"

  istio_system_ns = {
    name = "istio-system"
  }

  tags = {
    Blueprint  = var.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

################################################################################
# Cluster
################################################################################
module "eks" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.35"

  cluster_name                   = var.name
  cluster_version                = "1.32"
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    worker_nodes = { # node group name
      ami_type      = "AL2_x86_64"
      instance_type = "t3.medium"

      min_size     = 2
      max_size     = 5
      desired_size = 2
      iam_role_additional_policies = {
        ebs_policy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }
  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  # https://istio.io/latest/docs/ops/deployment/application-requirements/#ports-used-by-istio
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15443 = {
      description                   = "east west gateway"
      protocol                      = "TCP"
      from_port                     = 15443
      to_port                       = 15443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  tags = local.tags
}

module "eks_blueprints_addons" {
  depends_on = [module.eks]
  source     = "aws-ia/eks-blueprints-addons/aws"
  version    = "~> 1.21"

  cluster_name                        = module.eks.cluster_name
  cluster_endpoint                    = module.eks.cluster_endpoint
  cluster_version                     = module.eks.cluster_version
  oidc_provider_arn                   = module.eks.oidc_provider_arn
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}