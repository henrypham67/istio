terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.6.1"
    }
  }
}
