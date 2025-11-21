# Contributing to GenAI IDP Accelerator for Terraform

Welcome to the GenAI IDP Accelerator for Terraform repository! This document provides comprehensive guidance for contributors working on the Terraform implementation of the GenAI **Intelligent Document Processing** (IDP) Accelerator.

## Code of Conduct

This project adheres to the [Amazon Open Source Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to <opensource-codeofconduct@amazon.com>.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Development Guidelines](#development-guidelines)
- [Module-Specific Documentation](#module-specific-documentation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Best Practices](#best-practices)
- [Contributing Workflow](#contributing-workflow)
- [Security](#security)

## Overview

This repository contains the Terraform implementation of the GenAI IDP Accelerator, which provides **Intelligent Document Processing** capabilities using various AWS services including Amazon Bedrock, SageMaker, Textract, and Step Functions.

### Key Features

- **Multiple Processing Patterns**: Support for BDA, Bedrock LLM, and SageMaker UDOP processors
- **Modular Architecture**: Reusable Terraform modules for different components
- **Configurable Workflows**: Flexible configuration system for different use cases
- **Comprehensive Monitoring**: Built-in monitoring and alerting capabilities
- **Security Best Practices**: Encryption, IAM least privilege, and network security

### Relationship to CDK Implementation

This Terraform implementation is based on the AWS CDK version located in the adjacent `genaiic-idp-accelerator-cdk` directory. The `sources/` directory in the CDK repository contains the core GenAI IDP Accelerator solution implemented by data scientists and should not be modified as part of this Terraform implementation.

## Repository Structure

```
genai-idp-terraform/
├── modules/                           # Reusable Terraform modules
│   ├── processors/                    # Document processing patterns
│   │   ├── bda-processor/            # Pattern 1: Bedrock Data Automation
│   │   ├── bedrock-llm-processor/    # Pattern 2: Bedrock LLM Classification & Extraction
│   │   └── sagemaker-udop-processor/ # Pattern 3: UDOP Classification + Claude Extraction
│   ├── processing-environment/        # Core processing infrastructure
│   ├── processing-environment-api/    # GraphQL API for processing management
│   ├── web-ui/                       # Web interface for document processing
│   ├── knowledge-base/               # Vector database for RAG capabilities
│   ├── monitoring/                   # CloudWatch dashboards and alarms
│   └── [other modules]/             # Supporting infrastructure modules
├── examples/                         # Example deployments and configurations
│   ├── bda-processor/               # BDA processor example
│   ├── bedrock-llm-processor/       # Bedrock LLM processor example
│   ├── sagemaker-udop-processor/    # SageMaker UDOP processor example
│   └── [other examples]/           # Additional example configurations
├── README.md                        # Repository overview and setup instructions
└── CONTRIBUTING.md                  # This file
```

## Getting Started

### Prerequisites

1. **Terraform**: Version 1.0 or later
2. **AWS CLI**: Configured with appropriate credentials
3. **AWS Permissions**: Required permissions for all AWS services used
4. **Model Access**: Enable access to required Bedrock models in AWS Console

### Initial Setup

1. **Clone Repository**:

   ```bash
   git clone <repository-url>
   cd genai-idp-terraform
   ```

2. **Choose Example**: Navigate to the appropriate example directory:

   ```bash
   cd examples/bedrock-llm-processor  # or bda-processor, sagemaker-udop-processor
   ```

3. **Configure Variables**: Copy and modify the example configuration:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

4. **Initialize Terraform**:

   ```bash
   terraform init
   ```

5. **Plan and Apply**:

   ```bash
   terraform plan
   terraform apply
   ```

## Development Guidelines

### Terraform Standards

1. **Code Style**: Follow HashiCorp's Terraform style guide
2. **Formatting**: Use `terraform fmt` to format code consistently
3. **Validation**: Run `terraform validate` before committing
4. **Documentation**: Maintain comprehensive variable and output descriptions

### Variable Naming Conventions

- Use `snake_case` for all variable names
- Prefix boolean variables with `is_`, `enable_`, or `has_`
- Use descriptive names that indicate purpose and type
- Group related variables logically

```hcl
variable "processing_environment_name" {
  description = "Name for the processing environment resources"
  type        = string
}

variable "is_summarization_enabled" {
  description = "Controls whether document summarization is enabled"
  type        = bool
  default     = false
}

variable "max_processing_concurrency" {
  description = "Maximum number of concurrent document processing tasks"
  type        = number
  default     = 100
}
```

### Resource Naming

Follow consistent naming patterns across all modules:

```hcl
resource "aws_lambda_function" "document_processor" {
  function_name = "${var.name}-document-processor"
  # ...
}

resource "aws_s3_bucket" "processing_bucket" {
  bucket = "${var.name}-processing-${random_id.suffix.hex}"
  # ...
}
```

### Module Structure

Each module should follow this structure:

```
module-name/
├── main.tf          # Main resource definitions
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider version constraints
├── README.md        # Module documentation
├── CONTRIBUTING.md  # Contributor guidance (for complex modules)
└── [other files]    # Additional configuration files
```

## Module-Specific Documentation

Each major module includes detailed contributor documentation:

### Processor Modules

- **[BDA Processor](modules/processors/bda-processor/CONTRIBUTING.md)**: Pattern 1 implementation using Bedrock Data Automation
- **[Bedrock LLM Processor](modules/processors/bedrock-llm-processor/CONTRIBUTING.md)**: Pattern 2 implementation using Bedrock models for classification and extraction
- **[SageMaker UDOP Processor](modules/processors/sagemaker-udop-processor/CONTRIBUTING.md)**: Pattern 3 implementation using UDOP for classification and Bedrock for extraction

### Core Infrastructure Modules

- **Processing Environment**: Core infrastructure for document processing
- **Processing Environment API**: GraphQL API for managing processing workflows
- **Web UI**: React-based web interface for document processing
- **Knowledge Base**: Vector database integration for RAG capabilities
- **Monitoring**: CloudWatch dashboards and alerting

## Testing

### Local Testing

1. **Terraform Validation**:

   ```bash
   terraform fmt -check
   terraform validate
   terraform plan
   ```

2. **Module Testing**: Use example configurations to test modules:

   ```bash
   cd examples/bedrock-llm-processor
   terraform init
   terraform plan
   ```

3. **Lambda Function Testing**: Use SAM CLI for local Lambda testing:

   ```bash
   sam local invoke FunctionName --env-vars env.json -e event.json
   ```

### Integration Testing

1. **Deploy Test Environment**: Use example configurations
2. **Upload Test Documents**: Use sample documents for testing
3. **Monitor Execution**: Check Step Functions, CloudWatch, and other AWS services
4. **Validate Results**: Verify processing results and output formats

### Automated Testing

Consider implementing automated tests using tools like:

- **Terratest**: For infrastructure testing
- **pytest**: For Lambda function unit tests
- **Checkov**: For security and compliance scanning

## Deployment

### Environment Management

1. **Development**: Use minimal configurations for development and testing
2. **Staging**: Mirror production configuration with reduced scale
3. **Production**: Full-scale deployment with comprehensive monitoring

### Configuration Management

1. **Terraform Variables**: Use `.tfvars` files for environment-specific configuration
2. **Custom Configuration**: Use module `custom_config` variables for runtime configuration
3. **Secrets Management**: Use AWS Secrets Manager or Parameter Store for sensitive data

### Deployment Pipeline

Consider implementing a CI/CD pipeline with:

1. **Code Validation**: Terraform fmt, validate, and security scanning
2. **Plan Review**: Automated plan generation and review
3. **Staged Deployment**: Deploy to development, then staging, then production
4. **Rollback Capability**: Maintain ability to rollback changes

## Best Practices

### Security

1. **Least Privilege**: Use minimal IAM permissions for all resources
2. **Encryption**: Enable encryption at rest and in transit for all data
3. **Network Security**: Use VPC endpoints and security groups appropriately
4. **Secrets Management**: Never hardcode secrets in Terraform code

### Performance

1. **Resource Sizing**: Right-size Lambda functions, SageMaker endpoints, and other resources
2. **Concurrency Management**: Configure appropriate concurrency limits
3. **Caching**: Implement caching where beneficial
4. **Monitoring**: Set up comprehensive monitoring and alerting

### Cost Optimization

1. **Auto-Scaling**: Implement auto-scaling for variable workloads
2. **Resource Lifecycle**: Use appropriate retention policies
3. **Monitoring**: Track costs and usage patterns
4. **Optimization**: Regular review and optimization of resources

### Reliability

1. **Error Handling**: Implement comprehensive error handling and retry logic
2. **Dead Letter Queues**: Use DLQs for async operations
3. **Health Checks**: Implement health monitoring for all components
4. **Backup and Recovery**: Implement appropriate backup strategies

### Maintainability

1. **Documentation**: Maintain comprehensive documentation
2. **Code Organization**: Use consistent code organization patterns
3. **Version Control**: Use semantic versioning for modules
4. **Testing**: Implement comprehensive testing strategies

## Contributing Workflow

### Development Process

1. **Fork Repository**: Create a personal fork for development
2. **Create Feature Branch**: Use descriptive branch names (e.g., `feature/add-new-processor`)
3. **Make Changes**: Follow development guidelines and best practices
4. **Test Thoroughly**: Run all applicable tests
5. **Update Documentation**: Update relevant documentation
6. **Submit Pull Request**: Include detailed description and test results

### Pull Request Guidelines

1. **Clear Description**: Provide clear description of changes and rationale
2. **Test Results**: Include test results and validation steps
3. **Documentation Updates**: Ensure documentation is updated
4. **Breaking Changes**: Clearly identify any breaking changes
5. **Review Checklist**: Use the provided PR template and checklist

### Code Review Process

1. **Automated Checks**: Ensure all automated checks pass
2. **Peer Review**: At least one peer review required
3. **Security Review**: Security review for sensitive changes
4. **Documentation Review**: Ensure documentation is accurate and complete

### Merge Process

1. **Squash and Merge**: Use squash and merge for clean history
2. **Release Notes**: Update release notes for significant changes
3. **Version Tagging**: Tag releases appropriately
4. **Deployment**: Follow deployment process for changes

## Getting Help

### Resources

- **AWS Documentation**: Comprehensive AWS service documentation
- **Terraform Documentation**: HashiCorp Terraform documentation
- **Module Documentation**: Detailed documentation in each module directory
- **Example Configurations**: Working examples in the `examples/` directory

### Support Channels

- **Issues**: Use GitHub issues for bug reports and feature requests
- **Discussions**: Use GitHub discussions for questions and general discussion
- **Documentation**: Check module-specific CONTRIBUTING.md files for detailed guidance

### Common Issues

1. **Permission Errors**: Ensure AWS credentials and permissions are properly configured
2. **Model Access**: Verify Bedrock model access is enabled in AWS Console
3. **Resource Limits**: Check AWS service limits and quotas
4. **Configuration Errors**: Validate configuration files and variable values

## Security

Security is a top priority for this project. Please review our [Security Policy](SECURITY.md) for:

- How to report security vulnerabilities
- Security best practices when using the solution
- Built-in security features
- Compliance considerations

**Important**: Never commit sensitive information such as:

- AWS credentials or access keys
- API keys or tokens
- Passwords or secrets
- Personal or confidential data

Use AWS Secrets Manager, Parameter Store, or environment variables for sensitive configuration.

## Conclusion

Thank you for contributing to the GenAI IDP Accelerator Terraform implementation! Your contributions help make **Intelligent Document Processing** more accessible and easier to deploy. Please follow these guidelines to ensure high-quality, maintainable code that benefits the entire community.

For specific guidance on individual modules, please refer to the CONTRIBUTING.md files in each module directory.
