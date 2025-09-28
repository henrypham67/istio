module "cluster" {
  source = "../../modules/eks"

  name     = var.cluster_name
  vpc_cidr = "10.1.0.0/16"

  desired_nodes = 7
  max_nodes     = 9
}

resource "helm_release" "istio_base" {
  depends_on       = [module.cluster]
  chart            = "base"
  version          = "1.25.1"
  name             = "istio-base"
  namespace        = var.istio_ns
  repository       = "https://istio-release.storage.googleapis.com/charts"
  create_namespace = true
}

# Control Plane
resource "helm_release" "istiod" {
  depends_on       = [module.cluster, helm_release.istio_base]
  chart            = "istiod"
  version          = "1.25.1"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  name             = "istiod"
  namespace        = var.istio_ns
  create_namespace = true

  values = [templatefile("values/istio.yaml", {
    CLUSTER_NAME    = var.cluster_name
    ISTIO_NAMESPACE = var.istio_ns
  })]
}

resource "helm_release" "istio_gateway" {
  depends_on       = [helm_release.istiod]
  chart            = "gateway"
  version          = "1.25.1"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  name             = "istio-ingress"
  namespace        = var.istio_ns
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
            "service.beta.kubernetes.io/aws-load-balancer-name"            = "istio-gateway-lb"

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
            },
            {
              name       = "argocd"
              port       = 80
              targetPort = 80
            },
            {
              name       = "grafana"
              port       = 5000
              targetPort = 5000
            },
            {
              name       = "kiali"
              port       = 6000
              targetPort = 6000
            },
            {
              name       = "test-app"
              port       = 8080
              targetPort = 8080
            }
          ]
        }
      }
    )
  ]
}

locals {
  apps_need_storage = {
    "mimir" : [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectAttributes",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ],
    "quickwit" : [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ]

  }
}


module "storages" {
  for_each = local.apps_need_storage
  source   = "../../modules/s3-pod-identity"

  # Core configuration
  cluster_name         = module.cluster.cluster_name
  application_name     = each.key
  bucket_name          = "my-${each.key}-bucket-199907060500"
  namespace            = "monitoring"
  service_account_name = "${each.key}-sa"

  # S3 configuration
  enable_versioning = true
  sse_algorithm     = "AES256"

  s3_permissions = each.value

  # Lifecycle management for cost optimization
  lifecycle_rules = [
    {
      id                                     = "delete-old-versions"
      enabled                                = true
      noncurrent_version_expiration_days     = 90
      abort_incomplete_multipart_upload_days = 7
    }
  ]

  tags = {
    Application = each.key
    Environment = "production"
    DataType    = "metrics"
  }
}

module "argocd" {
  source     = "../../modules/argocd"
  depends_on = [helm_release.istio_gateway]

  git_repo_url       = var.git_argocd_repo_url
  argocd_helm_values = [file("values/argocd.yaml")]
  istio_gateway      = helm_release.istio_gateway
}
