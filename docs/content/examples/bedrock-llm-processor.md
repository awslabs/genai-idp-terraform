# Bedrock LLM Processor Example

This example demonstrates how to use the Bedrock LLM processor to create a flexible document processing pipeline using Amazon Bedrock foundation models. It's perfect for custom document processing with advanced AI capabilities and comprehensive analytics.

## Overview

The Bedrock LLM Processor example provides:

1. **Document Upload** → S3 bucket triggers processing
2. **Multi-stage AI Pipeline** → Classification, extraction, summarization
3. **Assessment Functions** → Real-time quality measurement
4. **Evaluation System** → Baseline comparison for accuracy tracking
5. **Web UI** → CloudFront-distributed interface for document management
6. **Analytics Environment** → Comprehensive reporting with Athena integration

## Key Features

✅ **Multi-Model Support**: Nova Pro, Claude 3.5 Sonnet, Claude 3 Haiku  
✅ **Assessment Functions**: Document quality scoring  
✅ **Evaluation System**: Baseline comparison and accuracy measurement  
✅ **Reporting Environment**: Parquet-based analytics with Glue tables  
✅ **Web UI**: CloudFront distribution with Cognito authentication  
✅ **Configurable Concurrency**: Scalable processing with worker pools  
✅ **Comprehensive Monitoring**: CloudWatch dashboards and detailed logging  

## Quick Start

### 1. Navigate to the Example

```bash
cd examples/bedrock-llm-processor
```

### 2. Configure Your Deployment

Copy and customize the configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

```hcl
# Basic Configuration
region = "us-east-1"
prefix = "genai-idp"

# Administrator Configuration
admin_email = "admin@example.com"

# Logging Configuration
log_level          = "INFO"
log_retention_days = 7

# Data Retention
data_tracking_retention_days = 365

# Core Processing Models
classification_model_id = "us.amazon.nova-pro-v1:0"
extraction_model_id     = "us.amazon.nova-pro-v1:0"

# Summarization Feature
summarization_enabled  = true
summarization_model_id = "us.anthropic.claude-3-7-sonnet-20250219-v1:0"

# Evaluation Feature
enable_evaluation   = false
evaluation_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"

# Assessment Feature
enable_assessment = false

# Reporting Feature
enable_reporting = false

# API Configuration
enable_api = true

# Web UI Configuration
web_ui = {
  enabled = true
}

# Tags
tags = {
  Environment = "dev"
  Project     = "genai-idp-accelerator"
}
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Test the Pipeline

Access your deployment:

```bash
# Get the Web UI URL
echo "Web UI: $(terraform output -raw web_ui_url)"

# Or upload via CLI
INPUT_BUCKET=$(terraform output -raw input_bucket_name)
echo "Upload documents to: s3://$INPUT_BUCKET"
```

## Advanced Configuration

### Custom Configuration Files

Configure custom document processing by specifying your own configuration file:

```hcl
# In terraform.tfvars
config_file_path = "path/to/your/custom/config.yaml"
```

The configuration file defines document classes, extraction prompts, and processing parameters. Examples are available in the `sources/config_library/` directory:

- **Pattern 1** (BDA): `sources/config_library/pattern-1/lending-package-sample/config.yaml`
- **Pattern 2** (Bedrock LLM): `sources/config_library/pattern-2/lending-package-sample/config.yaml`  
- **Pattern 3** (SageMaker UDOP): `sources/config_library/pattern-3/rvl-cdip-package-sample/config.yaml`

### Example Custom Configuration

```yaml
# custom-config.yaml
document_classes:
  - name: "invoice"
    description: "Business invoices and billing documents"
    extraction_fields:
      - invoice_number
      - date
      - amount
      - vendor
  - name: "contract"
    description: "Legal contracts and agreements"
    extraction_fields:
      - parties
      - effective_date
      - termination_date
      - key_terms

processing_settings:
  classification_confidence_threshold: 0.8
  extraction_max_retries: 3
  enable_summarization: true
```

Then reference it in your terraform.tfvars:

```hcl
config_file_path = "./custom-config.yaml"
```

### Performance Tuning

Optimize for your workload:

```hcl
# High-volume processing configuration
# Note: Performance tuning is handled at the module level

# Memory optimization for large documents
lambda_memory_size = 3008
lambda_timeout     = 900
```

### Security Configuration

Enable additional security features:

```hcl
# KMS encryption
enable_kms_encryption = true

# VPC deployment
vpc_deployment = true
vpc_subnet_ids = ["subnet-12345", "subnet-67890"]
vpc_security_group_ids = ["sg-abcdef"]
```

## Understanding the Processing Pipeline

### 1. Document Classification

- **Model**: Nova Pro (configurable)
- **Purpose**: Identify document type and structure
- **Output**: Document class and confidence score

### 2. Text Extraction

- **Model**: Nova Pro (configurable)
- **Purpose**: Extract structured data based on document class
- **Output**: JSON with extracted fields

### 3. Summarization (Optional)

- **Model**: Claude 3.7 Sonnet (configurable)
- **Purpose**: Generate document summary
- **Output**: Concise summary text

### 4. Assessment (Optional)

- **Model**: Claude 3 Haiku (configurable)
- **Purpose**: Quality measurement and validation
- **Output**: Quality scores and feedback

### 5. Evaluation (Optional)

- **Model**: Claude 3.5 Sonnet (configurable)
- **Purpose**: Compare against baseline documents
- **Output**: Accuracy metrics and comparison results

## Analytics and Reporting

When `enable_reporting = true`, you get comprehensive analytics:

### Glue Tables Created

- `document_processing_metrics`: Processing performance data
- `document_evaluations`: Accuracy and quality metrics
- `metering`: Cost and usage tracking
- `document_assessments`: Quality assessment results

### Example Athena Queries

**Processing Performance**:

```sql
SELECT 
    document_class,
    AVG(processing_time_ms) as avg_processing_time,
    COUNT(*) as document_count
