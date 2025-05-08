provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
    }
  }
}

provider "kubectl" {
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
  }
}

data "aws_lb" "argo" {
  depends_on = [kubectl_manifest.virtual_service]

  name = "istio-gateway-lb"
}

# data "aws_eks_cluster_auth" "this" {
#   name = var.cluster_name
# }

# provider "argocd" {
#   username = "admin"
#   password = "admin"
#
#   insecure                    = true
#   port_forward_with_namespace = helm_release.argocd.namespace
#
#   kubernetes {
#     host                   = module.cluster.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.cluster.certificate_authority_data)
#
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       # This requires the awscli to be installed locally where Terraform is executed
#       args = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
#     }
#   }
# }

provider "argocd" {
  username = "admin"
  password = "admin"
  server_addr = data.aws_lb.argo.dns_name
  insecure = true
}
