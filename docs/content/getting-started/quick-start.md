# Quick Start

This guide will help you deploy your first GenAI IDP solution in under 30 minutes. We'll deploy a complete document processing pipeline with web UI, assessment, and evaluation capabilities.

## What You'll Deploy

This quick start creates:

- **S3 Buckets**: For document input, output, and working storage
- **Processing Pipeline**: Step Functions workflow with Lambda functions
- **AI Processing**: Amazon Bedrock integration for document analysis
- **Web UI**: CloudFront-distributed interface with Cognito authentication
- **Assessment Functions**: Document quality measurement
- **Evaluation System**: Baseline comparison capabilities
- **Analytics**: Reporting environment with Athena integration
- **Monitoring**: CloudWatch dashboards and comprehensive logging

## Step 1: Choose Your Processor

Navigate to the Bedrock LLM processor example (recommended for beginners):

```bash
cd examples/bedrock-llm-processor
```

## Step 2: Configure Variables

Copy the example configuration and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
# terraform.tfvars
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

!!! tip "Model Access Required"
    Before deployment, ensure you have access to the required Bedrock models in the AWS Console:
    
    - Navigate to **Amazon Bedrock** → **Model access**
    - Request access to: Claude 3 Sonnet, Claude 3 Haiku, Nova Pro, and Titan Text Express

## Step 3: Deploy the Infrastructure

Initialize and deploy:

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

When prompted, type `yes` to confirm the deployment.

!!! info "Deployment Time"
    The initial deployment typically takes 10-15 minutes to complete due to Lambda layer building and CloudFront distribution setup.

## Step 4: Access Your Deployment

After deployment completes, get the important URLs:

```bash
# View all outputs
terraform output

# Get the Web UI URL
echo "Web UI: $(terraform output -raw web_ui_url)"

# Get the input bucket name
echo "Upload documents to: $(terraform output -raw input_bucket_name)"
```

## Step 5: Test the Pipeline

### Access the Web UI

1. Open the Web UI URL from the terraform output
2. Sign up with your admin email (if configured)
3. Upload a test document through the interface

### Or Upload via CLI

```bash
# Create a simple test document
echo "Invoice #12345
Date: 2024-01-15
Customer: Acme Corp
Amount: $1,250.00
Description: Professional services" > test-invoice.txt

# Upload to the input bucket
INPUT_BUCKET=$(terraform output -raw input_bucket_name)
aws s3 cp test-invoice.txt s3://$INPUT_BUCKET/
```

### Monitor Processing

Watch the processing in real-time:

```bash
# Stream processing logs
aws logs tail /aws/lambda/$(terraform output -raw prefix)-processing --follow

# Or check the Web UI for real-time status updates
```

### Check Results

After processing completes (usually 1-2 minutes):

```bash
# List processed results
OUTPUT_BUCKET=$(terraform output -raw output_bucket_name)
aws s3 ls s3://$OUTPUT_BUCKET/processed/

# Download results
aws s3 cp s3://$OUTPUT_BUCKET/processed/ ./results/ --recursive
```

## Step 6: Explore the Features

### Assessment Results
If you enabled assessment, check the quality scores:

```bash
# View assessment results
cat ./results/*/assessment.json
```

### Analytics Data
If you enabled reporting, query analytics with Athena:

```sql
-- Example query in Athena console
SELECT 
    document_id,
    processing_time_ms,
    accuracy_score,
    cost_usd
FROM document_processing_metrics 
WHERE year = 2024 AND month = 1
LIMIT 10;
```

### Web UI Features
Explore the web interface:

- Document upload and management
- Real-time processing status
- Results visualization
- Configuration management

## Understanding Your Deployment

Your deployment includes:

- **Processing Pipeline**: Step Functions workflow with Lambda functions
- **Storage**: Input, output, and working S3 buckets
- **AI Processing**: Bedrock integration with Nova Pro and Claude models
- **Web Interface**: CloudFront distribution with Cognito authentication
- **Monitoring**: CloudWatch dashboards and comprehensive logging
- **Analytics**: Glue database with Athena-ready tables (if enabled)

## Cleanup

When you're done testing, clean up the resources:

```bash
# Empty S3 buckets first (required)
aws s3 rm s3://$(terraform output -raw input_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw output_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw working_bucket_name) --recursive

# Destroy all resources
terraform destroy
```

Type `yes` when prompted to confirm the destruction.

!!! warning "Data Loss"
    This will permanently delete all resources and data. Make sure to backup any important documents or results before running destroy.

## Next Steps

Now that you have a working deployment:

1. **Explore Examples**: Try the [BDA Processor](../examples/bda-processor.md) or [SageMaker UDOP](../examples/sagemaker-udop.md)
2. **Customize Processing**: Modify prompts and models for your use case
3. **Scale Up**: Adjust concurrency and performance settings
4. **Production Setup**: Review [deployment guides](../deployment-guides/index.md) for production considerations

## Troubleshooting

### Common Issues

#### Model Access Denied
```
Error: AccessDeniedException: You don't have access to the model
```
**Solution**: Enable model access in Bedrock console before deployment

#### Bucket Name Conflicts
```
Error: BucketAlreadyExists
```
**Solution**: Change the `prefix` variable to something unique

#### Lambda Layer Build Failures
```
Error: Failed to build Lambda layer
```
**Solution**: Ensure Docker is running and try rebuilding the Lambda layers

### Getting Help

If you encounter issues:

1. Check CloudWatch logs for detailed error information
2. Review [troubleshooting guide](../deployment-guides/troubleshooting.md)
3. Consult [FAQs](../faqs/index.md)
4. Open an issue in the repository

## Summary

You've successfully deployed a complete GenAI IDP solution with:

✅ **Multi-stage AI processing** with Amazon Bedrock  
✅ **Web UI** for document management  
✅ **Assessment functions** for quality measurement  
✅ **Evaluation system** for accuracy tracking  
✅ **Analytics environment** for insights  
✅ **Scalable architecture** ready for production use  

Ready to build more complex solutions? Explore our [examples](../examples/index.md) and [advanced deployment guides](../deployment-guides/index.md)!
