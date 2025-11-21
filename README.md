# GenAI IDP Accelerator for Terraform

A modular Terraform implementation of the GenAI **Intelligent Document Processing** (IDP) Accelerator, designed to transform unstructured documents into structured data at scale using AWS's latest AI/ML services.

## Overview

This project provides a Terraform-based implementation of the [GenAI **Intelligent Document Processing** Accelerator](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws), offering flexible deployment options and infrastructure-as-code management for **Intelligent Document Processing** workflows.

## Experimental Status

This solution is in experimental stage. While it implements security best practices, conduct thorough testing and security review before production use.

### Key Features

- **Modular Architecture**: Reusable Terraform modules for flexible composition
- **Multiple AI Processing Patterns**: Three distinct approaches for different use cases
- **Serverless Design**: Built on AWS Lambda, Step Functions, and other serverless technologies
- **Security First**: KMS encryption, IAM least privilege, and VPC support with comprehensive security fixes
- **Comprehensive Monitoring**: Built-in CloudWatch dashboards and alerting
- **Web Interface**: Optional React-based UI for document management
- **Knowledge Base**: Query processed documents using natural language
- **Enhanced Permissions**: Comprehensive IAM policies aligned with AWS security best practices

## Processing Patterns

The GenAI IDP Accelerator supports three different processing patterns, each optimized for specific use cases:

### Pattern 1: BDA Processor (Bedrock Data Automation)

- **Best for**: Standard document types with well-defined schemas
- **Processing**: Managed service with built-in document understanding
- **Setup**: Requires existing BDA project configuration
- **Customization**: Schema-based with predefined document classes
- **Recent Updates**: Enhanced permissions for DynamoDB, SSM Parameter Store, and Bedrock Data Automation APIs

### Pattern 2: Bedrock LLM Processor

- **Best for**: Custom document types requiring flexible extraction
- **Processing**: Multi-stage pipeline with foundation models (Claude, Nova)
- **Setup**: Fully automated deployment
- **Customization**: Complete control over classification and extraction logic

### Pattern 3: SageMaker UDOP Processor

- **Best for**: Specialized document processing with custom models
- **Processing**: Fine-tuned UDOP models for classification + Bedrock for extraction
- **Setup**: Requires trained UDOP model artifacts
- **Customization**: Custom model training and deployment

## Repository Structure

```
genai-idp-terraform/
├── modules/                           # Reusable Terraform modules
│   ├── processors/                    # Document processing patterns
│   │   ├── bda-processor/            # Pattern 1: Bedrock Data Automation
│   │   ├── bedrock-llm-processor/    # Pattern 2: Bedrock LLM Processing
│   │   └── sagemaker-udop-processor/ # Pattern 3: SageMaker UDOP Processing
│   ├── processing-environment/        # Core processing infrastructure
│   ├── processing-environment-api/    # GraphQL API for status tracking
│   ├── web-ui/                       # React-based web interface
│   ├── knowledge-base/               # Vector database for RAG
│   └── [supporting modules]/         # Additional infrastructure components
├── examples/                         # Complete deployment examples
│   ├── bda-processor/               # BDA processor deployment
│   ├── bedrock-llm-processor/       # Bedrock LLM processor deployment
│   ├── sagemaker-udop-processor/    # SageMaker UDOP processor deployment
│   └── [other examples]/           # Additional example configurations
└── sources/                         # Original CDK implementation (reference only)
```

## Recent Security Enhancements

Based on comprehensive security analysis and AWS best practices, the solution now includes:

### Enhanced IAM Permissions

- **DynamoDB**: Full CRUD operations for tracking and configuration tables
- **SSM Parameter Store**: Secure parameter management with GetParameter, PutParameter, and GetParametersByPath
- **Bedrock Data Automation**: Complete API access including GetDataAutomationProject, ListDataAutomationProjects, GetBlueprint, and GetBlueprintRecommendation
- **S3 Enhanced Permissions**: Full CRUD operations including DeleteObject and GetBucketLocation for comprehensive bucket management

### Conditional HITL (Human-in-the-Loop) Support

- **Modular HITL Policies**: Separate conditional policies for Human-in-the-Loop functionality
- **Optional BDA Metadata Table**: Configurable access to BDAMetadataTable based on deployment requirements
- **Environment Variable Consistency**: Standardized CONFIGURATION_TABLE_NAME across all Lambda functions

