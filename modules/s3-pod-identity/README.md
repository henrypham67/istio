# S3 Pod Identity Module

A comprehensive Terraform module that creates S3 bucket infrastructure, IAM role with policies, and EKS Pod Identity association for applications requiring secure S3 access with AWS authentication.

## Overview

This module provisions:
- S3 bucket with configurable encryption, versioning, and lifecycle management
- Dedicated IAM role and policy for the application with customizable S3 permissions
- EKS Pod Identity Association linking Kubernetes service accounts to IAM roles
- Optional Kubernetes namespace creation with custom labels and annotations
- Security best practices including public access blocking

**Key Features**: Each application gets its own IAM role and policy for maximum security isolation and principle of least privilege.

## Features

### S3 Bucket Security
- ✅ Server-side encryption (AES256 or KMS)
- ✅ Public access blocking by default
- ✅ Optional versioning for data protection
- ✅ Configurable lifecycle rules
- ✅ Proper tagging and resource organization

### IAM Security & Isolation
- ✅ Dedicated IAM role per application
- ✅ Customizable S3 permissions per service requirements
- ✅ Additional policy statements support
- ✅ Managed policy attachment capability
- ✅ Principle of least privilege

### EKS Integration
- ✅ Pod Identity association for secure authentication
- ✅ No stored credentials or secrets required
- ✅ Automatic IAM role assumption for service accounts
- ✅ Comprehensive validation and error handling

### Kubernetes Support
- ✅ Optional namespace creation with labels/annotations
- ✅ Service account integration
- ✅ Ready-to-use Helm chart values output

## Usage

### Basic Example for Mimir

```hcl
module "mimir_storage" {
  source = "./modules/s3-pod-identity"
  
  # Core configuration
  cluster_name         = "my-cluster"
  application_name     = "mimir"
  bucket_name          = "my-cluster-mimir-storage"
  namespace            = "monitoring"
  service_account_name = "mimir-sa"
  
  # S3 configuration
  create_namespace     = true
  enable_versioning    = true
  sse_algorithm        = "AES256"
  
  # Mimir-specific S3 permissions (includes GetObjectAttributes)
  s3_permissions = [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:GetObjectAttributes"
  ]
  
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
    Application = "mimir"
    Environment = "production"
    DataType    = "metrics"
  }
}
```

### Loki Example with Multiple Buckets

```hcl
# Loki chunks storage
module "loki_chunks_storage" {
  source = "./modules/s3-pod-identity"
  
  cluster_name         = "my-cluster"
  application_name     = "loki"
  bucket_name          = "my-cluster-loki-chunks"
  namespace            = "logging"
  service_account_name = "loki-sa"
  
  # Loki doesn't need versioning for chunks
  enable_versioning    = false
  create_namespace     = true
  
  # Loki-specific permissions (no GetObjectAttributes needed)
  s3_permissions = [
    "s3:ListBucket",
    "s3:GetObject", 
    "s3:PutObject",
    "s3:DeleteObject"
  ]
  
  # Additional policy for accessing ruler bucket
  additional_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = [
        "arn:aws:s3:::my-cluster-loki-ruler",
        "arn:aws:s3:::my-cluster-loki-ruler/*"
      ]
    }
  ]
  
  tags = {
    Application = "loki"
    Environment = "production"
    DataType    = "logs"
  }
}

# Separate bucket for Loki ruler (using different module instance)
module "loki_ruler_storage" {
  source = "./modules/s3-pod-identity"
  
  cluster_name         = "my-cluster"
  application_name     = "loki-ruler"
  bucket_name          = "my-cluster-loki-ruler"
  namespace            = "logging"  
  service_account_name = "loki-ruler-sa"
  
  # Don't create namespace again
  create_namespace     = false
  enable_versioning    = true  # Rules benefit from versioning
  
  s3_permissions = [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject", 
    "s3:DeleteObject"
  ]
  
  tags = {
    Application = "loki-ruler"
    Environment = "production"
    DataType    = "rules"
  }
}
```

### Tempo Example with Advanced Security

