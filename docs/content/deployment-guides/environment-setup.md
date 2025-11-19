# Environment Setup Guide

This guide walks you through setting up different environments for the GenAI IDP Accelerator using Terraform.

## Environment Types

### Development Environment

**Purpose**: Testing and development work
**Characteristics**:
- Lower resource limits
- Reduced redundancy
- Simplified monitoring

**Configuration**:
```hcl
# terraform/environments/dev/terraform.tfvars
environment = "dev"
region = "us-east-1"

# Basic settings
lambda_memory_size = 512
lambda_timeout = 60
enable_xray_tracing = false

# Simplified storage
s3_versioning_enabled = false
s3_lifecycle_enabled = true

# Basic monitoring
enable_detailed_monitoring = false
log_retention_days = 7
```

### Staging Environment

**Purpose**: Testing and validation environment
**Characteristics**:
- Full feature testing
- Performance validation
- Security testing
- Complete monitoring setup

**Configuration**:
```hcl
# terraform/environments/staging/terraform.tfvars
environment = "staging"
region = "us-east-1"

# Enhanced settings
lambda_memory_size = 1024
lambda_timeout = 300
enable_xray_tracing = true

# Enhanced storage
s3_versioning_enabled = true
s3_lifecycle_enabled = true

# Full monitoring
enable_detailed_monitoring = true
log_retention_days = 30
```

## Network Configuration

### VPC Setup

**New VPC** (Recommended):
```hcl
# Network configuration
create_vpc = true
vpc_cidr = "10.0.0.0/16"

# Subnet configuration
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

# NAT Gateway for private subnets
enable_nat_gateway = true
single_nat_gateway = false  # One per AZ for HA
```

**Existing VPC**:
```hcl
# Use existing VPC
create_vpc = false
vpc_id = "vpc-12345678"

# Existing subnets
private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
public_subnet_ids = ["subnet-abcdef12", "subnet-21fedcba"]
```

### Security Groups

**Default Security Groups**:
```hcl
# Lambda security group
lambda_security_group_rules = [
  {
    type        = "egress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS APIs"
  }
]

# API Gateway security group (if using VPC endpoints)
api_gateway_security_group_rules = [
  {
    type        = "ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "HTTPS from VPC"
  }
]
```

## Storage Configuration

### S3 Bucket Setup

**Development**:
```hcl
s3_bucket_configuration = {
  versioning = {
    enabled = false
  }
  
  lifecycle_configuration = {
    rules = [
      {
        id     = "delete_old_objects"
        status = "Enabled"
        
        expiration = {
          days = 30
        }
      }
    ]
  }
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
```

**Staging**:
```hcl
s3_bucket_configuration = {
  versioning = {
    enabled = true
    mfa_delete = true
  }
  
  lifecycle_configuration = {
    rules = [
      {
        id     = "intelligent_tiering"
        status = "Enabled"
        
        transition = [
          {
            days          = 30
            storage_class = "STANDARD_IA"
          },
          {
            days          = 90
            storage_class = "GLACIER"
          }
        ]
      }
    ]
  }
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.s3_key.arn
      }
    }
  }
}
```

### DynamoDB Configuration

**Development**:
```hcl
dynamodb_configuration = {
  billing_mode = "PAY_PER_REQUEST"
  
  point_in_time_recovery = {
    enabled = false
  }
  
  server_side_encryption = {
    enabled = true
  }
}
```

**Staging**:
```hcl
dynamodb_configuration = {
  billing_mode   = "PROVISIONED"
  read_capacity  = 100
  write_capacity = 100
  
  point_in_time_recovery = {
    enabled = true
  }
  
  server_side_encryption = {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }
  
  global_secondary_indexes = [
    {
      name            = "status-index"
      hash_key        = "status"
      projection_type = "ALL"
      read_capacity   = 50
      write_capacity  = 50
    }
  ]
}
```

## Security Configuration

### IAM Roles and Policies

**Least Privilege Principle**:
```hcl
# Lambda execution role
lambda_execution_role_policies = [
  "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  aws_iam_policy.lambda_custom_policy.arn
]

# Custom policy for specific permissions
resource "aws_iam_policy" "lambda_custom_policy" {
  name = "${var.environment}-lambda-custom-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument",
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.documents.arn}/*"
      }
    ]
  })
}
```

### KMS Key Management

**Environment-Specific Keys**:
```hcl
# KMS key for S3 encryption
resource "aws_kms_key" "s3_key" {
  description = "${var.environment} S3 encryption key"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## Monitoring and Logging

### CloudWatch Configuration

**Log Groups**:
```hcl
# Lambda log groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = var.lambda_functions
  
  name              = "/aws/lambda/${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days
  
  kms_key_id = aws_kms_key.cloudwatch_key.arn
}
```

**Alarms**:
```hcl
# Error rate alarm
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.environment}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors lambda error rate"
  
  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### X-Ray Tracing

**Configuration**:
```hcl
# Enable X-Ray tracing
lambda_tracing_config = {
  mode = var.enable_xray_tracing ? "Active" : "PassThrough"
}

# X-Ray service map
resource "aws_xray_sampling_rule" "idp_sampling" {
  rule_name      = "${var.environment}-idp-sampling"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"
}
```

## Environment Promotion

### Development to Staging

**Validation Checklist**:
- [ ] All tests pass
- [ ] Security scan completed
- [ ] Performance benchmarks met
- [ ] Documentation updated

**Promotion Process**:
```bash
# 1. Tag the release
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# 2. Deploy to staging
cd terraform/environments/staging
terraform plan -var-file="terraform.tfvars"
terraform apply

# 3. Run integration tests
./scripts/run-integration-tests.sh staging

# 4. Validate deployment
./scripts/validate-deployment.sh staging
```

## Backup and Recovery

### State File Backup

**S3 Backend Configuration**:
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-${var.environment}"
    key            = "idp-accelerator/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-${var.environment}"
    
    # Versioning enabled on bucket
    versioning = true
  }
}
```

### Data Backup

**Automated Backups**:
```hcl
# DynamoDB backup
resource "aws_dynamodb_table" "documents" {
  point_in_time_recovery {
    enabled = true
  }
}

# S3 cross-region replication
resource "aws_s3_bucket_replication_configuration" "documents" {
  count = var.enable_cross_region_replication ? 1 : 0
  
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.documents.id
  
  rule {
    id     = "replicate-all"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.documents_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

---

Next: [Monitoring Setup](monitoring.md) | [Best Practices](best-practices.md)
