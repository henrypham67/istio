# S3 bucket for application data storage
resource "aws_s3_bucket" "app_bucket" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    ManagedBy = "s3-pod-identity-module"
    Purpose   = "Application data storage with EKS Pod Identity"
  })
}

# Enable server-side encryption for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? var.kms_key_id : null
    }
    bucket_key_enabled = var.sse_algorithm == "aws:kms" ? var.bucket_key_enabled : null
  }
}

# Enable versioning for data protection (optional)
resource "aws_s3_bucket_versioning" "app_bucket" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable public access block (security best practice)
resource "aws_s3_bucket_public_access_block" "app_bucket" {
  count  = var.block_public_access ? 1 : 0
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "app_bucket" {
  count  = var.lifecycle_rules != null ? 1 : 0
  bucket = aws_s3_bucket.app_bucket.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {}

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [rule.value.noncurrent_version_expiration_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [rule.value.abort_incomplete_multipart_upload_days] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }
}

# IAM assume role policy for EKS Pod Identity
data "aws_iam_policy_document" "pod_identity_assume_role" {
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

# IAM role for Pod Identity
resource "aws_iam_role" "app_pod_identity" {
  name               = var.iam_role_name != null ? var.iam_role_name : "${var.cluster_name}-${var.application_name}-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json

  tags = merge(var.tags, {
    ManagedBy     = "s3-pod-identity-module"
    Application   = var.application_name
    ServiceAccount = var.service_account_name
    Namespace     = var.namespace
  })
}

# S3 access policy for the application
resource "aws_iam_policy" "app_s3_access" {
  name        = var.iam_policy_name != null ? var.iam_policy_name : "${var.cluster_name}-${var.application_name}-s3-access"
  description = "S3 access policy for ${var.application_name} application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = var.s3_permissions
        Resource = [
          aws_s3_bucket.app_bucket.arn,
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      }
    ], var.additional_policy_statements)
  })

  tags = merge(var.tags, {
    ManagedBy   = "s3-pod-identity-module"
    Application = var.application_name
  })
}

# Attach S3 policy to role
resource "aws_iam_role_policy_attachment" "app_s3_policy_attachment" {
  role       = aws_iam_role.app_pod_identity.name
  policy_arn = aws_iam_policy.app_s3_access.arn
}

# Attach additional managed policies if specified
resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each = toset(var.additional_managed_policy_arns)
  
  role       = aws_iam_role.app_pod_identity.name
  policy_arn = each.value
}

# EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "app_pod_identity" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.app_pod_identity.arn

  tags = merge(var.tags, {
    ManagedBy      = "s3-pod-identity-module"
    Application    = var.application_name
    ServiceAccount = var.service_account_name
    Namespace      = var.namespace
  })
}