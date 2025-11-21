# BDA Processor Example with Web UI

This example demonstrates how to deploy a complete document processing solution using the BDA (Bedrock Data Automation) processor from the GenAI IDP Accelerator with an integrated Web UI.

## Architecture Overview

The BDA processor provides a managed solution for extracting structured data from documents using Amazon Bedrock Data Automation. This example creates:

- **Processing Environment**: Core infrastructure for document processing
- **BDA Processor**: Document processing pipeline using Bedrock Data Automation
- **Web UI**: React-based web application for document upload and management
- **User Identity**: Cognito-based authentication and authorization
- **IDP Common Layer**: Shared Lambda layer with utilities
- **S3 Buckets**: Input, output, working, and evaluation baseline storage
- **KMS Encryption**: End-to-end encryption for all resources

## Features

### 🚀 **Core Capabilities**

- **Automated Document Processing**: Uses Bedrock Data Automation for extraction
- **Web User Interface**: Upload documents and view results through a web browser
- **User Authentication**: Secure access with Amazon Cognito
- **Step Functions Workflow**: Orchestrates the complete processing pipeline
- **Real-time Status Tracking**: GraphQL API for monitoring document status
- **Scalable Architecture**: Handles concurrent document processing

### 🔧 **Optional Features**

- **Document Summarization**: AI-powered document summarization
- **Evaluation Framework**: Baseline comparison for accuracy measurement
- **Custom Configuration**: Configurable document classes and attributes
- **Encryption**: KMS encryption for all data at rest and in transit
- **CloudFront Distribution**: Global content delivery for the web UI
- **Access Logging**: Optional CloudFront and S3 access logging

## Prerequisites

### 1. **AWS Account Setup**

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Access to Amazon Bedrock in your chosen region

**Note**: This example uses both the AWS and AWSCC (AWS Cloud Control) providers. The AWSCC provider is required for Bedrock Data Automation resources and will be automatically installed during `terraform init`.

### 2. **Bedrock Model Access**

Before deploying, enable access to the required Bedrock models in the AWS Console:

1. Navigate to Amazon Bedrock → Model access
2. Request access to the models you plan to use:
   - **Evaluation**: `amazon.titan-text-express-v1` (default)
   - **Summarization**: `anthropic.claude-3-sonnet-20240229-v1:0` (default)
3. Wait for approval (usually immediate for most models)

### 3. **Bedrock Data Automation Project**

The Bedrock Data Automation project and blueprint are now **automatically created by Terraform**. No manual setup required!

The example includes:

- **Custom Blueprint**: Homeowners Insurance Application form schema (defined in `bda.tf`)
- **BDA Project**: Configured with document, image, video, and audio processing (defined in `bda.tf`)
- **Standard Output**: Markdown format with configurable extraction settings

The BDA resources are organized in a separate `bda.tf` file for better code organization and maintainability.

## Quick Start

### 1. **Clone and Navigate**

```bash
git clone <repository-url>
cd genaiic-idp-accelerator-terraform/examples/bda-processor
```

### 2. **Configure Variables**

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your specific values
# Key settings to review:
# - region: Your preferred AWS region
# - prefix: Unique prefix for your resources
# - enable_evaluation: Whether to enable evaluation features
# - enable_summarization: Whether to enable summarization features
```

**Important**: The example now includes a complete Homeowners Insurance Application blueprint that matches the CDK sample. No manual BDA project creation is required!

### 3. **Deploy**

```bash
terraform init
terraform plan
terraform apply
```

### 4. **Test the Deployment**

```bash
# Upload a test document
aws s3 cp test-document.pdf s3://$(terraform output -raw buckets | jq -r '.input_bucket.bucket_name')/

# Check processing status via GraphQL API
curl -X POST $(terraform output -raw processing_environment | jq -r '.api.graphql_url') \
  -H "Content-Type: application/json" \
  -d '{"query": "query { listDocuments { id status } }"}'

# Monitor Step Functions executions
aws stepfunctions list-executions --state-machine-arn $(terraform output -raw bda_processor | jq -r '.state_machine_arn')
```

## Configuration Options

### **Basic Configuration**

```hcl
# terraform.tfvars
region = "us-east-1"
prefix = "my-idp"
log_level = "INFO"
```

### **Feature Toggles**

```hcl
# Enable/disable optional features
enable_evaluation = true
enable_summarization = true
max_processing_concurrency = 100
```

### **Model Configuration**

```hcl
# Bedrock models for different functions
evaluation_model_id = "amazon.titan-text-express-v1"
summarization_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
```

### **Custom Document Classes**

```hcl
custom_config = {
  notes = "Configuration for invoice processing"
  classes = [
    {
      name        = "Invoice"
      description = "Invoice document class"
      attributes = [
        {
          name              = "invoice_number"
          description       = "Invoice number"
          evaluation_method = "EXACT"
        },
        {
          name              = "total_amount"
          description       = "Total amount"
          evaluation_method = "NUMERIC_EXACT"
        }
      ]
    }
  ]
}
```

## Usage

### **Document Processing Workflow**

1. **Upload Documents**: Place documents in the input S3 bucket
2. **Automatic Processing**: Documents are automatically queued and processed
3. **Monitor Progress**: Use the GraphQL API to track processing status
4. **Retrieve Results**: Processed results appear in the output S3 bucket

### **API Endpoints**

#### **GraphQL API**

```bash
# Get API endpoint
GRAPHQL_URL=$(terraform output -raw processing_environment | jq -r '.api.graphql_url')

