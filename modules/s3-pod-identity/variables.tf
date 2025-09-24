# Core configuration variables
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.cluster_name))
    error_message = "Cluster name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.bucket_name)) && length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "S3 bucket name must be 3-63 characters long and contain only lowercase letters, numbers, periods, and hyphens."
  }
}

variable "application_name" {
  description = "Name of the application (used for IAM role and policy naming)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.application_name))
    error_message = "Application name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "namespace" {
  description = "Kubernetes namespace where the service account will be created"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.namespace)) && length(var.namespace) <= 63
    error_message = "Namespace must contain only lowercase letters, numbers, and hyphens, and be no more than 63 characters."
  }
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account that will be associated with the IAM role"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_account_name)) && length(var.service_account_name) <= 63
    error_message = "Service account name must contain only lowercase letters, numbers, and hyphens, and be no more than 63 characters."
  }
}

# IAM configuration
variable "iam_role_name" {
  description = "Custom name for the IAM role (if not provided, will be generated from cluster_name and application_name)"
  type        = string
  default     = null
}

variable "iam_policy_name" {
  description = "Custom name for the IAM policy (if not provided, will be generated from cluster_name and application_name)"
  type        = string
  default     = null
}

variable "s3_permissions" {
  description = "List of S3 permissions to grant to the application"
  type        = list(string)
  default = [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:GetObjectAttributes",
    "s3:GetObjectTagging",
    "s3:PutObjectTagging"
  ]
  
  validation {
    condition = alltrue([
      for perm in var.s3_permissions : can(regex("^s3:", perm))
    ])
    error_message = "All permissions must start with 's3:'."
  }
}

variable "additional_policy_statements" {
  description = "Additional IAM policy statements to include in the policy"
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
    Condition = optional(map(any))
  }))
  default = []
}

variable "additional_managed_policy_arns" {
  description = "List of additional managed policy ARNs to attach to the IAM role"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for arn in var.additional_managed_policy_arns : can(regex("^arn:aws:iam::", arn))
    ])
    error_message = "All policy ARNs must be valid AWS IAM policy ARNs."
  }
}

# S3 bucket configuration
variable "force_destroy" {
  description = "Allow Terraform to destroy the S3 bucket even if it contains objects (use with caution in production)"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning for data protection"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm for S3 bucket (AES256 or aws:kms)"
  type        = string
  default     = "AES256"
  
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "SSE algorithm must be either 'AES256' or 'aws:kms'."
  }
}

variable "kms_key_id" {
  description = "KMS key ID to use for S3 encryption when sse_algorithm is aws:kms (optional)"
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "Enable S3 bucket key for KMS encryption (reduces KMS API calls and costs)"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Enable S3 bucket public access block for security"
  type        = bool
  default     = true
}

# Lifecycle management
variable "lifecycle_rules" {
  description = "List of lifecycle rules for the S3 bucket"
  type = list(object({
    id                                       = string
    enabled                                  = bool
    expiration_days                          = optional(number)
    noncurrent_version_expiration_days       = optional(number)
    abort_incomplete_multipart_upload_days   = optional(number)
  }))
  default = null
  
  validation {
    condition = var.lifecycle_rules == null || alltrue([
      for rule in var.lifecycle_rules : rule.id != null && rule.id != ""
    ])
    error_message = "Each lifecycle rule must have a non-empty id."
  }
}

variable "namespace_labels" {
  description = "Labels to apply to the Kubernetes namespace (only used if create_namespace is true)"
  type        = map(string)
  default     = {}
}

variable "namespace_annotations" {
  description = "Annotations to apply to the Kubernetes namespace (only used if create_namespace is true)"
  type        = map(string)
  default     = {}
}

# Tagging
variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for k, v in var.tags : can(regex("^[a-zA-Z0-9 _.:/=+@-]{1,128}$", k)) && can(regex("^[a-zA-Z0-9 _.:/=+@-]{0,256}$", v))
    ])
    error_message = "Tag keys must be 1-128 characters and values must be 0-256 characters. Only alphanumeric characters and :/=+@-_ are allowed."
  }
}