# Home

Welcome to the GenAI **Intelligent Document Processing** (IDP) Accelerator for Terraform documentation. This accelerator provides a comprehensive set of Terraform modules and configurations to deploy **Intelligent Document Processing** solutions on AWS.

[![Compatible with GenAI IDP version: 0.3.18](https://img.shields.io/badge/Compatible%20with%20GenAI%20IDP-0.3.18-brightgreen)](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/releases/tag/v0.3.18)
![Stability: Experimental](https://img.shields.io/badge/Stability-Experimental-important.svg)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

!!! warning "Experimental Status"
    This solution is in experimental stage. While it implements security best practices, conduct thorough testing and security review before production use.

## What is GenAI IDP Accelerator?

The GenAI IDP Accelerator is a collection of Terraform modules that enables you to quickly deploy and configure AWS services for **Intelligent Document Processing** using generative AI capabilities. It provides pre-built infrastructure components that can be easily customized and deployed to process various document types using AWS AI/ML services.

## Key Features

- **Quick Deployment**: Pre-configured Terraform modules for rapid deployment
- **Multiple Processors**: Choose from BDA, Bedrock LLM, or SageMaker UDOP processors
- **Multi-format Support**: Process PDFs, images, and various document formats
- **AI-Powered**: Leverage AWS AI services including Amazon Bedrock foundation models
- **Assessment & Evaluation**: Built-in quality measurement and baseline comparison
- **Analytics & Reporting**: Comprehensive metrics and analytics with Athena integration
- **Web UI**: CloudFront-distributed interface for document management
- **Security First**: Built-in security best practices and KMS encryption
- **Scalable**: Auto-scaling capabilities with configurable concurrency
- **Cost-Optimized**: Efficient resource utilization and cost tracking

## Architecture Overview

The GenAI IDP Accelerator consists of several key components:

- **Document Processing**: Three processor options (BDA, Bedrock LLM, SageMaker UDOP)
- **Document Ingestion**: S3-based document storage with event-driven processing
- **AI Processing**: Amazon Bedrock foundation models (Claude, Nova) for flexible processing
- **Assessment Functions**: Real-time document quality measurement
- **Evaluation System**: Baseline comparison for accuracy tracking
- **Reporting Environment**: Parquet-based analytics with Glue tables
- **Web Interface**: CloudFront-distributed UI with Cognito authentication
- **Monitoring**: CloudWatch dashboards and comprehensive logging

## Getting Started

Ready to get started? Check out our [Getting Started Guide](getting-started/index.md) to deploy your first GenAI IDP solution.

## Quick Links

- [Getting Started](getting-started/index.md) - Deploy your first solution
- [Terraform Modules](terraform-modules/index.md) - Explore available modules
- [Examples](examples/index.md) - See real-world implementations
- [Deployment Guides](deployment-guides/index.md) - Step-by-step deployment instructions
- [Security](security/index.md) - Security features and best practices
- [FAQs](faqs/index.md) - Common questions and answers
- [Contributing](contributing/index.md) - How to contribute to the project

## Support

If you encounter any issues or have questions, please:

1. Check our [FAQs](faqs/index.md) for common solutions
2. Review the [troubleshooting guide](deployment-guides/troubleshooting.md)
3. Open an issue in the repository

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](https://github.com/awslabs/genai-idp-terraform/blob/main/LICENSE) file for details.
