# GenAI IDP Accelerator for Terraform

A modular Terraform implementation of the GenAI **Intelligent Document Processing** (IDP) Accelerator, designed to transform unstructured documents into structured data at scale using AWS's latest AI/ML services.

## Overview

This project provides a Terraform-based implementation of the [GenAI **Intelligent Document Processing** Accelerator](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws), offering flexible deployment options and infrastructure-as-code management for **Intelligent Document Processing** workflows.

## Experimental Status

This solution is in experimental stage. While it implements security best practices, conduct thorough testing and security review before production use.

## Versioning

This repository uses a dual-version scheme to track both the upstream IDP solution and the Terraform implementation:

- **`IDP_VERSION`**: Tracks the upstream [GenAI IDP Accelerator](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws) version
- **`VERSION`**: Tracks this Terraform implementation using the format `{IDP_VERSION}-tf.{TERRAFORM_VERSION}`

### Version Format Examples

| VERSION | Meaning |
|---------|---------|
| `0.3.18-tf.0` | IDP v0.3.18, initial Terraform implementation |
| `0.3.18-tf.1` | IDP v0.3.18, first Terraform patch |
| `0.3.18-tf.2` | IDP v0.3.18, second Terraform patch |
| `0.4.9-tf.0` | IDP v0.4.9, initial Terraform implementation |

The Terraform version (`tf.X`) resets to `0` when the upstream IDP version changes.

### Key Features

- **Modular Architecture**: Reusable Terraform modules for flexible composition
- **Multiple AI Processing Patterns**: Three distinct approaches for different use cases
- **Serverless Design**: Built on AWS Lambda, Step Functions, and other serverless technologies
- **Security First**: KMS encryption, IAM least privilege, and VPC support with comprehensive security fixes
- **Comprehensive Monitoring**: Built-in CloudWatch dashboards and alerting
- **Web Interface**: Optional React-based UI for document management
- **Knowledge Base**: Query processed documents using natural language
- **Document Discovery**: Upload and analyze documents for pattern discovery
- **Chat with Documents**: Interactive Q&A with processed documents using foundation models
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

# Discovery Configuration (optional)
discovery = {
  enabled = true
}

