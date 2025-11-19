# Deployment Questions

Frequently asked questions about deploying the GenAI IDP Accelerator.

## First Deployment

### What do I need before starting?

Before your first deployment, ensure you have:
- AWS account with administrative permissions
- Terraform installed (version 1.0 or later)
- AWS CLI configured with credentials
- Access to Amazon Bedrock models in your region
- S3 bucket for Terraform state (recommended)

### How do I request Bedrock model access?

1. Go to the Amazon Bedrock console
2. Navigate to "Model access" in the left sidebar
3. Click "Request model access"
4. Select the models you need (Claude, Titan, etc.)
5. Submit the request and wait for approval (usually immediate)

### What regions are supported?

The accelerator works in any AWS region that supports:
- Amazon Bedrock
- Amazon Textract
- AWS Lambda
- Amazon S3
- Amazon DynamoDB

Popular regions include: `us-east-1`, `us-west-2`, `eu-west-1`, `ap-southeast-1`

### How long does deployment take?

Typical deployment times:
- **Initial deployment**: 10-15 minutes
- **Updates**: 5-10 minutes
- **Destroy**: 5-10 minutes

Times may vary based on region and resource complexity.

## Configuration

### How do I customize the deployment?

Create a `terraform.tfvars` file with your settings:
```hcl
environment = "dev"
region = "us-east-1"
project_name = "my-idp-project"

# Lambda configuration
lambda_memory_size = 1024
lambda_timeout = 300

# Storage configuration
s3_bucket_prefix = "my-company-idp"
```

### Can I use existing AWS resources?

Yes, you can reference existing resources:
```hcl
# Use existing VPC
vpc_id = "vpc-12345678"
subnet_ids = ["subnet-12345678", "subnet-87654321"]

# Use existing S3 bucket
existing_s3_bucket = "my-existing-bucket"

# Use existing DynamoDB table
existing_dynamodb_table = "my-existing-table"
```

### How do I configure different environments?

Create separate directories for each environment:
```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   └── staging/
│       ├── main.tf
│       └── terraform.tfvars
```

## State Management

### Should I use remote state?

Yes, always use remote state for shared environments:
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "idp-accelerator/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-locks"
  }
}
```

### How do I handle state conflicts?

If you encounter state lock issues:
```bash
# Check who has the lock
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"my-state-file"}}'

# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

### Can I import existing resources?

Yes, you can import existing AWS resources:
```bash
# Import existing S3 bucket
terraform import aws_s3_bucket.documents my-existing-bucket

# Import existing Lambda function
terraform import aws_lambda_function.processor my-existing-function
```

## Updates and Maintenance

### How do I update the accelerator?

1. Update your Terraform configuration
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply updates
4. Monitor the deployment for issues

### How do I handle breaking changes?

Before major updates:
1. Backup your Terraform state
2. Test in a development environment
3. Review the changelog for breaking changes
4. Plan for potential downtime
5. Have a rollback strategy ready

### Can I rollback a deployment?

Yes, you can rollback using:
```bash
# Restore previous state file
cp terraform.tfstate.backup terraform.tfstate

# Apply previous configuration
git checkout previous-version
terraform apply
```

## Troubleshooting

### Common deployment errors?

**Permission denied errors**:
- Check IAM permissions
- Verify AWS credentials
- Ensure service-linked roles exist

**Resource already exists**:
- Import existing resources
- Use different resource names
- Check for naming conflicts

**Timeout errors**:
- Increase timeout values
- Check network connectivity
- Verify service availability

### How do I debug deployment issues?

Enable detailed logging:
```bash
export TF_LOG=DEBUG
terraform apply
```

Check AWS CloudTrail for API calls and errors.

### What if deployment fails halfway?

Terraform handles partial failures gracefully:
1. Fix the underlying issue
2. Run `terraform apply` again
3. Terraform will continue from where it left off
4. Use `terraform refresh` if state is inconsistent

## Performance

### How do I optimize deployment speed?

- Use `-parallelism` flag: `terraform apply -parallelism=20`
- Enable provider caching
- Use smaller resource sets for testing
- Deploy in regions closer to you

### Can I deploy multiple environments simultaneously?

Yes, but be careful with:
- Resource limits and quotas
- API rate limits
- State file conflicts
- Naming collisions

Use separate state files and workspaces for each environment.

## Security

### What permissions does Terraform need?

Terraform needs permissions to create and manage:
- IAM roles and policies
- Lambda functions
- S3 buckets
- DynamoDB tables
- API Gateway resources
- CloudWatch logs and alarms

Use the principle of least privilege and consider using cross-account roles.

### How do I secure sensitive variables?

Use Terraform's sensitive variables:
```hcl
variable "api_key" {
  description = "API key for external service"
  type        = string
  sensitive   = true
}
```

Or use AWS Systems Manager Parameter Store:
```hcl
data "aws_ssm_parameter" "api_key" {
  name = "/idp/api-key"
}
```

---

For more deployment help, see:
- [Environment Setup Guide](../deployment-guides/environment-setup.md)
- [Troubleshooting Guide](../deployment-guides/troubleshooting.md)
- [Best Practices](../deployment-guides/best-practices.md)
