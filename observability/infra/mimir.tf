# S3 bucket for Mimir
resource "aws_s3_bucket" "mimir" {
  bucket = "my-mimir-bucket-1999070605"
  force_destroy = true
}

# IAM policy for S3 access
resource "aws_iam_policy" "mimir_s3" {
  name = "MimirS3Access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      Resource = [
        aws_s3_bucket.mimir.arn,
        "${aws_s3_bucket.mimir.arn}/*"
      ]
    }]
  })
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM Role for Pod Identity
resource "aws_iam_role" "mimir_pod_identity" {
  name = "MimirPodIdentityRole"

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.mimir_pod_identity.name
  policy_arn = aws_iam_policy.mimir_s3.arn
}

# Kubernetes Service Account
resource "kubernetes_service_account" "mimir" {
  metadata {
    name      = "mimir-sa"
    namespace = "observability"
  }
}

# EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "mimir" {
  depends_on      = [helm_release.argocd]
  cluster_name    = var.cluster_name
  namespace       = "argocd"
  service_account = "mimir-sa"
  role_arn        = aws_iam_role.mimir_pod_identity.arn
}



resource "kubectl_manifest" "mimir_cm" {
  depends_on = [helm_release.argocd]
  yaml_body  = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-helm-values
  namespace: argocd
data:
  values.yaml: |
    mimir:
      common:
        storage:
          s3:
            bucket_name: ${aws_s3_bucket.mimir.id}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.mimir_pod_identity.arn}
YAML
}