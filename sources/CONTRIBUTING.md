Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Contributing to GenAI Intelligent Document Processing (GenAIIDP)

Thank you for your interest in contributing to the GenAI Intelligent Document Processing accelerator! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Development Environment Setup](#development-environment-setup)
  - [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
  - [Branching Strategy](#branching-strategy)
  - [Making Changes](#making-changes)
  - [Testing Your Changes](#testing-your-changes)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Documentation](#documentation)
- [Reporting Bugs/Feature Requests](#reporting-bugsfeature-requests)
- [AWS Specific Considerations](#aws-specific-considerations)
- [Security issue notifications](#security-issue-notifications)

## Code of Conduct

This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact
opensource-codeofconduct@amazon.com with any additional questions or comments.

## Getting Started

### Development Environment Setup

1. **Prerequisites**:
   - Bash shell (Linux, MacOS)
   - AWS CLI
   - AWS SAM CLI
   - Python 3.11 or later
   - Docker

2. **Fork and Clone the Repository**:
   ```bash
   git clone <repository-url> genaiic-idp-accelerator
   cd genaiic-idp-accelerator
   ```

3. **Install Dependencies and test local build**:

See [Build Deployment Assets from Source Code](docs/deployment.md#option-2-build-deployment-assets-from-source-code)

### Project Structure

Familiarize yourself with the project structure:

- `config_library/`: Configuration templates for different processing patterns
- `docs/`: Documentation files
- `lib/idp_common_pkg/`: Core functionality library for IDP
- `notebooks`: Notebooks demonstrating use of idp_common python package. 
- `patterns/`: Implementation of document processing patterns
- `samples/`: Sample documents for testing
- `scripts/`: Utility scripts for development, testing, and deployment
- `src/`: Source code for the application
  - `api/`: API definitions
  - `lambda/`: AWS Lambda functions
  - `ui/`: Web UI components

## Development Workflow

### Branching Strategy

1. Create a branch from `develop` for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```
   
   Use prefixes like `feature/`, `fix/`, `docs/` to indicate the type of change.

### Making Changes

1. Make your changes in the appropriate files
2. Keep changes focused on a single issue or feature
3. Write/update tests as necessary
4. Ensure code passes linting rules:
   - For Python code: `ruff` is configured for this project
   - For UI code: ESLint is configured in `src/ui/.eslintrc`

### Testing Your Changes

1. **Local Testing**:
   ```bash
   # Run Python unit tests
   pytest lib/idp_common_pkg/tests/

   # Test individual Lambda functions
   cd patterns/pattern-2/
   sam build
   sam local invoke OCRFunction -e ../../testing/OCRFunction-event.json --env-vars ../../testing/env.json
   
   # Verify UI code passes linting checks
   cd src/ui/
   npm run lint
   ```

2. **Integration Testing**:
   - Deploy your changes to a test environment
   - Test with sample documents (see `samples/` directory)
   - Verify results in output bucket and CloudWatch logs

## Pull Request Process

1. **Update Documentation**: Ensure all documentation affected by your changes is updated
2. **Run Tests**: Verify that your changes pass all tests
3. **Create a Pull Request**: Submit a PR with a clear description of:
   - What the changes do
   - Why the changes are needed
   - Any relevant context or considerations
4. **Address Review Feedback**: Be responsive to review comments and make requested changes
5. **Merge**: Once approved, your contribution will be merged

## Coding Standards

- **Python**: Follow PEP 8 style guidelines
- **JavaScript/TypeScript**: Follow the ESLint configuration in the project
- **Documentation**: Update relevant documentation for any changes to functionality
- **Commit Messages**: Write clear, descriptive commit messages
- **Versioning**: Follow semantic versioning principles

## Documentation

- Update `README.md` when adding significant features
- Add detailed documentation to `/docs` for new patterns or major features
- Include code comments for complex logic or non-obvious implementations
- Update configuration examples if you modify the configuration structure

## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features for the GenAIIDP solution.

### Distinguishing Between Solution Issues and AWS Service Issues

**Important:** This repository is specifically for issues related to the GenAIIDP accelerator solution, not the underlying AWS services it uses (such as Amazon Bedrock Data Automation (BDA), Amazon Bedrock Foundational Models, Amazon Bedrock Knowledge Bases, Amazon Textract, etc.).

- **For GenAIIDP Solution Issues:** Use this GitHub repository
  - Deployment issues with the CloudFormation templates
  - Bugs in the Step Functions workflows
  - Issues with the Web UI
  - Requests for new document processing features specific to this solution

- **For AWS Service Issues:** Contact AWS Support or relevant AWS forums
  - Performance of Amazon Bedrock models
  - Amazon Textract extraction quality
  - Service quotas or throttling issues
  - Feature requests for AWS services

We provide issue templates to make this process easier:

- [Bug Report Template](/.github/ISSUE_TEMPLATE/bug_report.md) - Use this template when reporting a bug
- [Feature Request Template](/.github/ISSUE_TEMPLATE/feature_request.md) - Use this template when suggesting new functionality

When filing an issue, please check existing open, or recently closed, issues to make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

* A reproducible test case or series of steps
* The version of our code being used
* Any modifications you've made relevant to the bug
* Anything unusual about your environment or deployment

For feature requests:

1. Clearly describe the feature and its value
2. Provide context on how it fits with the project's goals
3. Include details on potential implementation approaches if possible

## AWS Specific Considerations

- **Cost Awareness**: Consider the cost implications of your changes
- **Security**: Follow AWS security best practices
- **Region Compatibility**: Ensure changes work across supported AWS regions
- **Service Quotas**: Be aware of AWS service quotas that may affect your implementation
- **IAM Permissions**: Only request the minimum necessary permissions for new functionality

## Security issue notifications
If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.

---

Thank you for contributing to the GenAI Intelligent Document Processing accelerator!
