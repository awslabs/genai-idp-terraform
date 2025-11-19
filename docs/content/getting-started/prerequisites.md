# Prerequisites

Before you begin deploying the GenAI IDP Accelerator, ensure you have the following prerequisites in place.

## AWS Account Requirements

### AWS Account Access
- An active AWS account with appropriate permissions
- AWS CLI configured with credentials
- Access to the following AWS services:
  - Amazon S3
  - Amazon Textract
  - Amazon Bedrock
  - AWS Lambda
  - Amazon DynamoDB
  - Amazon CloudWatch
  - AWS IAM

### Required AWS Permissions

Your AWS credentials must have permissions to create and manage:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "textract:*",
        "bedrock:*",
        "lambda:*",
        "dynamodb:*",
        "iam:*",
        "cloudwatch:*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

!!! warning "Security Best Practice"
    For enterprise deployments, use more restrictive IAM policies following the principle of least privilege.

## Software Requirements

### Terraform
- **Version**: 1.5.0 or later
- **Installation**: [Download from terraform.io](https://www.terraform.io/downloads)

```bash
# Verify Terraform installation
terraform version
```

### AWS CLI
- **Version**: 2.0 or later
- **Installation**: [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

```bash
# Verify AWS CLI installation
aws --version

# Configure AWS CLI (if not already done)
aws configure
```

### Git
- Required for cloning the repository
- **Installation**: [Git Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## Regional Considerations

### Supported AWS Regions

The GenAI IDP Accelerator supports deployment in regions where all required services are available:

- `us-east-1` (N. Virginia) **Recommended**
- `us-west-2` (Oregon)
- `eu-west-1` (Ireland)
- `ap-southeast-1` (Singapore)

!!! info "Amazon Bedrock Availability"
    Amazon Bedrock is not available in all regions. Check the [AWS Regional Services List](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for current availability.

### Service Quotas

Ensure your AWS account has sufficient service quotas for:

- **Lambda**: Concurrent executions (default: 1,000)
- **Textract**: API requests per second
- **Bedrock**: Model access and API limits
- **S3**: Bucket limits (default: 100)

## Network Requirements

### Internet Access
- Required for downloading Terraform providers
- Required for accessing AWS APIs
- Required for Lambda functions to access AWS services

### VPC Considerations
- Default VPC is sufficient for basic deployments
- Custom VPC configuration available for advanced deployments

## Optional Tools

### Terraform State Management
Consider using remote state storage for team collaboration:

- **AWS S3** + **DynamoDB** for state locking
- **Terraform Cloud**
- **Terraform Enterprise**

### Development Tools
- **VS Code** with Terraform extension
- **terraform-docs** for documentation generation
- **tflint** for Terraform linting

## Verification Checklist

Before proceeding, verify you have:

- [ ] AWS account with appropriate permissions
- [ ] Terraform 1.5.0+ installed
- [ ] AWS CLI 2.0+ installed and configured
- [ ] Git installed
- [ ] Selected a supported AWS region
- [ ] Verified service quotas
- [ ] Internet connectivity

## Next Steps

Once you've completed all prerequisites, proceed to the [Installation](installation.md) guide to set up your development environment.
