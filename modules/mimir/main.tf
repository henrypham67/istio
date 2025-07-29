# S3 bucket for Mimir
resource "aws_s3_bucket" "mimir" {
  bucket        = var.mimir_bucket_name
  force_destroy = var.force_destroy

  tags = var.tags
}

# Enable server-side encryption for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "mimir" {
  bucket = aws_s3_bucket.mimir.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Or use "aws:kms" with a KMS key for better security
    }
  }
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "mimir" {
  bucket = aws_s3_bucket.mimir.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM policy for S3 access (least privilege)
resource "aws_iam_policy" "mimir_s3" {
  name        = var.iam_policy_name
  description = "Policy for Mimir to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mimir.arn,
          "${aws_s3_bucket.mimir.arn}/*"
        ]
      }
    ]
  })
}

# Assume role policy for EKS Pod Identity
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
  name               = "${var.cluster_name}-mimir-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.mimir_pod_identity.name
  policy_arn = aws_iam_policy.mimir_s3.arn
}

# Kubernetes Namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

# Kubernetes Service Account
resource "kubernetes_service_account" "mimir" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.mimir_pod_identity.arn
    }
  }
}

# EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "mimir" {
  cluster_name    = var.cluster_name
  namespace       = kubernetes_namespace.monitoring.metadata[0].name
  service_account = kubernetes_service_account.mimir.metadata[0].name
  role_arn        = aws_iam_role.mimir_pod_identity.arn
}