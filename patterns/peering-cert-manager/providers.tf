provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "kubernetes" {
  host                   = module.cluster_1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster_1.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.cluster_1.cluster_name]
  }

  alias = "kubernetes_1"
}

provider "kubernetes" {
  host                   = module.cluster_2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster_2.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.cluster_2.cluster_name]
  }

  alias = "kubernetes_2"
}

provider "helm" {
  kubernetes {
    host                   = module.cluster_1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster_1.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.cluster_1.cluster_name]
    }
  }

  alias = "helm_1"
}

provider "helm" {
  kubernetes {
    host                   = module.cluster_2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster_2.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.cluster_2.cluster_name]
    }
  }

  alias = "helm_2"
}

provider "kubectl" {
  host                   = module.cluster_1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster_1.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.cluster_1.cluster_name]
  }

  alias = "kubectl_1"
}

provider "kubectl" {
  host                   = module.cluster_2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster_2.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.cluster_2.cluster_name]
  }

  alias = "kubectl_2"
}