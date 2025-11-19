# Development Guide

This guide covers the development workflow for contributing to the GenAI IDP Accelerator.

## Development Environment Setup

### Prerequisites

Before starting development, ensure you have:
- **Terraform** (version 1.0+)
- **AWS CLI** configured with appropriate permissions
- **Git** for version control
- **Code editor** with Terraform support (VS Code recommended)
- **Docker** (optional, for local testing)

### Local Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/genaiic-idp-accelerator-terraform.git
   cd genaiic-idp-accelerator-terraform
   ```

2. **Set up development environment**:
   ```bash
   # Create development workspace
   terraform workspace new dev
   
   # Copy example configuration
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit configuration for your environment
   vim terraform.tfvars
   ```

3. **Install development tools**:
   ```bash
   # Install pre-commit hooks
   pip install pre-commit
   pre-commit install
   
   # Install Terraform linting tools
   brew install tflint
   brew install tfsec
   ```

## Project Structure

### Directory Layout

```
genaiic-idp-accelerator-terraform/
├── modules/                    # Reusable Terraform modules
│   ├── lambda-processor/      # Lambda function module
│   ├── api-gateway/          # API Gateway module
│   ├── storage/              # S3 and DynamoDB module
│   └── monitoring/           # CloudWatch module
├── examples/                 # Example deployments
│   ├── bedrock-llm-processor/   # Bedrock LLM example
│   └── bda-processor/         # BDA processor example
├── environments/             # Environment-specific configs
│   ├── dev/                 # Development environment
│   └── staging/             # Staging environment
├── scripts/                 # Utility scripts
├── docs/                    # Documentation
└── tests/                   # Test files
```

### Module Structure

Each module follows this structure:
```
modules/lambda-processor/
├── main.tf                  # Main resource definitions
├── variables.tf             # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider requirements
├── README.md               # Module documentation
└── examples/               # Usage examples
```

## Development Workflow

### Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Follow Terraform best practices
   - Update documentation
   - Add tests where appropriate

3. **Test your changes**:
   ```bash
   # Validate Terraform syntax
   terraform validate
   
   # Check formatting
   terraform fmt -check
   
   # Run security checks
   tfsec .
   
   # Run linting
   tflint
   ```

4. **Test deployment**:
   ```bash
   # Plan deployment
   terraform plan -var-file="dev.tfvars"
   
   # Apply to development environment
   terraform apply -var-file="dev.tfvars"
   
   # Test functionality
   ./scripts/test-deployment.sh
   ```

### Code Standards

#### Terraform Style Guide

**Naming Conventions**:
```hcl
# Use snake_case for resources and variables
resource "aws_lambda_function" "document_processor" {
  function_name = "${var.environment}_idp_processor"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function"
  type        = number
  default     = 1024
}
```

**Resource Organization**:
```hcl
# Group related resources together
# Use consistent naming patterns
# Add meaningful descriptions

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.environment}-idp-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}
```

**Variable Definitions**:
```hcl
variable "environment" {
  description = "Environment name (dev, staging)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging"], var.environment)
    error_message = "Environment must be dev or staging."
  }
}

variable "lambda_config" {
  description = "Lambda function configuration"
  type = object({
    memory_size = number
    timeout     = number
    runtime     = string
  })
  
  default = {
    memory_size = 1024
    timeout     = 300
    runtime     = "python3.9"
  }
}
```

#### Documentation Standards

**Module Documentation**:
```markdown
# Lambda Processor Module

This module creates AWS Lambda functions for document processing.

## Usage

```hcl
module "lambda_processor" {
  source = "./modules/lambda-processor"
  
  environment = "dev"
  lambda_config = {
    memory_size = 1024
    timeout     = 300
    runtime     = "python3.9"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| lambda_config | Lambda configuration | `object` | see below | no |
```

### Testing

#### Unit Testing

Use `terraform validate` and `terraform plan` for basic testing:
```bash
# Test module validation
cd modules/lambda-processor
terraform init
terraform validate

# Test with example configuration
terraform plan -var-file="../../examples/bedrock-llm-processor/terraform.tfvars"
```

#### Integration Testing

Create test scripts for end-to-end testing:
```bash
#!/bin/bash
# scripts/test-deployment.sh

set -e

echo "Testing deployment..."

# Deploy to test environment
terraform apply -var-file="test.tfvars" -auto-approve

# Wait for deployment to complete
sleep 30

# Test API endpoints
curl -X POST "${API_ENDPOINT}/documents" \
  -H "Content-Type: application/json" \
  -d '{"document_key": "test-document.pdf"}'

# Check processing results
aws dynamodb get-item \
  --table-name "${TABLE_NAME}" \
  --key '{"document_id": {"S": "test-document"}}'

echo "Tests passed!"

# Cleanup
terraform destroy -var-file="test.tfvars" -auto-approve
```

#### Automated Testing

Use GitHub Actions or similar for CI/CD:
```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Validate
        run: |
          terraform init
          terraform validate
      
      - name: Security Scan
        run: |
          docker run --rm -v $(pwd):/src aquasec/tfsec /src
      
      - name: Integration Test
        run: ./scripts/test-deployment.sh
        env:
          AWS_ACCESS_KEY_ID: ${{'{{'}} secrets.AWS_ACCESS_KEY_ID {{'}}'}}
          AWS_SECRET_ACCESS_KEY: ${{'{{'}} secrets.AWS_SECRET_ACCESS_KEY {{'}}'}}
```

## Contributing Guidelines

### Pull Request Process

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test thoroughly**
5. **Update documentation**
6. **Submit pull request**

### Pull Request Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Terraform validate passes
- [ ] Terraform plan succeeds
- [ ] Integration tests pass
- [ ] Documentation updated

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added/updated
```

### Code Review Guidelines

**For Reviewers**:
- Check for security best practices
- Verify resource naming consistency
- Ensure proper error handling
- Review cost implications
- Validate documentation updates

**For Contributors**:
- Respond to feedback promptly
- Make requested changes
- Update tests if needed
- Ensure CI/CD passes

## Debugging and Troubleshooting

### Common Development Issues

**Terraform State Issues**:
```bash
# Refresh state
terraform refresh

# Import existing resources
terraform import aws_s3_bucket.example bucket-name

# Remove resource from state
terraform state rm aws_s3_bucket.example
```

**Provider Version Conflicts**:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
```

**Module Path Issues**:
```hcl
# Use relative paths for local modules
module "lambda_processor" {
  source = "../modules/lambda-processor"
}

# Use Git URLs for remote modules
module "lambda_processor" {
  source = "git::https://github.com/org/repo.git//modules/lambda-processor?ref=v1.0.0"
}
```

### Development Tools

**VS Code Extensions**:
- HashiCorp Terraform
- AWS Toolkit
- GitLens
- Prettier

**Useful Commands**:
```bash
# Format all Terraform files
terraform fmt -recursive

# Generate dependency graph
terraform graph | dot -Tpng > graph.png

# Show current state
terraform show

# List resources in state
terraform state list
```

## Release Process

### Versioning

Follow semantic versioning (SemVer):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Creating Releases

1. **Update version numbers**
2. **Update CHANGELOG.md**
3. **Create Git tag**:
   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```
4. **Create GitHub release**
5. **Update documentation**

---

For more information, see:
- [Testing Guide](testing.md)
- [Documentation Guide](documentation.md)
- [Contributing Guidelines](index.md)
