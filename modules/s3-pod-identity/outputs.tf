# S3 bucket outputs
output "s3_bucket_id" {
  description = "ID (name) of the S3 bucket created"
  value       = aws_s3_bucket.app_bucket.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created (same as id)"
  value       = aws_s3_bucket.app_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket created"
  value       = aws_s3_bucket.app_bucket.arn
}

output "s3_bucket_region" {
  description = "AWS region of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.region
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket_domain_name
}

output "s3_bucket_hosted_zone_id" {
  description = "Route 53 Hosted Zone ID of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.hosted_zone_id
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket_regional_domain_name
}

# S3 bucket configuration outputs
output "s3_bucket_versioning_enabled" {
  description = "Whether S3 bucket versioning is enabled"
  value       = var.enable_versioning
}

output "s3_bucket_encryption" {
  description = "S3 bucket encryption configuration"
  value = {
    algorithm           = var.sse_algorithm
    kms_key_id         = var.kms_key_id
    bucket_key_enabled = var.sse_algorithm == "aws:kms" ? var.bucket_key_enabled : null
  }
}

output "s3_bucket_lifecycle_configured" {
  description = "Whether S3 bucket lifecycle rules are configured"
  value       = var.lifecycle_rules != null
}

output "s3_bucket_public_access_blocked" {
  description = "Whether S3 bucket public access is blocked"
  value       = var.block_public_access
}

# IAM role and policy outputs
output "iam_role_arn" {
  description = "ARN of the IAM role created for the application"
  value       = aws_iam_role.app_pod_identity.arn
}

output "iam_role_name" {
  description = "Name of the IAM role created for the application"
  value       = aws_iam_role.app_pod_identity.name
}

output "iam_policy_arn" {
  description = "ARN of the S3 access policy created for the application"
  value       = aws_iam_policy.app_s3_access.arn
}

output "iam_policy_name" {
  description = "Name of the S3 access policy created for the application"
  value       = aws_iam_policy.app_s3_access.name
}

output "s3_permissions" {
  description = "List of S3 permissions granted to the application"
  value       = var.s3_permissions
}

# EKS Pod Identity outputs
output "pod_identity_association_id" {
  description = "ID of the EKS Pod Identity Association"
  value       = aws_eks_pod_identity_association.app_pod_identity.association_id
}

output "pod_identity_association_arn" {
  description = "ARN of the EKS Pod Identity Association"
  value       = aws_eks_pod_identity_association.app_pod_identity.association_arn
}

# Kubernetes configuration outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}

output "application_name" {
  description = "Name of the application"
  value       = var.application_name
}

output "namespace" {
  description = "Kubernetes namespace used"
  value       = var.namespace
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = var.service_account_name
}

# Summary outputs for convenience
output "configuration_summary" {
  description = "Summary of the configuration created by this module"
  value = {
    # Application information
    application = {
      name            = var.application_name
      cluster_name    = var.cluster_name
      namespace       = var.namespace
      service_account = var.service_account_name
    }
    
    # S3 bucket information
    s3_bucket = {
      name       = aws_s3_bucket.app_bucket.id
      arn        = aws_s3_bucket.app_bucket.arn
      region     = aws_s3_bucket.app_bucket.region
      versioning = var.enable_versioning
      encryption = var.sse_algorithm
      public_access_blocked = var.block_public_access
      lifecycle_configured  = var.lifecycle_rules != null
    }
    
    # IAM configuration
    iam = {
      role_arn              = aws_iam_role.app_pod_identity.arn
      role_name             = aws_iam_role.app_pod_identity.name
      policy_arn            = aws_iam_policy.app_s3_access.arn
      policy_name           = aws_iam_policy.app_s3_access.name
      s3_permissions        = var.s3_permissions
      pod_identity_id       = aws_eks_pod_identity_association.app_pod_identity.association_id
    }
    
    # Kubernetes configuration
    kubernetes = {
      namespace_labels    = var.namespace_labels
      namespace_annotations = var.namespace_annotations
    }
  }
}

# Helm chart integration outputs
output "helm_values" {
  description = "Ready-to-use values for Helm chart integration"
  value = {
    # Service account configuration
    serviceAccount = {
      create = true
      name   = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.app_pod_identity.arn
      }
    }
    
    # S3 configuration for application
    s3 = {
      bucket_name = aws_s3_bucket.app_bucket.id
      region     = aws_s3_bucket.app_bucket.region
      endpoint   = "https://s3.${aws_s3_bucket.app_bucket.region}.amazonaws.com"
    }
    
    # Application metadata
    application = {
      name = var.application_name
    }
  }
}