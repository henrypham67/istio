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
  source = "./modules/eks"

  name     = var.cluster_1
  vpc_cidr = var.vpc_cidr_block_1
  providers = {
    aws  = aws
    helm = helm.helm_1
  }
}

module "cluster_2" {
  source = "./modules/eks"

  name     = var.cluster_2
  vpc_cidr = var.vpc_cidr_block_2
  providers = {
    aws  = aws.us_west_2
    helm = helm.helm_2
  }
}

resource "kubernetes_namespace_v1" "istio_system_1" {
  metadata {
    name = "istio-system"
    labels = {
      "topology.istio.io/network" = "istio-system"
    }
  }

  provider = kubernetes.kubernetes_1
}

resource "kubernetes_namespace_v1" "istio_system_2" {
  metadata {
    name = "istio-system"
    labels = {
      "topology.istio.io/network" = "istio-system"
    }
  }

  provider = kubernetes.kubernetes_2
}

resource "kubernetes_secret" "cert-manager-vault-token_1" {
  depends_on = [module.cluster_1]

  metadata {
    name      = "cert-manager-vault-token"
    namespace = "istio-system"
  }
  data = {
    "token" = "root"
  }

  provider = kubernetes.kubernetes_1
}

resource "kubernetes_secret" "cert-manager-vault-token_2" {
  depends_on = [module.cluster_2]

  metadata {
    name      = "cert-manager-vault-token"
    namespace = "istio-system"
  }
  data = {
    "token" = "root"
  }

  provider = kubernetes.kubernetes_2
}

data "kubernetes_service" "vault" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }

  provider = kubernetes.kubernetes_1
}

locals {
  vault_dns = data.kubernetes_service.vault.status[0].load_balancer[0].ingress[0].hostname
}

resource "kubernetes_manifest" "vault_issuer_1" {
  depends_on = [module.cluster_1]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Issuer"
    "metadata" = {
      "name"      = "vault"
      "namespace" = "istio-system"
    }
    "spec" = {
      "vault" = {
        "server" = "http://${local.vault_dns}:8200"
        "path"   = "pki_int1_istio-cluster1/sign/istio-ca-istio-cluster1"
        "auth" = {
          "tokenSecretRef" = {
            "name" = "cert-manager-vault-token"
            "key"  = "token"
          }
        }
      }
    }
  }

  provider = kubernetes.kubernetes_1
}

resource "kubernetes_manifest" "vault_issuer_2" {
  depends_on = [module.cluster_2]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Issuer"
    "metadata" = {
      "name"      = "vault"
      "namespace" = "istio-system"
    }
    "spec" = {
      "vault" = {
        "server" = "http://${local.vault_dns}:8200"
        "path"   = "pki_int1_istio-cluster1/sign/istio-ca-istio-cluster1"
        "auth" = {
          "tokenSecretRef" = {
            "name" = "cert-manager-vault-token"
            "key"  = "token"
          }
        }
      }
    }
  }

  provider = kubernetes.kubernetes_2
}

resource "helm_release" "istio_csr_1" {
  depends_on = [kubernetes_manifest.vault_issuer_1]
  chart      = "cert-manager-istio-csr"
  repository = "https://charts.jetstack.io"
  name       = "cert-manager-istio-csr"
  version    = "0.14.0"
  namespace  = "istio-system"
  values = [
    templatefile("values/istio_csr.yaml", {
      CLUSTER_ID = var.cluster_1
    })
  ]
  timeout  = 600
  provider = helm.helm_1
}

resource "helm_release" "istio_csr_2" {
  depends_on = [kubernetes_manifest.vault_issuer_2]
  chart      = "cert-manager-istio-csr"
  repository = "https://charts.jetstack.io"
  name       = "cert-manager-istio-csr"
  version    = "0.14.0"
  namespace  = "istio-system"
  values = [
    templatefile("values/istio_csr.yaml", {
      CLUSTER_ID = var.cluster_2
    })
  ]
  timeout  = 600
  provider = helm.helm_2
}

resource "helm_release" "istio-base" {
  chart      = "base"
  version    = "1.25.1"
  name       = "istio-base"
  namespace  = "istio-system"
  repository = "https://istio-release.storage.googleapis.com/charts"

  provider = helm.helm_1
}

# Control Plane
resource "helm_release" "istiod" {
  chart      = "istiod"
  version    = "1.25.1"
  repository = "https://istio-release.storage.googleapis.com/charts"
  name       = "istiod"
  namespace  = "istio-system"

  values = [templatefile("values/istio.yaml", {
    CLUSTER_NAME = var.cluster_1
  })]

  provider = helm.helm_1
}

