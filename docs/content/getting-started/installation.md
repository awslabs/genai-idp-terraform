# Installation

This guide walks you through setting up your development environment and cloning the GenAI IDP Accelerator for Terraform.

## Clone the Repository

First, clone the GenAI IDP Accelerator repository to your local machine:

```bash
git clone https://gitlab.aws.dev/gciupryk/genaiic-idp-accelerator-terraform.git
cd genaiic-idp-accelerator-terraform
```

## Repository Structure

After cloning, you'll see the following structure:

```
genaiic-idp-accelerator-terraform/
├── modules/                           # Terraform modules
│   ├── concurrency-table/            # DynamoDB concurrency management
│   ├── configuration-table/          # Configuration storage
│   ├── idp-common-layer/             # Shared Lambda layer
│   ├── knowledge-base/               # Knowledge base integration
│   ├── lambda-functions/             # Core Lambda functions
│   ├── lambda-layer-codebuild/       # Lambda layer builder
│   ├── lambda-layer-codebuild-idp/   # IDP-specific layer builder
│   ├── monitoring/                   # CloudWatch monitoring
│   ├── processing-environment/       # Core processing infrastructure
│   ├── processing-environment-api/   # GraphQL API
│   ├── processor-attachment/         # Processor integration
│   ├── processors/                   # Document processors
│   │   ├── bda-processor/           # Bedrock Data Automation
│   │   ├── bedrock-llm-processor/   # Bedrock LLM processing
│   │   └── sagemaker-udop-processor/ # SageMaker UDOP model
│   ├── tracking-table/              # Document tracking
│   ├── user-identity/               # Cognito authentication
│   └── web-ui/                      # Web interface
├── examples/                        # Example implementations
│   ├── bda-processor/              # BDA processor example
│   ├── bedrock-llm-processor/      # Bedrock LLM example
│   ├── core-tables/                # Core DynamoDB tables
│   ├── processing-environment/     # Processing infrastructure
│   ├── processing-environment-api/ # API-only deployment
│   ├── sagemaker-udop-processor/   # SageMaker UDOP example
│   └── user-identity-standalone/   # Standalone authentication
├── sources/                        # Lambda source code and assets
├── docs/                          # Documentation
├── README.md
├── LICENSE
└── CONTRIBUTING.md
```

## Environment Setup

### 1. Configure AWS Credentials

Ensure your AWS credentials are properly configured:

```bash
# Option 1: Using AWS CLI
aws configure

# Option 2: Using environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option 3: Using AWS profiles
export AWS_PROFILE="your-profile-name"
```

### 2. Verify AWS Access

Test your AWS access:

```bash
# Check current AWS identity
aws sts get-caller-identity

# List available regions
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

### 3. Initialize Terraform Backend (Optional)

For team collaboration, set up remote state storage:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket-name

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

Then create a `backend.tf` file in your working directory:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket-name"
    key            = "genai-idp/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Terraform Provider Configuration

The modules use the following Terraform providers:

```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}
```

## Verify Installation

### 1. Check Terraform Configuration

Navigate to an example directory and verify the configuration:

```bash
cd examples/bedrock-llm-processor
terraform init
terraform validate
terraform plan
```

### 2. Test Module Access

Verify you can access the modules:

```bash
# From the root directory
terraform init
terraform validate
```

## Development Environment (Optional)

### VS Code Setup

If using VS Code, install these recommended extensions:

```json
{
  "recommendations": [
    "hashicorp.terraform",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "ms-python.python"
  ]
}
```

### Pre-commit Hooks

Set up pre-commit hooks for code quality:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

## Troubleshooting

### Common Issues

#### Terraform Provider Download Issues
```bash
# Clear provider cache
rm -rf .terraform
terraform init
```

#### AWS Credentials Issues
```bash
# Verify credentials
aws sts get-caller-identity

# Check AWS CLI configuration
aws configure list
```

#### Permission Issues
Ensure your AWS user/role has the required permissions listed in [Prerequisites](prerequisites.md).

### Getting Help

If you encounter issues:

1. Check the [troubleshooting guide](../deployment-guides/troubleshooting.md)
2. Review [common errors](../faqs/index.md)
3. Open an issue in the repository

## Next Steps

With your environment set up, you're ready to deploy your first solution! Continue to the [Quick Start](quick-start.md) guide to deploy a basic document processing pipeline.