### Security Architecture Improvements

- **Least Privilege Access**: IAM policies follow principle of least privilege with specific resource ARNs
- **Conditional Resource Access**: HITL functionality deployed only when required using Terraform for_each patterns
- **Resource Separation**: Clear separation between core processing permissions and optional HITL permissions

## Prerequisites

Before deploying the solution, ensure you have:

### Required Tools

- **[Terraform](https://www.terraform.io/)**: Version 1.0 or later
- **[AWS CLI](https://aws.amazon.com/cli/)**: Configured with appropriate credentials
- **[Docker](https://www.docker.com/)**: For building Lambda deployment packages (if needed)

### AWS Requirements

- **AWS Account**: With appropriate permissions for all services used
- **Bedrock Model Access**: Enable access to required models in the AWS Console
- **Service Quotas**: Ensure adequate quotas for Lambda, Step Functions, etc.

### Enable Bedrock Model Access

**Important**: Before deploying, you must enable access to Bedrock models:

1. Go to the [AWS Console](https://console.aws.amazon.com/)
2. Navigate to **Amazon Bedrock**
3. Click **"Model access"** in the left navigation
4. Request access to the models you plan to use:
   - **Claude 3 Sonnet**: `anthropic.claude-3-sonnet-20240229-v1:0`
   - **Claude 3 Haiku**: `anthropic.claude-3-haiku-20240307-v1:0`
   - **Nova Pro**: `us.amazon.nova-pro-v1:0`
   - **Titan Text Express**: `amazon.titan-text-express-v1`
5. Click the checkbox next to each model and **"Request model access"**

This is a one-time manual step that cannot be automated through Terraform.

## Quick Start

### 1. Choose Your Processing Pattern

Select the pattern that best fits your use case:

```bash
# For flexible, custom document processing (Recommended for most use cases)
cd examples/bedrock-llm-processor

# For standard documents with existing BDA project
cd examples/bda-processor

# For specialized processing with custom UDOP models
cd examples/sagemaker-udop-processor
```

### 2. Configure Your Deployment

Copy and customize the example configuration:

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your specific values
nano terraform.tfvars
```

**Minimal configuration example**:

```hcl
# terraform.tfvars
aws_region = "us-east-1"
prefix     = "my-idp"

tags = {
  Environment = "development"
  Project     = "document-processing"
}
```

### 3. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 4. Access Your Deployment

After deployment, Terraform will output important information:

```bash
# View deployment outputs
terraform output

# Example outputs:
# web_ui_url = "https://d1234567890.cloudfront.net"
# api_endpoint = "https://abcdef.appsync-api.us-east-1.amazonaws.com/graphql"
# input_bucket = "my-idp-input-documents-abc123"
```

## Usage Examples

### Upload and Process Documents

Once deployed, you can process documents in several ways:

#### 1. Web Interface (Recommended)

- Navigate to the `web_ui_url` from your Terraform outputs
- Upload documents through the drag-and-drop interface
- Monitor processing status in real-time
- View and download extraction results

#### 2. Direct S3 Upload

```bash
# Upload a document to trigger processing
aws s3 cp my-document.pdf s3://your-input-bucket/
```

#### 3. Programmatic Upload

```python
import boto3

s3 = boto3.client('s3')
s3.upload_file('local-document.pdf', 'your-input-bucket', 'documents/document.pdf')
```

### Monitor Processing

```bash
# Check Step Functions executions
aws stepfunctions list-executions --state-machine-arn <state-machine-arn>

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/your-prefix"
```

## Configuration Options

### Basic Configuration

```hcl
# terraform.tfvars
aws_region = "us-east-1"
prefix     = "my-idp"

# Optional: Custom model selection
classification_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
extraction_model_id     = "anthropic.claude-3-sonnet-20240229-v1:0"

# Optional: Performance tuning
max_processing_concurrency = 50
classification_max_workers = 20
```

### Advanced Configuration

```hcl
# Enable additional features
enable_web_ui           = true
enable_knowledge_base   = true
enable_evaluation       = true
enable_summarization    = true

# HITL (Human-in-the-Loop) Configuration
# Set to non-null value to enable HITL functionality
bda_metadata_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/my-bda-metadata-table"

# Custom configuration
custom_config = {
  classification = {
    method = "multimodalPageLevelClassification"
  }
  extraction = {
    max_tokens = 8000
  }
}
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web UI        │    │   GraphQL API    │    │  S3 Buckets     │
│  (CloudFront)   │◄──►│   (AppSync)      │◄──►│  (Input/Output) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Step Functions Workflow                      │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   OCR           │ Classification  │      Extraction             │
│ (Textract)      │ (Bedrock/UDOP) │     (Bedrock)              │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Monitoring & Logging                       │
│              (CloudWatch Dashboards & Alarms)                  │
└─────────────────────────────────────────────────────────────────┘
```

## Security Features

### IAM Security Model

- **Least Privilege**: All IAM policies follow the principle of least privilege
- **Resource-Specific ARNs**: Policies reference specific resource ARNs rather than wildcards
- **Conditional Access**: HITL functionality requires explicit configuration to enable

### Data Protection

- **KMS Encryption**: All data encrypted at rest and in transit
- **VPC Support**: Optional VPC deployment for network isolation
- **Secure Parameter Management**: SSM Parameter Store for sensitive configuration

### Compliance & Monitoring

- **CloudWatch Integration**: Comprehensive logging and monitoring
- **AWS Config**: Resource compliance monitoring
- **CloudTrail**: API call auditing and tracking

## AWS Best Practices for Production

Before deploying this solution to production, consider implementing the following AWS best practices. These recommendations help ensure security, reliability, and cost optimization.

### Compute & Performance

- **Lambda Concurrent Execution Limits**: Configure reserved concurrency for each Lambda function to prevent runaway costs and protect downstream services. This solution currently has 43 Lambda functions without configured limits.
- **Lambda Dead Letter Queue (DLQ)**: Configure DLQ for Lambda functions to capture and analyze failed asynchronous invocations. This solution currently has 37 Lambda functions without configured DLQ.
- **Lambda VPC Configuration**: Configure Lambda functions inside a VPC when accessing private resources. This solution currently has 10 Lambda functions without VPC configuration. Note: Only required for functions accessing VPC resources.
- **Lambda Environment Variable Encryption**: Configure Lambda functions to encrypt environment variables using KMS customer-managed keys. This solution currently has 39 Lambda functions without environment variable encryption.
- **Lambda Code Signing**: Configure Lambda functions to validate code signatures to ensure code integrity. This solution currently has 46 Lambda functions without code-signing validation.
- *(Additional recommendations will be added here)*

### Security & Encryption

- **CodeBuild Encryption with CMK**: Configure CodeBuild projects to use customer-managed KMS keys for encrypting build artifacts, environment variables, and logs. This solution currently has 3 CodeBuild projects without CMK encryption.
- **CloudWatch Log Group Encryption**: Configure CloudWatch Log Groups to use KMS encryption for log data at rest. This solution currently has 7 CloudWatch Log Groups without KMS encryption.
- *(Additional recommendations will be added here)*

### Monitoring & Observability

- **CloudWatch Alarms**: Set up alarms for critical metrics and error rates
- **CloudWatch Log Retention**: Configure CloudWatch Log Groups with appropriate retention periods (minimum 1 year for production). This solution currently has 37 CloudWatch Log Groups without adequate retention.
- *(Additional recommendations will be added here)*

### Cost Optimization

- **Resource Tagging**: Implement comprehensive tagging strategy for cost allocation
- *(Additional recommendations will be added here)*

### Reliability & Resilience

- **Multi-AZ Deployment**: Deploy critical components across multiple availability zones
- **CloudFront Origin Failover**: Configure CloudFront with origin groups for automatic failover to secondary origins. This solution currently has 1 CloudFront distribution without origin failover.
- **CloudFront Geo Restriction**: Configure geo restrictions based on compliance and security requirements. This solution currently has 1 CloudFront distribution without geo restriction configured.
- *(Additional recommendations will be added here)*

For detailed guidance on implementing these best practices, see the [AWS Best Practices Documentation](docs/content/security/aws-best-practices.md).

## Documentation

### Comprehensive Documentation

This project includes comprehensive documentation built with Material for MkDocs, covering everything from getting started to advanced deployment scenarios.

#### Online Documentation

- **GitHub Pages**: [https://awslabs.github.io/genai-idp-terraform/](https://awslabs.github.io/genai-idp-terraform/)
- **Auto-deployed**: Updated automatically with each commit to main branch
- **Mobile-friendly**: Responsive design for all devices

#### Local Documentation

Run the documentation locally for development:

```bash
# Quick start (automated setup)
cd docs && ./serve.sh

# Manual setup
cd docs
pip install -r requirements.txt
mkdocs serve
```

Visit [http://127.0.0.1:8000](http://127.0.0.1:8000) to view the documentation.

#### Documentation Sections

- **[Getting Started](docs/content/getting-started/)**: Prerequisites, installation, and quick start
- **[Terraform Modules](docs/content/terraform-modules/)**: Detailed module documentation
- **[Examples](docs/content/examples/)**: Real-world implementation examples
- **[Deployment Guides](docs/content/deployment-guides/)**: Deployment best practices
- **[Security Guide](docs/content/security/)**: Security best practices and compliance
- **[FAQs](docs/content/faqs/)**: Common questions and troubleshooting
- **[Contributing](docs/content/contributing/)**: How to contribute to the project

#### Documentation Features

- **Live Examples**: All examples reference real, working Terraform configurations
- **Cost Estimates**: Detailed cost breakdowns for each deployment pattern
- **Architecture Diagrams**: Visual representations of system components
- **Step-by-step Guides**: Detailed instructions for every deployment scenario
- **Troubleshooting**: Common issues and their solutions
- **Best Practices**: Recommended configurations and security guidelines

## Examples and Use Cases

### Example 1: Financial Document Processing

```bash
cd examples/bedrock-llm-processor
# Configure for financial documents (invoices, statements, forms)
# Uses Claude 3 Sonnet for high accuracy
```

### Example 2: Legal Document Analysis

```bash
cd examples/bda-processor
# Configure for standard legal documents
# Uses BDA for consistent, schema-based processing
# Enhanced with comprehensive IAM permissions and HITL support
```

### Example 3: Custom Document Classification

```bash
cd examples/sagemaker-udop-processor
# Deploy with fine-tuned UDOP model
# Ideal for specialized document types
```

## Troubleshooting

### Common Issues

#### 1. Model Access Denied

```
Error: AccessDeniedException: You don't have access to the model
```

**Solution**: Enable model access in the Bedrock console (see Prerequisites)

#### 2. Insufficient Permissions

```
Error: User is not authorized to perform: bedrock:InvokeModel
```

**Solution**: Ensure your AWS credentials have the required permissions

#### 3. Resource Limits

```
Error: LimitExceededException: Rate exceeded
```

**Solution**: Adjust `max_processing_concurrency` in your configuration

#### 4. HITL Configuration Issues

```
Error: Access denied to BDA metadata table
```

**Solution**: Ensure `bda_metadata_table_arn` is correctly configured if using HITL functionality

### Getting Help

- **Module Documentation**: Each module has detailed README with troubleshooting
- **AWS Documentation**: Refer to service-specific AWS documentation
- **CloudWatch Logs**: Check function logs for detailed error information
- **Security Documentation**: Review security guide for IAM and permission issues
- **GitHub Issues**: Report bugs and request features

## Contributing

We welcome contributions! Each module includes detailed contributor documentation:

- **[Main Contributing Guide](CONTRIBUTING.md)**: Overall repository guidelines and workflow
- **[BDA Processor](modules/processors/bda-processor/README.md)**: Pattern 1 implementation guidance
- **[Bedrock LLM Processor](modules/processors/bedrock-llm-processor/README.md)**: Pattern 2 implementation guidance  
- **[SageMaker UDOP Processor](modules/processors/sagemaker-udop-processor/README.md)**: Pattern 3 implementation guidance
- **[Processing Environment](modules/processing-environment/README.md)**: Core infrastructure guidance
- **[Web UI](modules/web-ui/README.md)**: Frontend development guidance

### Security Contributions

When contributing security-related changes:

- Follow AWS security best practices
- Use least privilege IAM policies
- Include comprehensive testing for permission changes
- Document security implications in pull requests

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Additional Resources

- **[AWS CDK Version](https://github.com/cdklabs/genai-idp)**: CDK implementation
- **[Terraform Documentation](https://www.terraform.io/docs)**: Terraform best practices
- **[AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)**: Bedrock service documentation
- **[Amazon Textract Documentation](https://docs.aws.amazon.com/textract/)**: OCR service documentation
- **[AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)**: Workflow orchestration
- **[AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)**: Security guidance and compliance
