# Examples

This section provides practical examples of how to use the GenAI IDP Accelerator modules to build different types of document processing solutions. Each example references the real, working examples available in the repository.

## End-to-End Delivery Patterns

These are complete document processing solutions that demonstrate different approaches to **Intelligent Document Processing**. Each pattern provides a full end-to-end implementation with all necessary components.

### [Bedrock LLM Processor](bedrock-llm-processor.md)
**Complete E2E Solution**  
**Deployment Time**: 15-20 minutes  
**Based on**: [examples/bedrock-llm-processor/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/bedrock-llm-processor?ref_type=heads)

**The flexible AI-powered document processing pattern** - Perfect for organizations needing custom document analysis with advanced AI capabilities and comprehensive analytics.

**Complete solution includes**:
- Multi-stage AI processing pipeline (classification, extraction, summarization)
- Amazon Bedrock integration with Nova Pro and Claude models
- Assessment functions for real-time quality measurement
- Evaluation system for baseline comparison and accuracy tracking
- Reporting environment with Parquet-based analytics and Athena integration
- CloudFront-distributed web UI with Cognito authentication
- Configurable concurrency and performance optimization
- Comprehensive CloudWatch monitoring and dashboards

**Key Features**:
✅ **Multi-Model Support**: Nova Pro, Claude 3.5 Sonnet, Claude 3 Haiku  
✅ **Assessment Functions**: Document quality scoring  
✅ **Evaluation System**: Baseline comparison for accuracy measurement  
✅ **Analytics Environment**: Comprehensive reporting with Glue tables  
✅ **Scalable Architecture**: Configurable worker pools and concurrency  
✅ **Flexible Configuration**: Customizable config files with sensible defaults  

**Configuration Options**:
- **Default Configuration**: Uses pre-built lending package configuration
- **Custom Configuration**: Specify your own config file with `config_file_path` variable
- **Multiple Patterns**: Choose from lending, RVL-CDIP, or custom document patterns

**Ideal for**:
- Custom document processing workflows requiring flexibility
- Organizations needing comprehensive quality measurement and analytics
- Advanced prompt engineering and model customization
- Production deployments with monitoring and cost tracking

---

### [BDA Processor](bda-processor.md)
**Complete E2E Solution**  
**Deployment Time**: 15-20 minutes  
**Based on**: [examples/bda-processor/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/bda-processor?ref_type=heads)

**The managed document processing pattern** - Perfect for organizations processing standard document types with minimal configuration.

**Complete solution includes**:
- Amazon Bedrock Data Automation integration
- Pre-built document schemas and templates
- Managed processing pipeline with automatic scaling
- Web UI for document management and monitoring
- Built-in quality assurance and validation
- Security best practices implementation

**Ideal for**:
- Standard document types (invoices, forms, contracts)
- Organizations wanting managed solutions
- Rapid deployment with minimal customization
- Consistent document processing workflows

---

### [SageMaker UDOP Processor](sagemaker-udop.md)
**Complete E2E Solution**  
**Deployment Time**: 25-35 minutes  
**Based on**: [examples/sagemaker-udop-processor/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/sagemaker-udop-processor?ref_type=heads)

**The specialized AI model pattern** - Perfect for organizations requiring highly accurate, custom-trained models for specific document types.

**Complete solution includes**:
- Amazon SageMaker endpoint deployment
- Fine-tuned UDOP (Unified Document Understanding) model
- Custom document classification and extraction
- Advanced processing pipeline with model optimization
- High-accuracy document analysis capabilities
- Specialized training and inference infrastructure

**Ideal for**:
- Specialized or complex document types
- Organizations requiring custom model training
- High-accuracy classification and extraction needs
- Industry-specific document processing requirements

## Supporting Infrastructure Components

These examples provide individual components that can be combined to build custom solutions or extend the end-to-end patterns above.

### [Processing Environment](processing-environment.md)
**Deployment Time**: 15-20 minutes  
**Based on**: [examples/processing-environment/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/processing-environment?ref_type=heads)

Core infrastructure setup without specific processors - perfect for building custom solutions.

**What it includes**:
- Core processing infrastructure
- DynamoDB tables for tracking
- GraphQL API for management
- Foundation for custom processors