```hcl
# KMS key for sensitive trace data
resource "aws_kms_key" "tempo_encryption" {
  description = "KMS key for Tempo trace encryption"
  
  tags = {
    Name = "tempo-encryption-key"
  }
}

# Tempo storage with enhanced security
module "tempo_storage" {
  source = "./modules/s3-pod-identity"
  
  cluster_name         = "my-cluster"
  application_name     = "tempo"
  bucket_name          = "my-cluster-tempo-traces"
  namespace            = "tracing"
  service_account_name = "tempo-sa"
  
  # Enhanced security configuration
  create_namespace     = true
  sse_algorithm        = "aws:kms"
  kms_key_id          = aws_kms_key.tempo_encryption.arn
  bucket_key_enabled  = true
  force_destroy       = false  # Protect production data
  
  # Tempo-specific permissions (includes object tagging)
  s3_permissions = [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:GetObjectTagging",
    "s3:PutObjectTagging"
  ]
  
  # Namespace configuration for Istio
  namespace_labels = {
    "istio-injection" = "enabled"
    "monitoring"      = "enabled"
  }
  
  # Data retention for compliance
  lifecycle_rules = [
    {
      id              = "retain-traces-30-days"
      enabled         = true
      expiration_days = 30
    },
    {
      id                                     = "cleanup-incomplete-uploads"
      enabled                                = true
      abort_incomplete_multipart_upload_days = 1
    }
  ]
  
  tags = {
    Application     = "tempo"
    Environment     = "production"
    DataType        = "traces"
    Compliance      = "required"
    BackupRetention = "30-days"
  }
}
```

### Custom IAM Role Names Example