FROM document_processing_metrics 
WHERE year = 2024 AND month = 1
GROUP BY document_class;
```

**Quality Analysis**:

```sql
SELECT 
    document_class,
    AVG(quality_score) as avg_quality,
    AVG(accuracy) as avg_accuracy
FROM document_evaluations 
WHERE year = 2024 AND month = 1
GROUP BY document_class;
```

**Cost Analysis**:

```sql
SELECT 
    model_id,
    SUM(cost_usd) as total_cost,
    COUNT(*) as invocations
FROM metering 
WHERE year = 2024 AND month = 1
GROUP BY model_id;
```

## Monitoring and Troubleshooting

### CloudWatch Dashboards

The deployment creates comprehensive dashboards for:

- Processing throughput and latency
- Error rates and success metrics
- Cost tracking per model
- Quality and accuracy trends

### Log Groups

Monitor processing with structured logs:

```bash
# Stream processing logs
aws logs tail /aws/lambda/$(terraform output -raw prefix)-classification --follow

# View assessment results
aws logs tail /aws/lambda/$(terraform output -raw prefix)-assessment --follow
```

### Common Issues

#### Model Access Denied

```
Error: AccessDeniedException: You don't have access to the model
```

**Solution**: Enable model access in Bedrock console

#### High Processing Latency

**Symptoms**: Slow document processing
**Solutions**:

- Configure appropriate Lambda memory and timeout settings
- Enable evaluation and reporting for monitoring
- Use appropriate model selection for your use case
- Consider using faster models for classification

#### Quality Score Issues

**Symptoms**: Low assessment scores
**Solutions**:

- Review and customize assessment prompts
- Ensure document quality is sufficient
- Consider using different assessment models

## Outputs

The deployment provides these key outputs:

```bash
terraform output
```

- `web_ui_url`: CloudFront distribution URL for the web interface
- `input_bucket_name`: S3 bucket for document uploads
- `output_bucket_name`: S3 bucket for processed results
- `api_endpoint`: AppSync GraphQL API endpoint
- `cognito_user_pool_id`: User pool for authentication
- `glue_database_name`: Analytics database name (if reporting enabled)

## Cleanup

To remove all resources:

```bash
# Empty S3 buckets first
aws s3 rm s3://$(terraform output -raw input_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw output_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw working_bucket_name) --recursive

# Destroy infrastructure
terraform destroy
```

## Next Steps

- **Customize Processing**: Modify prompts and document classes for your use case
- **Scale Performance**: Adjust concurrency settings for your workload
- **Integrate APIs**: Use the GraphQL API for custom applications
- **Advanced Analytics**: Build custom dashboards with the reporting data
- **Production Deployment**: Review security and compliance requirements

This example provides a complete, production-ready document processing solution with advanced AI capabilities and comprehensive monitoring.
aws s3 ls s3://$(terraform output -raw buckets | jq -r '.output_bucket.bucket_name')/ --recursive

```

## Configuration Options

The Bedrock LLM Processor example provides three configuration levels:

### Minimal (Default)
- Uses `terraform.tfvars` as-is
- Basic functionality enabled
- Suitable for testing and learning

### Comprehensive
- Copy `terraform.tfvars.example` to `terraform.tfvars`
- All features enabled
- Production-ready configuration

### Custom
- Start with `terraform.tfvars.example`
- Customize for your specific needs
- Full control over all settings

## Features Available

- Document processing pipeline
- Web UI for document management
- GraphQL API for status tracking
- Multiple Bedrock models support
- Custom document classes
- Evaluation framework (optional)
- Document summarization (optional)
- Custom prompt engineering
- Flexible AI model selection

## Advanced Configuration

### Custom Prompts
Modify the processor configuration to use custom prompts for specific document types:

```hcl
# In terraform.tfvars
custom_prompts = {
  invoice = "Extract invoice details including vendor, amount, and date..."
  contract = "Identify key contract terms, parties, and obligations..."
}
```

### Model Selection

Choose different Bedrock models for different processing tasks:

```hcl
# In terraform.tfvars
bedrock_models = {
  classification = "anthropic.claude-3-haiku-20240307-v1:0"
  extraction = "anthropic.claude-3-sonnet-20240229-v1:0"
  summarization = "anthropic.claude-3-opus-20240229-v1:0"
}
```

## Next Steps

1. **Explore the Example**: Review the [Bedrock LLM Processor](../../../examples/bedrock-llm-processor/README.md) documentation
2. **Customize**: Modify the configuration for your use case
3. **Scale Up**: Move to more advanced examples when ready

## Related Examples

- [BDA Processor](../../../examples/bda-processor/) - Alternative using Bedrock Data Automation
- [SageMaker UDOP Processor](../../../examples/sagemaker-udop-processor/) - Custom model approach
- [Processing Environment](../../../examples/processing-environment/) - Core infrastructure only
