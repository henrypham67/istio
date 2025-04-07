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
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.35"

  cluster_name                   = var.name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  # Give the Terraform identity admin access to the cluster
  # which will allow resources to be deployed into the cluster
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  self_managed_node_groups = {
    initial = {
      ami_type      = "AL2_x86_64"
      instance_type = "t3.medium"

      min_size = 1
      max_size = 1
      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 1
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
  }

  tags = local.tags
}

################################################################################
# EKS Blueprints Addons
################################################################################

resource "kubectl_manifest" "istio_system" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.istio_system_ns.name}
  labels:
    topology.istio.io/network: ${local.istio_system_ns.name}
YAML
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.21"

  depends_on = [kubectl_manifest.cacerts_cluster]

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # This is required to expose Istio Ingress Gateway
  enable_aws_load_balancer_controller = true

  helm_releases = {
    # Istio CRDs
    istio-base = {
      chart         = "base"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-base"
      namespace     = local.istio_system_ns.name
    }

    # Control Plane
    istiod = {
      chart         = "istiod"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istiod"
      namespace     = local.istio_system_ns.name

      set = [
        {
          name  = "meshConfig.accessLogFile"
          value = "/dev/stdout"
        },
        {
          name  = "global.meshID"
          value = var.name
        },
        {
          name  = "global.multiCluster.clusterName"
          value = var.name
        },
        {
          name  = "global.network"
          value = var.name
        },
        {
          name  = "gateways.istio-ingressgateway.injectionTemplate"
          value = "gateway"
        }
      ]
    }

    istio-ingress = {
      chart            = "gateway"
      chart_version    = local.istio_chart_version
      repository       = local.istio_chart_url
      name             = "istio-ingress"
      namespace        = "istio-ingress" # per https://github.com/istio/istio/blob/master/manifests/charts/gateways/istio-ingress/values.yaml#L2
      create_namespace = true

      values = [
        yamlencode(
          {
            labels = {
              istio = "ingressgateway"
            }
            service = {
              annotations = {
                "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
                "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
                "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
                "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
              }
              ports = [
                {
                  name       = "tls-istiod"
                  port       = 15012
                  targetPort = 15012
                },
                {
                  name       = "tls-webhook"
                  port       = 15017
                  targetPort = 15017
                }
              ]
            }
          }
        )
      ]
    }

    istio-eastwestgateway = {
      chart         = "gateway"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-eastwestgateway"
      namespace     = local.istio_system_ns.name

      values = [
        yamlencode(
          {
            labels = {
              istio                       = "eastwestgateway"
              app                         = "istio-eastwestgateway"
              "topology.istio.io/network" = var.name
            }
            env = {
              "ISTIO_META_REQUESTED_NETWORK_VIEW" = var.name
            }
            service = {
              annotations = {
                "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
                "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
                "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
                "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
              }
              ports = [
                {
                  name       = "tls"
                  port       = 15443
                  targetPort = 15443
                }
              ]
            }
          }
        )
      ]
    }
  }

  tags = local.tags
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