```hcl
module "custom_app_storage" {
  source = "./modules/s3-pod-identity"
  
  cluster_name         = "my-cluster"
  application_name     = "my-app"
  bucket_name          = "my-app-custom-bucket"
  namespace            = "default"
  service_account_name = "my-app-sa"
  
  # Custom IAM resource names
  iam_role_name   = "MyAppCustomRole"
  iam_policy_name = "MyAppCustomPolicy"
  
  # Custom S3 permissions
  s3_permissions = [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject"
  ]
  
  # Additional managed policy
  additional_managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  
  tags = {
    Application = "my-app"
    Environment = "development"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| kubernetes | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| kubernetes | >= 2.0 |

## Inputs

### Core Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| application_name | Name of the application (used for IAM role and policy naming) | `string` | n/a | yes |
| bucket_name | Name of the S3 bucket (must be globally unique) | `string` | n/a | yes |
| namespace | Kubernetes namespace where the service account will be created | `string` | n/a | yes |
| service_account_name | Name of the Kubernetes service account | `string` | n/a | yes |

### IAM Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| iam_role_name | Custom name for the IAM role (auto-generated if not provided) | `string` | `null` | no |
| iam_policy_name | Custom name for the IAM policy (auto-generated if not provided) | `string` | `null` | no |
| s3_permissions | List of S3 permissions to grant to the application | `list(string)` | `[comprehensive list]` | no |
| additional_policy_statements | Additional IAM policy statements | `list(object)` | `[]` | no |
| additional_managed_policy_arns | Additional managed policy ARNs to attach | `list(string)` | `[]` | no |

### S3 Bucket Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| force_destroy | Allow Terraform to destroy bucket with objects | `bool` | `false` | no |
| enable_versioning | Enable S3 bucket versioning | `bool` | `true` | no |
| sse_algorithm | Server-side encryption algorithm (AES256 or aws:kms) | `string` | `"AES256"` | no |
| kms_key_id | KMS key ID for encryption when using aws:kms | `string` | `null` | no |
| bucket_key_enabled | Enable S3 bucket key for KMS encryption | `bool` | `true` | no |
| block_public_access | Enable S3 bucket public access block | `bool` | `true` | no |
| lifecycle_rules | List of lifecycle rules for the S3 bucket | `list(object)` | `null` | no |

### Kubernetes Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_namespace | Create the Kubernetes namespace if it doesn't exist | `bool` | `false` | no |
| namespace_labels | Labels to apply to the Kubernetes namespace | `map(string)` | `{}` | no |
| namespace_annotations | Annotations to apply to the Kubernetes namespace | `map(string)` | `{}` | no |
| tags | Tags to apply to AWS resources | `map(string)` | `{}` | no |

### Default S3 Permissions

The module provides comprehensive S3 permissions by default suitable for most observability applications:

```hcl
s3_permissions = [
  "s3:ListBucket",
  "s3:GetObject",
  "s3:PutObject",
  "s3:DeleteObject",
  "s3:GetObjectAttributes",  # Needed by Mimir
  "s3:GetObjectTagging",     # Needed by Tempo
  "s3:PutObjectTagging"      # Needed by Tempo
]
```

You can customize this list based on your application's specific requirements.

## Outputs

### S3 Bucket Outputs

| Name | Description |
|------|-------------|
| s3_bucket_name | Name of the S3 bucket created |
| s3_bucket_arn | ARN of the S3 bucket created |
| s3_bucket_region | AWS region of the S3 bucket |

### IAM Outputs

| Name | Description |
|------|-------------|
| iam_role_arn | ARN of the IAM role created |
| iam_role_name | Name of the IAM role created |
| iam_policy_arn | ARN of the S3 access policy created |
| iam_policy_name | Name of the S3 access policy created |

### Integration Outputs

| Name | Description |
|------|-------------|
| configuration_summary | Complete summary of all resources created |
| helm_values | Ready-to-use values for Helm chart integration |

## Application-Specific Guidance

### For Mimir
- **Requires**: `s3:GetObjectAttributes` for metadata operations
- **Versioning**: Enable for data protection
- **Lifecycle**: Configure to manage storage costs

### For Loki
- **Chunks bucket**: Disable versioning (cost optimization)
- **Ruler bucket**: Enable versioning (rule protection)
- **Multiple buckets**: Use additional_policy_statements or separate instances

### For Tempo
- **Requires**: `s3:GetObjectTagging` and `s3:PutObjectTagging`
- **Security**: Consider KMS encryption for sensitive trace data
- **Lifecycle**: Short retention periods for cost optimization

## Integration with Helm Charts

Use the `helm_values` output for direct integration:

```hcl
# Example with Mimir Helm chart
resource "helm_release" "mimir" {
  name       = "mimir"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "mimir-distributed"
  namespace  = module.mimir_storage.namespace
  
  values = [
    yamlencode({
      serviceAccount = module.mimir_storage.helm_values.serviceAccount
      
      mimir = {
        structuredConfig = {
          blocks_storage = {
            backend = "s3"
            s3 = {
              bucket_name = module.mimir_storage.helm_values.s3.bucket_name
              region     = module.mimir_storage.helm_values.s3.region
            }
          }
        }
      }
    })
  ]
}
```

## Security Best Practices

### Default Security Features

1. **Individual IAM roles** for maximum isolation
2. **Public access blocking** enabled by default
3. **Server-side encryption** mandatory
4. **Bucket versioning** enabled for data protection
5. **Comprehensive validation** prevents misconfigurations

### Recommendations

1. **Use KMS encryption** for sensitive data (traces, logs with PII)
2. **Configure lifecycle rules** for cost optimization
3. **Set force_destroy to false** for production buckets
4. **Use custom IAM names** for better organization
5. **Tag resources consistently** for governance and cost tracking
6. **Monitor CloudTrail** for access patterns

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Check the `s3_permissions` variable matches your application needs
- Verify Pod Identity association is active
- Ensure bucket name and permissions are correct

**"Role already exists" errors:**
- Use `iam_role_name` to customize role names
- Check for naming conflicts across environments
- Review Terraform state for orphaned resources

**Application-specific permission errors:**
- **Mimir**: Ensure `s3:GetObjectAttributes` is included
- **Tempo**: Include `s3:GetObjectTagging` and `s3:PutObjectTagging`
- **Loki**: May need access to multiple buckets via `additional_policy_statements`

### Debugging Commands

```bash
# Check IAM role permissions
aws iam get-role --role-name <role-name>
aws iam list-attached-role-policies --role-name <role-name>

# Test S3 access from pod
kubectl run test-pod --image=amazon/aws-cli:latest \
  --overrides='{"spec":{"serviceAccount":"<service-account-name>"}}' \
  -n <namespace> --rm -it -- aws s3 ls s3://<bucket-name>

# Check Pod Identity association
aws eks describe-pod-identity-association \
  --cluster-name <cluster-name> \
  --association-id <association-id>
```

## Migration Guide

### From Shared Role Pattern

If migrating from a shared IAM role approach:

1. Deploy individual modules for each application
2. Update Helm charts to use new service account names
3. Test each application independently
4. Remove shared IAM resources once all applications are migrated

### Customizing for Your Applications

1. **Review default permissions**: Adjust `s3_permissions` based on application needs
2. **Configure lifecycle rules**: Set up cost optimization policies
3. **Set up monitoring**: Use outputs to configure CloudWatch alarms
4. **Plan naming strategy**: Use consistent `application_name` values

This module provides maximum security isolation while maintaining operational simplicity through comprehensive automation and ready-to-use outputs.