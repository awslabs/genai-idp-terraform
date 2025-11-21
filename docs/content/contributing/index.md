# Contributing

We welcome contributions to the GenAI IDP Accelerator for Terraform! This guide will help you get started with contributing to the project, whether you're fixing bugs, adding features, improving documentation, or sharing examples.

## Ways to Contribute

### Bug Reports

Help us improve by reporting bugs you encounter:

- Use the issue template
- Provide detailed reproduction steps
- Include relevant logs and error messages
- Specify your environment details

### Feature Requests

Suggest new features or improvements:

- Describe the use case and problem
- Explain the proposed solution
- Consider backward compatibility
- Provide examples if possible

### Code Contributions

Contribute code improvements:

- Bug fixes
- New modules or features
- Performance optimizations
- Security enhancements

### Documentation

Help improve documentation:

- Fix typos and errors
- Add missing information
- Create new guides and examples
- Improve existing content

### Testing

Enhance testing coverage:

- Add unit tests
- Create integration tests
- Test in different environments
- Validate examples and guides

## Getting Started

### 1. Fork the Repository

```bash
# Fork the repository on GitLab
# Then clone your fork
git clone https://gitlab.aws.dev/your-username/genaiic-idp-accelerator-terraform.git
cd genaiic-idp-accelerator-terraform
```

### 2. Set Up Development Environment

```bash
# Install dependencies
terraform --version  # Ensure 1.5.0+
aws --version        # Ensure AWS CLI v2

# Set up pre-commit hooks (optional but recommended)
pip install pre-commit
pre-commit install
```

### 3. Create a Branch

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Or a bug fix branch
git checkout -b fix/issue-description
```

### 4. Make Changes

Follow our development guidelines:

- [Development Guide](development.md)
- [Testing Guide](testing.md)
- [Documentation Guide](documentation.md)

### 5. Test Your Changes

```bash
# Run terraform validation
terraform init
terraform validate

# Run tests (if available)
./scripts/test.sh

# Test examples
cd examples/bedrock-llm-processor
terraform init
terraform plan
```

### 6. Submit a Merge Request

1. Push your changes to your fork
2. Create a merge request on GitLab
3. Fill out the merge request template
4. Wait for review and address feedback

## Development Guidelines

### Code Standards

#### Terraform Code Style

```hcl
# Use consistent formatting
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bucket"
  })
}

# Use descriptive variable names
variable "document_processing_timeout" {
  description = "Timeout in seconds for document processing Lambda function"
  type        = number
  default     = 300
  
  validation {
    condition     = var.document_processing_timeout >= 30 && var.document_processing_timeout <= 900
    error_message = "Timeout must be between 30 and 900 seconds."
  }
}
```

#### File Organization

```
modules/
├── module-name/
│   ├── main.tf           # Main resources
│   ├── variables.tf      # Input variables
│   ├── outputs.tf        # Output values
│   ├── versions.tf       # Provider requirements
│   ├── README.md         # Module documentation
│   └── examples/         # Usage examples
```

### Documentation Standards

#### Module Documentation

Each module must include:

- Clear description and purpose
- Usage examples
- Variable documentation
- Output documentation
- Requirements and dependencies

#### Code Comments

```hcl
# Create S3 bucket for document storage with encryption enabled
# This bucket will store incoming documents and trigger processing
resource "aws_s3_bucket" "documents" {
  bucket = local.bucket_name
  
  # Prevent accidental deletion in staging
  lifecycle {
    prevent_destroy = var.environment == "staging"
  }
}
```

### Testing Requirements

#### Module Testing

- All modules must have basic validation tests
- Examples must be tested and working
- Integration tests for complex workflows

#### Example Testing

```bash
# Each example should include a test script
#!/bin/bash
set -e

echo "Testing bedrock-llm-processor example..."

# Initialize and validate
terraform init
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Optional: Apply and test (for CI/CD)
if [ "$RUN_APPLY_TESTS" = "true" ]; then
  terraform apply tfplan
  # Run functional tests
  ./test-functionality.sh
  # Clean up
  terraform destroy -auto-approve
fi

echo "Test completed successfully!"
```

## Contribution Process

### Issue Workflow

1. **Issue Creation**
   - Use appropriate issue templates
   - Provide detailed information
   - Add relevant labels

2. **Issue Triage**
   - Maintainers review and label issues
   - Priority and complexity assessment
   - Assignment to contributors

3. **Development**
   - Create branch from main
   - Implement changes
   - Test thoroughly

4. **Review Process**
   - Submit merge request
   - Code review by maintainers
   - Address feedback
   - Final approval and merge

### Merge Request Guidelines

#### Title Format

```
type(scope): brief description

Examples:
feat(modules): add new processing-environment module
fix(examples): correct variable reference in bedrock-llm-processor
docs(guides): update deployment guide for security
```

#### Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Other (please describe)

## Testing
- [ ] Terraform validate passes
- [ ] Examples tested
- [ ] Integration tests pass
- [ ] Documentation updated

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

## Community Guidelines

### Code of Conduct

We follow the [AWS Open Source Code of Conduct](https://aws.github.io/code-of-conduct). Please:

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professional communication

### Communication Channels

- **Issues**: Bug reports and feature requests
- **Merge Requests**: Code discussions and reviews
- **Discussions**: General questions and ideas

## Recognition

Contributors are recognized through:

- Contributor list in README
- Release notes acknowledgments
- Community highlights

## Getting Help

### For Contributors

- Review existing issues and merge requests
- Ask questions in issue comments
- Reach out to maintainers for guidance

### For Maintainers

- Provide timely feedback on contributions
- Help new contributors get started
- Maintain project quality and standards

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] Version bumped
- [ ] Release notes prepared
- [ ] Examples tested

## Next Steps

Ready to contribute? Here's how to get started:

1. **Browse Issues**: Look for issues labeled `good first issue` or `help wanted`
2. **Read Guidelines**: Review the [development guide](development.md)
3. **Start Small**: Begin with documentation or small bug fixes
4. **Ask Questions**: Don't hesitate to ask for help or clarification

Thank you for contributing to the GenAI IDP Accelerator!