# List all documents
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{"query": "query { listDocuments { id status createdAt } }"}'

# Get specific document
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{"query": "query { getDocument(id: \"doc-123\") { id status results } }"}'
```

#### **Direct Queue Access**

```bash
# Send document directly to processing queue
QUEUE_URL=$(terraform output -raw processing_environment | jq -r '.document_queue.queue_url')
aws sqs send-message --queue-url $QUEUE_URL --message-body '{"documentId": "test-doc", "s3Key": "test-document.pdf"}'
```

### **Monitoring and Observability**

#### **CloudWatch Metrics**

- **Namespace**: `{prefix}-metrics`
- **Key Metrics**: Processing duration, success rate, error count
- **Dashboards**: Automatically created for monitoring

#### **Step Functions**

```bash
# Get state machine ARN
STATE_MACHINE_ARN=$(terraform output -raw bda_processor | jq -r '.state_machine_arn')

# List executions
aws stepfunctions list-executions --state-machine-arn $STATE_MACHINE_ARN
```

#### **Lambda Functions**

```bash
# View Lambda function logs
aws logs tail /aws/lambda/{function-name} --follow
```

## Architecture Details

### **Component Overview**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Input S3      │    │  Processing      │    │   Output S3     │
│   Bucket        │───▶│  Environment     │───▶│   Bucket        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  BDA Processor   │
                       │  ┌─────────────┐ │
                       │  │Step Functions│ │
                       │  │   Workflow  │ │
                       │  └─────────────┘ │
                       │  ┌─────────────┐ │
                       │  │   Lambda    │ │
                       │  │  Functions  │ │
                       │  └─────────────┘ │
                       └──────────────────┘
```

### **Lambda Functions**

| Function | Purpose | Dependencies |
|----------|---------|--------------|
| `invoke_bda` | Initiates BDA jobs | boto3, idp_common |
| `bda_completion` | Handles BDA events | boto3, idp_common |
| `process_results` | Processes extraction results | PyMuPDF, boto3, idp_common |
| `summarization` | Document summarization | idp_common |
| `evaluation` | Baseline comparison | idp_common |

### **Data Flow**

1. **Document Upload** → Input S3 Bucket
2. **Queue Processing** → SQS Queue → Lambda Trigger
3. **BDA Processing** → Step Functions → Bedrock Data Automation
4. **Results Processing** → Lambda Functions → Output S3 Bucket
5. **Status Updates** → GraphQL API → DynamoDB

## Customization

### **Adding New Document Types**

```hcl
custom_config = {
  classes = [
    {
      name = "Receipt"
      description = "Receipt document class"
      attributes = [
        {
          name = "merchant_name"
          description = "Name of the merchant"
          evaluation_method = "EXACT"
        }
      ]
    }
  ]
}
```

### **Custom Processing Logic**

1. Extend the Lambda functions in `assets/lambdas/`
2. Update the Step Functions workflow in `assets/sfn/workflow.asl.json`
3. Modify the configuration schema as needed

### **Integration with External Systems**

- **Webhooks**: Add webhook notifications in the completion Lambda
- **Databases**: Integrate with external databases for metadata storage
- **APIs**: Call external APIs for additional processing

## Troubleshooting

### **Common Issues**

#### **Model Access Denied**

```
Error: AccessDeniedException: You don't have access to the model
```

**Solution**: Enable model access in Bedrock console

#### **Layer Build Failures**

```
Error: Lambda layer build failed
```

**Solution**: Set `force_layer_rebuild = true` and re-apply

#### **Permission Errors**

```
Error: AccessDenied
```

**Solution**: Check IAM permissions for Bedrock, S3, and Lambda

### **Debugging Steps**

1. **Check CloudWatch Logs**

   ```bash
   aws logs tail /aws/lambda/{function-name} --follow
   ```

2. **Verify Step Functions Execution**

   ```bash
   aws stepfunctions describe-execution --execution-arn {execution-arn}
   ```

3. **Test Individual Components**

   ```bash
   aws lambda invoke --function-name {function-name} --payload '{}' response.json
   ```

## Cost Optimization

### **Resource Sizing**

- **Lambda Memory**: Adjust based on document size and processing complexity
- **Concurrency Limits**: Set appropriate limits to control costs
- **Log Retention**: Use shorter retention periods for development

### **Usage Patterns**

- **Batch Processing**: Process documents in batches during off-peak hours
- **Lifecycle Policies**: Set S3 lifecycle policies for automatic cleanup
- **Reserved Capacity**: Consider reserved capacity for predictable workloads

## Security

### **Encryption**

- **At Rest**: KMS encryption for S3, DynamoDB, and Lambda
- **In Transit**: TLS encryption for all API calls
- **Key Management**: Automatic key rotation enabled

