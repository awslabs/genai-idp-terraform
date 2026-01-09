# GenAI IDP Accelerator - Terraform Examples

This directory contains comprehensive examples demonstrating how to deploy the GenAI IDP Accelerator using Terraform. Each example is designed to be easily deployable with `terraform init`, `terraform plan`, and `terraform apply` after setting up the `terraform.tfvars` file.

## Quick Start

1. **Choose your processing pattern** from the examples below
2. **Navigate to the example directory**
3. **Copy the example configuration**: `cp terraform.tfvars.example terraform.tfvars`
4. **Customize the variables** in `terraform.tfvars`
5. **Deploy**: `terraform init && terraform plan && terraform apply`

## Available Examples

### 1. **Bedrock LLM Processor** (`bedrock-llm-processor/`)

**Best for**: Flexible document processing with foundation models

- **Processing**: Multi-stage pipeline with Claude/Nova models
- **Features**: Classification, extraction, summarization, assessment, evaluation
- **Setup**: Fully automated deployment
- **Customization**: Complete control over processing logic

**Key Features**:

- Web UI with CloudFront distribution
- Knowledge Base integration for RAG
- Assessment functions for quality measurement
- Evaluation against baseline documents
- Analytics and reporting environment
- Configurable model selection (Claude, Nova)

### 2. **BDA Processor** (`bda-processor/`)

**Best for**: Standard document types with well-defined schemas

- **Processing**: Managed service with built-in document understanding
- **Features**: BDA integration, summarization, evaluation, reporting
- **Setup**: Requires existing BDA project configuration
- **Customization**: Schema-based with predefined document classes

**Key Features**:

- Bedrock Data Automation integration
- Web UI for document management
- Evaluation against baseline documents
- Analytics and reporting environment
- Configurable document schemas

### 3. **SageMaker UDOP Processor** (`sagemaker-udop-processor/`)

**Best for**: Specialized document processing with custom models

- **Processing**: Fine-tuned UDOP models for classification + Bedrock for extraction
- **Features**: Custom model deployment, assessment, evaluation, reporting
- **Setup**: Requires trained UDOP model artifacts
- **Customization**: Custom model training and deployment

**Key Features**:

- SageMaker endpoint deployment with auto-scaling
- Custom UDOP model integration
- Assessment functions for quality measurement
- Evaluation against baseline documents
- Analytics and reporting environment
- GPU-optimized instance types

### 4. **Processing Environment** (`processing-environment/`)

**Best for**: Core infrastructure without processors

- **Purpose**: Demonstrates the core processing environment module
- **Features**: S3 buckets, DynamoDB tables, Lambda functions, evaluation, reporting
- **Use Case**: Building custom processors or understanding core components

### 5. **Processing Environment API** (`processing-environment-api/`)

**Best for**: Standalone API deployment

- **Purpose**: Demonstrates the decoupled API module
- **Features**: AppSync GraphQL API, Cognito authentication, real-time subscriptions
- **Use Case**: Adding API functionality to existing processing environments

### 6. **Core Tables** (`core-tables/`)

**Best for**: Shared DynamoDB tables

- **Purpose**: Demonstrates shared table deployment
- **Features**: Configuration and tracking tables with encryption
- **Use Case**: Multi-processor deployments with shared state

### 7. **User Identity Standalone** (`user-identity-standalone/`)

**Best for**: Authentication infrastructure

- **Purpose**: Demonstrates user identity management
- **Features**: Cognito User Pool, Identity Pool, admin user creation
- **Use Case**: Adding authentication to custom applications

## Configuration Guide

### **Basic Configuration**

```hcl
# terraform.tfvars
region = "us-east-1"
prefix = "my-idp"

# Enable optional features (all default to false)
enable_evaluation = true
enable_reporting  = true

# Model configuration
assessment_model_id = "anthropic.claude-3-haiku-20240307-v1:0"
evaluation_model_id = "anthropic.claude-3-haiku-20240307-v1:0"
```

