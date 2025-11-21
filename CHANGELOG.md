# Changelog

All notable changes to the GenAI IDP Accelerator for Terraform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Initial Release

### Overview

The GenAI IDP Accelerator for Terraform provides functional parity with the CDK version (v0.3.8), offering a comprehensive solution for intelligent document processing using AWS services. This Terraform implementation follows infrastructure-as-code best practices while maintaining the same powerful capabilities.

### Core Features

#### Document Processing Engines

- **BDA Processor**: Amazon Bedrock Data Automation for structured document analysis
- **Bedrock LLM Processor**: Large Language Model processing using Amazon Bedrock
- **SageMaker UDOP Processor**: Unified Document Processing using Amazon SageMaker endpoints

#### Intelligent Document Analysis

- **Multi-format Support**: Process PDFs, images, and various document formats
- **Text Extraction**: Advanced OCR and text recognition capabilities
- **Structure Analysis**: Identify tables, forms, key-value pairs, and document layout
- **Content Classification**: Automatic document type detection and categorization

#### Summarization Capabilities

- **Processor-specific Configuration**: Independent summarization settings for each processing engine
- **Flexible Model Selection**: Choose different Bedrock models per processor
- **Granular Control**: Enable/disable summarization at the processor level
- **Multi-model Support**: Support for various foundation models (Claude, Titan, etc.)

#### Infrastructure Features

- **Serverless Architecture**: Event-driven processing using AWS Lambda and Step Functions
- **Scalable Storage**: Amazon S3 integration for document storage and processing
- **Monitoring & Observability**: CloudWatch integration for logging and metrics
- **Security Best Practices**: IAM roles, encryption, and secure data handling
- **Cost Optimization**: Pay-per-use model with automatic scaling

#### Platform Independence

- **Consistent Deployment**: CodeBuild integration ensures reproducible deployments
- **Multi-environment Support**: Deploy across different AWS accounts and regions
- **Flexible Configuration**: Extensive customization options for various use cases

### Usage Patterns

#### Top-level Module (Recommended)

The main module provides a simplified interface for common use cases:

- **Single processor deployment**: XOR logic ensures only one processor is active at a time
- Pre-configured processor settings with sensible defaults
- Integrated monitoring and logging
- Streamlined variable structure
- Choose from BDA, Bedrock LLM, or SageMaker UDOP processors

#### Sub-modules (Advanced Use Cases)

Individual processor modules available for complex requirements:

- `modules/bda-processor/` - Standalone BDA processing
- `modules/bedrock-llm-processor/` - Standalone LLM processing  
- `modules/sagemaker-udop-processor/` - Standalone UDOP processing
- **Multiple processor deployments**: Combine different processors in custom architectures
- Advanced networking and security customizations
- Custom processor combinations and configurations

### Configuration Examples

#### Basic Configuration

```hcl
module "genai_idp" {
  source = "./path/to/genai-idp-accelerator"
  
  # Choose ONE processor (uncomment the desired option):
  
  # Option 1: BDA Processor
  bda_processor = {
    enabled = true
    summarization = {
      enabled  = true
      model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
    }
  }
  
  # Option 2: Bedrock LLM Processor
  # bedrock_llm_processor = {
  #   enabled = true
  #   summarization = {
  #     enabled  = true
  #     model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
  #   }
  # }
  
  # Option 3: SageMaker UDOP Processor
  # sagemaker_udop_processor = {
  #   enabled = true
  #   summarization = {
  #     enabled  = true
  #     model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
  #   }
  # }
}
```

#### Advanced Sub-module Usage

```hcl
# Use individual processors for custom workflows
# Sub-modules allow multiple processors in complex architectures
module "custom_bda" {
  source = "./modules/bda-processor"
  
  # Custom BDA configuration
  # ... processor-specific settings
}

module "custom_llm" {
  source = "./modules/bedrock-llm-processor"
  
  # Custom LLM configuration
  # ... processor-specific settings
}
```

### Getting Started

1. Choose between top-level module (simple) or sub-modules (advanced)
2. Configure your desired processors and features
3. Set up summarization models as needed
4. Deploy using standard Terraform workflow (`terraform init`, `terraform plan`, `terraform apply`)

### Examples

Complete working examples available in:

- `examples/bda-processor/` - BDA processor deployment
- `examples/bedrock-llm-processor/` - Bedrock LLM deployment
- `examples/sagemaker-udop-processor/` - SageMaker UDOP deployment