resource "helm_release" "istio_base_2" {
  chart      = "base"
  version    = "1.25.1"
  name       = "istio-base"
  namespace  = "istio-system"
  repository = "https://istio-release.storage.googleapis.com/charts"

  provider = helm.helm_2
}

# Control Plane
resource "helm_release" "istiod_2" {
  chart      = "istiod"
  version    = "1.25.1"
  repository = "https://istio-release.storage.googleapis.com/charts"
  name       = "istiod"
  namespace  = "istio-system"

  values = [templatefile("values/istio.yaml", {
    CLUSTER_NAME = var.cluster_2
  })]

  provider = helm.helm_2
}
resource "helm_release" "istio-eastwestgateway-1" {
  chart      = "gateway"
  version    = "1.25.1"
  repository = "https://istio-release.storage.googleapis.com/charts"
  name       = "istio-eastwestgateway"
  namespace  = "istio-system"

  values = [
    yamlencode({
      labels = {
        istio                       = "eastwestgateway"
        app                         = "istio-eastwestgateway"
        "topology.istio.io/network" = var.cluster_1
      }
      env = {
        "ISTIO_META_REQUESTED_NETWORK_VIEW" = var.cluster_1
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
        }
        ports = [
          {
            name       = "tls"
            port       = 15443
            targetPort = 15443
          }
        ]
      }
    })
  ]

  provider = helm.helm_1
}
resource "helm_release" "istio-eastwestgateway-2" {
  chart      = "gateway"
  version    = "1.25.1"
  repository = "https://istio-release.storage.googleapis.com/charts"
  name       = "istio-eastwestgateway"
  namespace  = "istio-system"

  values = [
    yamlencode({
      labels = {
        istio                       = "eastwestgateway"
        app                         = "istio-eastwestgateway"
        "topology.istio.io/network" = var.cluster_2
      }
      env = {
        "ISTIO_META_REQUESTED_NETWORK_VIEW" = var.cluster_2
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
        }
        ports = [
          {
            name       = "tls"
            port       = 15443
            targetPort = 15443
          }
        ]
      }
    })
  ]

  provider = helm.helm_2
}

resource "kubernetes_secret" "istio_reader_token_1" {
  depends_on = [module.cluster_1, kubernetes_namespace_v1.istio_system_1]
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "istio-reader-service-account"
    }
    name      = "istio-reader-service-account-istio-remote-secret-token"
    namespace = "istio-system"
  }
  type = "kubernetes.io/service-account-token"

  provider = kubernetes.kubernetes_1
}

resource "kubernetes_secret" "istio_reader_token_2" {
  depends_on = [module.cluster_2, kubernetes_namespace_v1.istio_system_2]
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "istio-reader-service-account"
    }
    name      = "istio-reader-service-account-istio-remote-secret-token"
    namespace = "istio-system"
  }
  type = "kubernetes.io/service-account-token"

  provider = kubernetes.kubernetes_2
}

module "multi_cluster_app_1" {
  source     = "../../modules/multi-cluster-app"
  depends_on = [module.cluster_1, module.cluster_2]

  other_cluster_certificate_authority_data = module.cluster_2.certificate_authority_data
  other_cluster_endpoint                   = module.cluster_2.cluster_endpoint
  other_cluster_name                       = module.cluster_2.cluster_name
  service_account_token                    = kubernetes_secret.istio_reader_token_2.data["token"]
  app_version                              = "v1"


  providers = {
    helm    = helm.helm_1
    kubectl = kubectl.kubectl_1
  }
}

module "multi_cluster_app_2" {
  source     = "../../modules/multi-cluster-app"
  depends_on = [module.cluster_1, module.cluster_2]

  other_cluster_certificate_authority_data = module.cluster_1.certificate_authority_data
  other_cluster_endpoint                   = module.cluster_1.cluster_endpoint
  other_cluster_name                       = module.cluster_1.cluster_name
  service_account_token                    = kubernetes_secret.istio_reader_token_1.data["token"]

  providers = {
    helm    = helm.helm_2
    kubectl = kubectl.kubectl_2
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
  depends_on                = [aws_vpc_peering_connection_accepter.peer]
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

# Accepter side - set from aws.us_west_2 provider
resource "aws_vpc_peering_connection_options" "accepter" {
  depends_on                = [aws_vpc_peering_connection_accepter.peer]
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