# Chat with Document Configuration (optional)
chat_with_document = {
  enabled = true
  # Optional: Add Bedrock Guardrail for content filtering
  guardrail_id_and_version = "your-guardrail-id:1"
}

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
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.70.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.26.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_assets_bucket"></a> [assets\_bucket](#module\_assets\_bucket) | ./modules/assets-bucket | n/a |
| <a name="module_bda_processor"></a> [bda\_processor](#module\_bda\_processor) | ./modules/processors/bda-processor | n/a |
| <a name="module_bedrock_llm_processor"></a> [bedrock\_llm\_processor](#module\_bedrock\_llm\_processor) | ./modules/processors/bedrock-llm-processor | n/a |
| <a name="module_human_review"></a> [human\_review](#module\_human\_review) | ./modules/human-review | n/a |
| <a name="module_idp_common_layer"></a> [idp\_common\_layer](#module\_idp\_common\_layer) | ./modules/idp-common-layer | n/a |
| <a name="module_processing_environment"></a> [processing\_environment](#module\_processing\_environment) | ./modules/processing-environment | n/a |
| <a name="module_processing_environment_api"></a> [processing\_environment\_api](#module\_processing\_environment\_api) | ./modules/processing-environment-api | n/a |
| <a name="module_processor_attachment"></a> [processor\_attachment](#module\_processor\_attachment) | ./modules/processor-attachment | n/a |
| <a name="module_reporting"></a> [reporting](#module\_reporting) | ./modules/reporting | n/a |
| <a name="module_sagemaker_udop_processor"></a> [sagemaker\_udop\_processor](#module\_sagemaker\_udop\_processor) | ./modules/processors/sagemaker-udop-processor | n/a |
| <a name="module_user_identity"></a> [user\_identity](#module\_user\_identity) | ./modules/user-identity | n/a |
| <a name="module_web_ui"></a> [web\_ui](#module\_web\_ui) | ./modules/web-ui | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role_policy.authenticated_user_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bda_processor"></a> [bda\_processor](#input\_bda\_processor) | Configuration for BDA processor | <pre>object({<br/>    project_arn = string<br/>    summarization = optional(object({<br/>      enabled  = optional(bool, true)<br/>      model_id = optional(string, null)<br/>    }), { enabled = true, model_id = null })<br/>    config = any<br/>  })</pre> | `null` | no |
| <a name="input_bedrock_llm_processor"></a> [bedrock\_llm\_processor](#input\_bedrock\_llm\_processor) | Configuration for Bedrock LLM processor | <pre>object({<br/>    classification_model_id      = optional(string, null)<br/>    extraction_model_id          = optional(string, null)<br/>    max_pages_for_classification = optional(string, "ALL")<br/>    summarization = optional(object({<br/>      enabled  = optional(bool, true)<br/>      model_id = optional(string, null)<br/>    }), { enabled = true, model_id = null })<br/>    enable_assessment = optional(bool, false)<br/>    config            = any<br/>  })</pre> | `null` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | Document tracking data retention period in days | `number` | `365` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection for Cognito resources | `bool` | `true` | no |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Enable GraphQL API for programmatic access and notifications | `bool` | `true` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Set to true when providing encryption\_key\_arn. This is needed to avoid Terraform plan-time unknown value issues. | `bool` | `true` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources in the document processing workflow | `string` | n/a | yes |
| <a name="input_evaluation"></a> [evaluation](#input\_evaluation) | Configuration for document processing evaluation against baseline | <pre>object({<br/>    enabled             = optional(bool, false)<br/>    model_id            = optional(string, null)<br/>    baseline_bucket_arn = optional(string)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_force_rebuild_layers"></a> [force\_rebuild\_layers](#input\_force\_rebuild\_layers) | Force rebuild of Lambda layers regardless of requirements changes | `bool` | `false` | no |
| <a name="input_human_review"></a> [human\_review](#input\_human\_review) | Configuration for human review functionality in document processing | <pre>object({<br/>    enabled                   = optional(bool, false)<br/>    user_group_name           = optional(string)<br/>    user_pool_id              = optional(string)<br/>    private_workforce_arn     = optional(string)<br/>    workteam_name             = optional(string)<br/>    enable_pattern2_hitl      = optional(bool, false)<br/>    hitl_confidence_threshold = optional(number, 80)<br/>  })</pre> | <pre>{<br/>  "enable_pattern2_hitl": false,<br/>  "enabled": false,<br/>  "hitl_confidence_threshold": 80<br/>}</pre> | no |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_knowledge_base"></a> [knowledge\_base](#input\_knowledge\_base) | Configuration for AWS Bedrock Knowledge Base functionality | <pre>object({<br/>    enabled            = optional(bool, false)<br/>    knowledge_base_arn = optional(string)<br/>    model_id           = optional(string, "us.amazon.nova-pro-v1:0")<br/>    embedding_model_id = optional(string, "amazon.titan-embed-text-v1")<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results will be stored | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for resource names | `string` | `"genai-idp"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_reporting"></a> [reporting](#input\_reporting) | Configuration for reporting and analytics functionality | <pre>object({<br/>    enabled                     = optional(bool, false)<br/>    bucket_arn                  = optional(string)<br/>    database_name               = optional(string)<br/>    crawler_schedule            = optional(string, "daily")<br/>    enable_partition_projection = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "crawler_schedule": "daily",<br/>  "enable_partition_projection": true,<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_sagemaker_udop_processor"></a> [sagemaker\_udop\_processor](#input\_sagemaker\_udop\_processor) | Configuration for SageMaker UDOP processor | <pre>object({<br/>    classification_endpoint_arn = string<br/>    summarization = optional(object({<br/>      enabled  = optional(bool, true)<br/>      model_id = optional(string, null)<br/>    }), { enabled = true, model_id = null })<br/>    enable_assessment          = optional(bool, false)<br/>    ocr_max_workers            = optional(number, 20)<br/>    classification_max_workers = optional(number, 20)<br/>    config                     = any<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_user_identity"></a> [user\_identity](#input\_user\_identity) | Configuration for external Cognito User Identity resources. If provided, the module will use this instead of creating its own user identity resources. | <pre>object({<br/>    user_pool_arn          = string<br/>    user_pool_client_id    = optional(string)<br/>    identity_pool_id       = optional(string)<br/>    authenticated_role_arn = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions (optional) | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions to run in (optional) | `list(string)` | `[]` | no |
| <a name="input_web_ui"></a> [web\_ui](#input\_web\_ui) | Web UI configuration object | <pre>object({<br/>    enabled                    = optional(bool, true)<br/>    create_infrastructure      = optional(bool, true)<br/>    bucket_name                = optional(string, null)<br/>    cloudfront_distribution_id = optional(string, null)<br/>    logging_enabled            = optional(bool, false)<br/>    logging_bucket_arn         = optional(string, null)<br/>    enable_signup              = optional(string, "")<br/>    display_name               = optional(string, null)<br/>  })</pre> | <pre>{<br/>  "bucket_name": null,<br/>  "cloudfront_distribution_id": null,<br/>  "create_infrastructure": true,<br/>  "display_name": null,<br/>  "enable_signup": "",<br/>  "enabled": true,<br/>  "logging_bucket_arn": null,<br/>  "logging_enabled": false<br/>}</pre> | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket for temporary working files during document processing | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api"></a> [api](#output\_api) | API resources (if enabled) |
| <a name="output_assets_bucket"></a> [assets\_bucket](#output\_assets\_bucket) | Shared assets bucket information |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix used for all resources |
| <a name="output_processing_environment"></a> [processing\_environment](#output\_processing\_environment) | Processing environment resources |
| <a name="output_processor"></a> [processor](#output\_processor) | Document processor details |
| <a name="output_processor_type"></a> [processor\_type](#output\_processor\_type) | Type of document processor used |
| <a name="output_user_identity"></a> [user\_identity](#output\_user\_identity) | User identity resources |
| <a name="output_web_ui"></a> [web\_ui](#output\_web\_ui) | Web UI resources (if enabled) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
