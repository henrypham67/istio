output "s3_bucket_name" {
  description = "Name of the S3 bucket created for Mimir"
  value       = aws_s3_bucket.mimir.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for Mimir pod identity"
  value       = aws_iam_role.mimir_pod_identity.arn
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = var.service_account_name
}

output "namespace" {
  description = "Kubernetes namespace used"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