### **Access Control**

- **IAM Roles**: Least privilege access for all components
- **VPC Integration**: Optional VPC deployment for network isolation
- **API Security**: GraphQL API with appropriate authentication

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will permanently delete all data. Ensure you have backups if needed.

## Support

For issues and questions:

- Check the [troubleshooting section](#troubleshooting)
- Review CloudWatch logs for detailed error information
- Consult the main repository documentation

## Next Steps

- **Production Deployment**: Review security and scaling considerations
- **Custom Processors**: Explore other processor types (LLM, SageMaker)
- **Integration**: Connect with your existing document management systems
- **Monitoring**: Set up comprehensive monitoring and alerting

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.70.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.4.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.49.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_genai_idp_accelerator"></a> [genai\_idp\_accelerator](#module\_genai\_idp\_accelerator) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cognito_user.admin_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user) | resource |
| [aws_cognito_user_group.admin_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_in_group.admin_user_in_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_in_group) | resource |
| [aws_glue_catalog_database.reporting_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_kms_alias.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.evaluation_baseline_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.reporting_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.working_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_notification.input_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [awscc_bedrock_blueprint.homeowners_insurance_blueprint](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/bedrock_blueprint) | resource |
| [awscc_bedrock_data_automation_project.bda_project](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/bedrock_data_automation_project) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Optional email address for the admin user. If provided, an admin user will be created in the Cognito User Pool. | `string` | `null` | no |
| <a name="input_config_file_path"></a> [config\_file\_path](#input\_config\_file\_path) | Path to the configuration YAML file for document processing | `string` | `"../../sources/config_library/pattern-1/lending-package-sample/config.yaml"` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | The retention period for document tracking data in days | `number` | `365` | no |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Enable GraphQL API for programmatic access and notifications | `bool` | `true` | no |
| <a name="input_enable_evaluation"></a> [enable\_evaluation](#input\_enable\_evaluation) | Enable evaluation functionality (simplified flag) | `bool` | `false` | no |
| <a name="input_enable_reporting"></a> [enable\_reporting](#input\_enable\_reporting) | Enable reporting functionality (simplified flag) | `bool` | `false` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | Model ID for evaluation processing | `string` | `"anthropic.claude-3-sonnet-20240229-v1:0"` | no |
| <a name="input_force_layer_rebuild"></a> [force\_layer\_rebuild](#input\_force\_layer\_rebuild) | Force rebuild of Lambda layers regardless of requirements changes | `bool` | `false` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for the document processing components | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by the document processing components in days | `number` | `7` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_summarization_enabled"></a> [summarization\_enabled](#input\_summarization\_enabled) | Enable document summarization for BDA processor | `bool` | `true` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Model ID for document summarization (BDA processor) | `string` | `"us.anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_web_ui"></a> [web\_ui](#input\_web\_ui) | Web UI configuration object | <pre>object({<br/>    enabled                    = optional(bool, true)<br/>    create_infrastructure      = optional(bool, true)<br/>    bucket_name                = optional(string, null)<br/>    cloudfront_distribution_id = optional(string, null)<br/>    logging_enabled            = optional(bool, false)<br/>    logging_bucket_arn         = optional(string, null)<br/>    enable_signup              = optional(string, "")<br/>  })</pre> | <pre>{<br/>  "bucket_name": null,<br/>  "cloudfront_distribution_id": null,<br/>  "create_infrastructure": true,<br/>  "enable_signup": "",<br/>  "enabled": true,<br/>  "logging_bucket_arn": null,<br/>  "logging_enabled": false<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api"></a> [api](#output\_api) | GraphQL API details |
| <a name="output_configuration_table_arn"></a> [configuration\_table\_arn](#output\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings |
| <a name="output_encryption_key"></a> [encryption\_key](#output\_encryption\_key) | KMS key for encryption |
| <a name="output_input_bucket"></a> [input\_bucket](#output\_input\_bucket) | S3 bucket for input documents |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix used for all resources |
| <a name="output_output_bucket"></a> [output\_bucket](#output\_output\_bucket) | S3 bucket for processed output documents |
| <a name="output_processor_type"></a> [processor\_type](#output\_processor\_type) | Type of document processor used |
| <a name="output_queue_processor_arn"></a> [queue\_processor\_arn](#output\_queue\_processor\_arn) | ARN of the Lambda function that processes documents from the queue |
| <a name="output_queue_sender_arn"></a> [queue\_sender\_arn](#output\_queue\_sender\_arn) | ARN of the Lambda function that sends documents to the processing queue |
| <a name="output_step_function_arn"></a> [step\_function\_arn](#output\_step\_function\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_user_identity"></a> [user\_identity](#output\_user\_identity) | User identity details |
| <a name="output_web_ui"></a> [web\_ui](#output\_web\_ui) | Web UI details |
| <a name="output_web_ui_url"></a> [web\_ui\_url](#output\_web\_ui\_url) | Web UI URL (if enabled) |
| <a name="output_working_bucket"></a> [working\_bucket](#output\_working\_bucket) | S3 bucket for working files |
<!-- END_TF_DOCS -->