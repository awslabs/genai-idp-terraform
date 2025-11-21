# Best Practices

This guide covers recommended practices for deploying and operating the GenAI IDP Accelerator with Terraform.

## Deployment Best Practices

### Environment Management

**Use Separate Environments**:

```hcl
# terraform/environments/dev/terraform.tfvars
environment = "dev"
region = "us-east-1"

# Reduced resources for development
lambda_memory_size = 512
lambda_timeout = 60
enable_detailed_monitoring = false
```

**Consistent Tagging**:

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = "genai-idp-accelerator"
    Owner       = var.owner
    Terraform   = "true"
  }
}
```

### State Management

**Remote State Backend**:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-${var.environment}"
    key            = "idp-accelerator/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**State Locking**:

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

## Security Best Practices

### IAM Permissions

**Least Privilege Principle**:

```hcl
resource "aws_iam_policy" "lambda_policy" {
  name = "${var.environment}-idp-lambda-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
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

### Data Protection

**Encryption at Rest**:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Encryption in Transit**:

- Use HTTPS for all API endpoints
- Enable SSL/TLS for data transfer
- Use VPC endpoints where possible

## Performance Best Practices

### Lambda Optimization

**Memory and Timeout Settings**:

```hcl
resource "aws_lambda_function" "document_processor" {
  memory_size = 1024  # Adjust based on workload
  timeout     = 300   # 5 minutes for document processing
  
  environment {
    variables = {
      POWERTOOLS_LOG_LEVEL = "INFO"
    }
  }
}
```

**Connection Reuse**:

```python
import boto3

# Initialize clients outside handler for reuse
s3_client = boto3.client('s3')
textract_client = boto3.client('textract')

def lambda_handler(event, context):
    # Use pre-initialized clients
    response = textract_client.detect_document_text(...)
```

### Storage Optimization

**S3 Lifecycle Policies**:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "documents_lifecycle" {
  bucket = aws_s3_bucket.documents.id
  
  rule {
    id     = "transition_to_ia"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}
```

## Monitoring Best Practices

### CloudWatch Configuration

**Log Groups**:

```hcl
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.environment}-idp-processor"
  retention_in_days = var.log_retention_days
}
```

**Alarms**:

```hcl
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

## Operational Best Practices

### Deployment Process

**Validation Steps**:

1. Run `terraform plan` and review changes
2. Test in development environment first
3. Use gradual rollout for staging
4. Monitor deployment metrics

**Rollback Strategy**:

```bash
# Keep previous state file versions
terraform state pull > terraform.tfstate.backup

# Quick rollback if needed
terraform apply -target=aws_lambda_function.processor \
  -var="lambda_version=previous"
```

### Documentation

**Infrastructure Documentation**:

- Document all custom configurations
- Maintain architecture diagrams
- Keep runbooks updated
- Record operational procedures

### Backup and Recovery

**State File Backup**:

```hcl
resource "aws_s3_bucket_versioning" "state_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

**Data Backup**:

```hcl
resource "aws_dynamodb_table" "documents" {
  point_in_time_recovery {
    enabled = true
  }
}
```

## Testing Best Practices

### Infrastructure Testing

**Validation**:

```bash
# Validate Terraform configuration
terraform validate

# Check formatting
terraform fmt -check

# Security scanning
tfsec .
```

**Integration Testing**:

```bash
# Test deployment in staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"

# Run smoke tests
./scripts/smoke-tests.sh staging
```

## Troubleshooting

### Common Issues

**Permission Errors**:

- Check IAM policies and roles
- Verify service-linked roles exist
- Review resource policies

**Resource Limits**:

- Check AWS service quotas
- Monitor resource utilization
- Request quota increases if needed

**State Issues**:

- Use `terraform refresh` to sync state
- Import existing resources if needed
- Handle state lock conflicts

### Debugging Tools

**Terraform Debugging**:

```bash
export TF_LOG=DEBUG
terraform apply
```

**AWS CLI Debugging**:

```bash
aws logs describe-log-groups --debug
aws lambda get-function --function-name processor --debug
```

## Maintenance

### Regular Tasks

**Weekly**:

- Review CloudWatch alarms and metrics
- Update documentation as needed

**Monthly**:

- Review and update IAM permissions
- Analyze performance metrics
- Plan capacity adjustments

**Quarterly**:

- Security review and updates
- Disaster recovery testing
- Architecture review

### Updates and Patches

**Terraform Updates**:

```bash
# Update Terraform version
terraform version
terraform init -upgrade

# Update provider versions
terraform init -upgrade
```

**Lambda Runtime Updates**:

```hcl
resource "aws_lambda_function" "processor" {
  runtime = "python3.11"  # Keep updated
}
```

---

For more detailed information, see:

- [Environment Setup](environment-setup.md)
- [Monitoring Guide](monitoring.md)
- [Troubleshooting Guide](troubleshooting.md)