**Use cases**:
- Custom processor development
- Infrastructure foundation
- Modular deployments

### [Processing Environment API](processing-environment-api.md)
**Deployment Time**: 10-15 minutes  
**Based on**: [examples/processing-environment-api/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/processing-environment-api?ref_type=heads)

Standalone API deployment for document processing management and monitoring.

**What it includes**:
- GraphQL API endpoints
- Document status tracking
- User authentication integration
- API documentation

**Use cases**:
- API-first deployments
- Integration with existing systems
- Microservices architecture

### [User Identity Standalone](user-identity.md)
**Deployment Time**: 5-10 minutes  
**Based on**: [examples/user-identity-standalone/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/user-identity-standalone?ref_type=heads)

Standalone user authentication and authorization setup using Amazon Cognito.

**What it includes**:
- Cognito User Pool
- User Pool Client
- Admin user setup
- Domain configuration

**Use cases**:
- Authentication foundation
- User management setup
- Security infrastructure

### [Core Tables](core-tables.md)
**Deployment Time**: 5-10 minutes  
**Based on**: [examples/core-tables/](https://github.com/awslabs/genai-idp-terraform/tree/main/examples/core-tables?ref_type=heads)

Essential DynamoDB tables for document tracking and configuration management.

**What it includes**:
- Document tracking table
- Configuration table
- Concurrency management table
- Basic monitoring setup

**Use cases**:
- Infrastructure foundation
- Custom implementations
- Modular deployments

## Repository Examples

All examples are available in the repository at:
```
genaiic-idp-accelerator-terraform/examples/
```

Each example includes:
- Complete Terraform configurations
- Multiple configuration options (minimal, comprehensive, template)
- Comprehensive README documentation
- Testing and validation instructions

## Quick Start Guide

### 1. Choose Your Pattern

**For Complete Solutions**: Start with one of the **End-to-End Delivery Patterns** above
- **Bedrock LLM Processor** - Most flexible, custom AI processing
- **BDA Processor** - Fastest deployment, managed processing
- **SageMaker UDOP** - Highest accuracy, specialized models

**For Custom Solutions**: Combine **Supporting Infrastructure Components** as needed

### 2. Navigate to Example Directory

```bash
cd examples/[example-name]
```

### 3. Configure Variables

Most examples provide configuration options:

```bash
# Use ready-to-deploy configuration
# terraform.tfvars.example is provided

# Copy and customize for your needs
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

### 4. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 5. Test

Each example includes specific testing instructions in its README file.

## Pattern Comparison

### End-to-End Delivery Patterns

| Pattern | Best For | Key Advantage |
|---------|----------|---------------|
| **Bedrock LLM Processor** | Custom document processing | Maximum flexibility and AI model choice |
| **BDA Processor** | Standard document types | Fastest time-to-deployment with managed schemas |
| **SageMaker UDOP** | Specialized classification | Highest accuracy with custom-trained models |

### Supporting Components

| Component | Purpose | Integration |
|-----------|---------|-------------|
| **Processing Environment** | Infrastructure foundation | Base for custom processors |
| **Processing Environment API** | API-first approach | Microservices and integrations |
| **User Identity** | Authentication setup | Security foundation |
| **Core Tables** | Data foundation | Tracking and configuration |

## Prerequisites

Before running any example, ensure you have:

- [Prerequisites](../getting-started/prerequisites.md) completed
- [Installation](../getting-started/installation.md) finished
- AWS credentials configured
- Terraform >= 1.5.0 installed

## Support and Troubleshooting

### Getting Help

- Check individual example README files for specific guidance
- Review [troubleshooting guide](../deployment-guides/troubleshooting.md)
- Consult [FAQs](../faqs/index.md)
- Open an issue in the repository

## Next Steps

1. **Start Simple**: Begin with the [Bedrock LLM Processor](bedrock-llm-processor.md) example
2. **Explore Repository**: Browse the actual examples in the `/examples` directory
3. **Customize**: Modify examples for your specific use cases
4. **Scale Up**: Combine multiple examples for complex solutions

Ready to get started? Choose an example and begin your GenAI IDP journey!