### **Advanced Configuration**

```hcl
# Performance tuning
max_processing_concurrency = 100
classification_max_workers = 20
extraction_max_workers     = 20

# Security configuration
enable_kms_encryption = true
vpc_deployment       = false

# Web UI configuration
enable_web_ui           = true
cloudfront_price_class  = "PriceClass_100"
enable_geo_restriction  = false
```

## Prerequisites

### **AWS Requirements**

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Docker installed (for Lambda layer building)

### **Bedrock Model Access**

**Important**: Enable model access in AWS Console before deployment:

1. Navigate to **Amazon Bedrock** → **Model access**
2. Request access to required models:
   - **Claude 3 Sonnet**: `anthropic.claude-3-sonnet-20240229-v1:0`
   - **Claude 3 Haiku**: `anthropic.claude-3-haiku-20240307-v1:0`
   - **Nova Pro**: `us.amazon.nova-pro-v1:0`
   - **Titan Text Express**: `amazon.titan-text-express-v1`

### **Service Quotas**

Ensure adequate quotas for:

- Lambda concurrent executions (recommended: 1000+)
- Step Functions state machines (recommended: 100+)
- SageMaker endpoints (for UDOP processor)
- Bedrock model invocations

## Deployment Steps

### **1. Choose Your Example**

```bash
cd examples/bedrock-llm-processor  # or your preferred example
```

### **2. Configure Variables**

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values
```

### **3. Deploy Infrastructure**

```bash
terraform init
terraform plan
terraform apply
```

### **4. Access Your Deployment**

```bash
# View outputs
terraform output

# Example outputs:
# web_ui_url = "https://d1234567890.cloudfront.net"
# api_endpoint = "https://abcdef.appsync-api.us-east-1.amazonaws.com/graphql"
# input_bucket = "my-idp-input-documents-abc123"
```

## Analytics and Reporting

When `enable_reporting = true`, you can query analytics data using Amazon Athena:

### **Document-Level Metrics**

```sql
SELECT
    processor_type,
    AVG(accuracy) as avg_accuracy,
    AVG(f1_score) as avg_f1_score,
    COUNT(*) as document_count
FROM document_evaluations
WHERE year = 2024 AND month = 7
GROUP BY processor_type;
```

### **Cost Analysis**

```sql
SELECT
    processor_type,
    SUM(cost_usd) as total_cost,
    AVG(processing_time_ms) as avg_processing_time
FROM metering
WHERE year = 2024 AND month = 7
GROUP BY processor_type;
```

## Troubleshooting

### **Common Issues**

#### **Model Access Denied**

```
Error: AccessDeniedException: You don't have access to the model
```

**Solution**: Enable model access in Bedrock console

#### **Insufficient Permissions**

```
Error: User is not authorized to perform: bedrock:InvokeModel
```

**Solution**: Ensure AWS credentials have required permissions

#### **Resource Limits**

```
Error: LimitExceededException: Rate exceeded
```

**Solution**: Adjust `max_processing_concurrency` in configuration

### **Getting Help**

- Check CloudWatch logs for detailed error information
- Review module README files for specific guidance
- Verify all prerequisites are met
- Ensure service quotas are adequate

## What's New

### **v0.3.18 Functional Parity**

- **Assessment Functions**: Document quality measurement
- **Enhanced Evaluation**: Baseline comparison with configurable models
- **Reporting Environment**: Parquet-based analytics with Glue tables
- **Save Reporting Data**: Automated metrics collection
- **Enhanced Monitoring**: Comprehensive CloudWatch integration
- **Conditional Resources**: Optional feature deployment
- **Environment Variable Parity**: 100% CDK compatibility

### **Deployment Ready**

All examples include:

- Complete IAM permission sets
- KMS encryption support
- VPC deployment options
- Comprehensive error handling
- Dead letter queues for reliability
- Auto-scaling configurations

Each example can be deployed independently with just `terraform init && terraform apply` after configuring `terraform.tfvars`!
