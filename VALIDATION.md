# Terraform Validation and Best Practices

This document outlines the validation tools and best practices implemented in this repository, following the [AWS IA Terraform Standards](https://aws-ia.github.io/standards-terraform/).

## Overview

Our validation pipeline includes multiple layers of checks to ensure code quality, security, and compliance:

- **Terraform Format**: Ensures consistent code formatting
- **Terraform Validate**: Validates syntax and configuration
- **TFLint**: Advanced linting with AWS-specific rules
- **TFSec**: Security scanning for potential vulnerabilities
- **Documentation**: Automated documentation generation and validation

## Tools and Configuration

### 1. TFLint Configuration

**File**: `.tflint.hcl`

TFLint provides advanced linting capabilities with AWS-specific rules:

- **Terraform Plugin**: General Terraform best practices
- **AWS Plugin**: AWS-specific validations and checks
- **Deep Check Mode**: Comprehensive analysis including module inspection
- **Parallel Execution**: Faster validation with multiple runners

Key rules enabled:
- Deprecated syntax detection
- Unused variable/output detection
- Naming convention enforcement (snake_case)
- Module structure validation
- AWS resource validation

### 2. TFSec Configuration

**Directory**: `.tfsec/`

TFSec performs static security analysis:

- **Minimum Severity**: MEDIUM (configurable)
- **Custom Exclusions**: Documented exceptions in `.tfsecignore`
- **AWS Focus**: Comprehensive AWS security checks
- **SARIF Output**: Integration with GitLab security dashboard

Key security areas:
- S3 bucket encryption and access controls
- IAM policy validation
- Security group rules
- RDS encryption requirements
- Lambda security configurations

### 3. Pre-commit Hooks

**File**: `.pre-commit-config.yaml`

Local development hooks that run before commits:

- Terraform formatting and validation
- Security scanning
- Documentation generation
- General file hygiene (trailing whitespace, etc.)
- Markdown linting

## GitLab CI/CD Pipeline

### Pipeline Stages

1. **Validate Stage**
   - `terraform-fmt`: Format checking
   - `terraform-validate`: Configuration validation
   - `terraform-lint`: TFLint analysis
   - `terraform-security`: TFSec security scan
   - `terraform-docs`: Documentation validation
   - `terraform-quality-gate`: Combined quality gate

2. **Test Stage**
   - Documentation build testing

3. **Build Stage**
   - Documentation generation

4. **Deploy Stage**
   - GitLab Pages deployment

### Trigger Rules

Validation jobs run on:
- **Merge Requests**: When Terraform files are changed
- **Main Branch**: All pushes to main
- **Manual Triggers**: Can be run manually

### Artifacts and Reports

- **TFLint Reports**: JUnit format for GitLab integration
- **TFSec Reports**: SARIF format for security dashboard
- **Documentation**: Generated and deployed to GitLab Pages

## Local Development

### Quick Start

```bash
# Install all required tools
make install-tools

# Setup pre-commit hooks
make setup-pre-commit

# Run all validation checks
make all
```

### Individual Commands

```bash
# Format Terraform files
make fmt

# Validate configurations
make validate

# Run linting
make lint

# Run security scan
make security

# Generate documentation
make docs

# Clean temporary files
make clean
```

### Check Specific Components

```bash
# Check a specific module
make check-module MODULE=modules/web-ui

# Check a specific example
make check-example EXAMPLE=examples/bedrock-llm-processor
```

## Configuration Customization

### TFLint Customization

Edit `.tflint.hcl` to:
- Enable/disable specific rules
- Add custom rules
- Configure AWS plugin settings
- Adjust parallel execution

```hcl
# Example: Disable a specific rule
rule "terraform_naming_convention" {
  enabled = false
}

# Example: Configure AWS plugin
plugin "aws" {
  enabled = true
  version = "0.31.0"
  deep_check = true
}
```

### TFSec Customization

Edit `.tfsec/config.yml` to:
- Adjust minimum severity level
- Add custom exclusions
- Configure output formats
- Enable/disable rule sets

```yaml
# Example: Lower severity threshold
minimum_severity: LOW

# Example: Exclude specific paths
exclude_paths:
  - "test/**"
  - "examples/**"
```

### Adding Exceptions

Use `.tfsec/.tfsecignore` for documented exceptions:

```
# Format: CHECK_ID:file_path:line_range  # Justification
AWS001:modules/web-ui/s3.tf:45-50  # S3 bucket intentionally public for CloudFront
```

## Best Practices

### Module Development

1. **Structure**: Follow standard module structure
   ```
   modules/my-module/
   ├── main.tf
   ├── variables.tf
   ├── outputs.tf
   ├── versions.tf
   └── README.md
   ```

2. **Documentation**: Use terraform-docs format
   ```hcl
   variable "example" {
     description = "Example variable description"
     type        = string
     default     = "default-value"
   }
   ```

3. **Naming**: Use snake_case for all resources and variables

4. **Versioning**: Pin module sources and provider versions

### Security Practices

1. **Encryption**: Enable encryption for all data stores
2. **IAM**: Follow least privilege principle
3. **Network**: Use private subnets where possible
4. **Logging**: Enable CloudTrail and VPC Flow Logs
5. **Secrets**: Use AWS Secrets Manager or Parameter Store

### Code Quality

1. **Formatting**: Always run `terraform fmt`
2. **Validation**: Test with `terraform validate`
3. **Linting**: Address TFLint warnings
4. **Security**: Fix TFSec findings
5. **Documentation**: Keep README files updated

## Troubleshooting

### Common Issues

#### TFLint Plugin Installation
```bash
# If AWS plugin fails to install
tflint --init
```

#### TFSec False Positives
```bash
# Add to .tfsecignore with justification
echo "AWS001:path/to/file.tf:10-15  # Justified exception" >> .tfsec/.tfsecignore
```

#### Pre-commit Hook Failures
```bash
# Skip hooks temporarily (not recommended)
git commit --no-verify

# Fix and re-run
pre-commit run --all-files
```

### Getting Help

1. **Tool Documentation**:
   - [TFLint Rules](https://github.com/terraform-linters/tflint/tree/master/docs/rules)
   - [TFSec Checks](https://aquasecurity.github.io/tfsec/latest/checks/)
   - [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

2. **AWS IA Standards**: [AWS IA Terraform Standards](https://aws-ia.github.io/standards-terraform/)

3. **Repository Issues**: Create an issue in this repository for project-specific questions

## Continuous Improvement

This validation setup is continuously improved based on:
- AWS IA standard updates
- New tool versions and capabilities
- Team feedback and requirements
- Security best practice evolution

Regular reviews ensure our standards remain current and effective.

## Integration with IDEs

### VS Code

Recommended extensions:
- HashiCorp Terraform
- TFLint extension
- GitLab Workflow

### IntelliJ/PyCharm

Recommended plugins:
- Terraform and HCL plugin
- AWS Toolkit

### Vim/Neovim

Recommended plugins:
- vim-terraform
- ale (with TFLint integration)
