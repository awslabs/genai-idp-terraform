# SageMaker UDOP Processor Example with Automated Model Training

This example demonstrates how to deploy a complete document processing solution using the SageMaker UDOP processor from the GenAI IDP Accelerator with automated model training and an integrated Web UI.

## Architecture Overview

The SageMaker UDOP processor provides a specialized solution for document processing using SageMaker endpoints for classification combined with foundation models for extraction. This example creates:

- **Automated Model Training**: Downloads RVL-CDIP dataset and trains a UDOP model automatically
- **Processing Environment**: Core infrastructure for document processing
- **SageMaker Classifier**: Document classification using the trained UDOP model
- **SageMaker UDOP Processor**: Document processing pipeline with SageMaker classification
- **Web UI**: React-based web application for document upload and management
- **User Identity**: Cognito-based authentication and authorization
- **S3 Buckets**: Input, output, training data, and evaluation baseline storage
- **KMS Encryption**: End-to-end encryption for all resources

## Features

### 🚀 **Core Capabilities**

- **Automated Model Training**: Automatically downloads RVL-CDIP dataset and trains UDOP model
- **Specialized Classification**: Uses trained SageMaker UDOP model for document classification
- **Foundation Model Extraction**: Uses Amazon Bedrock models for information extraction
- **Web User Interface**: Upload documents and view results through a web browser
- **User Authentication**: Secure access with Amazon Cognito
- **Step Functions Workflow**: Orchestrates the complete processing pipeline
- **Real-time Status Tracking**: GraphQL API for monitoring document status
- **Auto-Scaling**: Automatically scales SageMaker endpoints based on demand

### 🔧 **Optional Features**

- **Document Summarization**: AI-powered document summarization
- **Assessment Framework**: Document quality assessment and validation
- **Evaluation Framework**: Baseline comparison for accuracy measurement
- **Custom Configuration**: Configurable document classes and attributes
- **Encryption**: KMS encryption for all data at rest and in transit
- **CloudFront Distribution**: Global content delivery for the web UI
- **Access Logging**: Optional CloudFront and S3 access logging

## Model Training Process

This example includes a complete automated model training pipeline:

1. **Data Generation**: Downloads RVL-CDIP dataset (100 examples per class) from Hugging Face
2. **Text Extraction**: Processes document images with AWS Textract
3. **Model Training**: Trains UDOP model using SageMaker with PyTorch framework
4. **Model Deployment**: Automatically deploys trained model to SageMaker endpoint

### Training Configuration

The training process can be customized through the `training_config` variable:

```hcl
training_config = {
  max_epochs    = 3                      # Number of training epochs
  base_model    = "microsoft/udop-large" # Base UDOP model to fine-tune
  retrain_model = false                  # Set to true to retrain on each apply
}
```

### Training Time and Cost

- **Training Duration**: 15-30 minutes (depending on epochs and instance type)
- **Training Instance**: ml.g5.12xlarge (GPU-accelerated)
- **Estimated Cost**: ~$3-5 per training run
- **Dataset Size**: 1,600 documents (100 per class, 16 document types)

## Prerequisites

### 1. **AWS Account Setup**

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Docker installed (for building Lambda container images)
- Access to Amazon Bedrock in your chosen region
- Access to Amazon SageMaker
- Sufficient service quotas for G5 instances

### 2. **Bedrock Model Access**

Before deploying, enable access to the required Bedrock models in the AWS Console:

1. Navigate to Amazon Bedrock → Model access
2. Request access to the models you plan to use:
   - **Extraction**: `us.amazon.nova-pro-v1:0` (default)
   - **Summarization**: `us.amazon.nova-pro-v1:0` (default)
   - **Assessment**: Uses extraction model (if enabled)
   - **Evaluation**: `anthropic.claude-3-sonnet-20240229-v1:0` (if enabled)

### 3. **Service Quotas**

Ensure you have sufficient quotas for:

- **SageMaker Training**: ml.g5.12xlarge instances
- **SageMaker Inference**: ml.g4dn.xlarge instances (or your chosen type)
- **Lambda**: Container image functions with 2GB memory

## Quick Start

### 1. **Clone and Navigate**

```bash
git clone <repository-url>
cd genai-idp-terraform/examples/sagemaker-udop-processor
```

### 2. **Configure Variables**

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

**Minimal configuration**:

```hcl
region      = "us-east-1"
prefix      = "my-udp-processor"
admin_email = "admin@example.com"

tags = {
  Environment = "development"
  Project     = "document-processing"
}
```

### 3. **Deploy Infrastructure**

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure (this will take 30-45 minutes due to model training)
terraform apply
```

### 4. **Access Your Deployment**

After deployment, Terraform will output important information:

```bash
# View deployment outputs
terraform output

# Example outputs:
# web_ui_url = "https://d1234567890.cloudfront.net"
# api_endpoint = "https://abcdef.appsync-api.us-east-1.amazonaws.com/graphql"
# input_bucket = "my-udp-processor-input-abc123"
# classifier_endpoint_name = "my-udp-processor-classifier-endpoint"
```

## Usage Examples

### Upload and Process Documents

#### 1. **Web Interface** (Recommended)

- Navigate to the `web_ui_url` from your Terraform outputs
- Sign in with the admin credentials (check your email for temporary password)
- Upload documents through the drag-and-drop interface
- Monitor processing status in real-time
- View classification results and extracted data

#### 2. **Direct S3 Upload**

```bash
# Upload a document to trigger processing
aws s3 cp my-document.pdf s3://your-input-bucket/
```

#### 3. **Programmatic Upload**

```python
import boto3

s3 = boto3.client('s3')
s3.upload_file('local-document.pdf', 'your-input-bucket', 'documents/document.pdf')
```

### Monitor Processing

```bash
# Check Step Functions executions
aws stepfunctions list-executions --state-machine-arn <state-machine-arn>

# View SageMaker endpoint status
aws sagemaker describe-endpoint --endpoint-name <classifier-endpoint-name>

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/your-prefix"
```

## Configuration Options

### Basic Configuration

```hcl
# terraform.tfvars
region = "us-east-1"
prefix = "my-udp-processor"

# Training configuration
training_config = {
  max_epochs    = 5                      # More epochs for better accuracy
  base_model    = "microsoft/udop-large"
  retrain_model = true                   # Retrain on each apply
}

# SageMaker endpoint configuration
classifier_instance_type = "ml.g4dn.2xlarge"  # Larger instance
classifier_min_instance_count = 2              # Higher minimum capacity
```

### Advanced Configuration

```hcl
# Enable additional features
enable_evaluation = true
enable_reporting  = true
summarization_enabled = true

# Custom model selection
summarization_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
evaluation_model_id    = "us.amazon.nova-pro-v1:0"

# Web UI customization
web_ui = {
  enabled           = true
  logging_enabled   = true
  enable_signup     = "ADMIN_ONLY"
}
```

## Document Types Supported

The trained UDOP model supports classification of 16 document types from the RVL-CDIP dataset:

1. **Letter** - Personal and business correspondence
2. **Form** - Structured forms and applications
3. **Email** - Email communications
4. **Handwritten** - Handwritten documents
5. **Advertisement** - Marketing materials and ads
6. **Scientific Report** - Research reports and studies
7. **Scientific Publication** - Academic papers and journals
8. **Specification** - Technical specifications
9. **File Folder** - File organization documents
10. **News Article** - News and media content
11. **Budget** - Financial budgets and planning
12. **Invoice** - Bills and invoices
13. **Presentation** - Slide presentations
14. **Questionnaire** - Surveys and questionnaires
15. **Resume** - CVs and resumes
16. **Memo** - Internal memos and communications

## Customization

### Using Your Own Dataset

To train with a custom dataset, modify the data generation Lambda function:

1. Edit `src/generate_demo_data/index.py`
2. Replace the Hugging Face dataset loading:

```python
# Replace this line:
return load_dataset("jordyvl/rvl_cdip_100_examples_per_class", split=split)

# With your dataset:
return load_dataset("your-org/your-dataset", split=split)
```

### Custom Training Parameters

Modify the training configuration in `sagemaker-model/main.tf`:

```hcl
# In the SageMaker training job
hyperparameters = {
  "max_epochs": local.max_epochs,
  "base_model": local.base_model,
  "learning_rate": "1e-5",     # Add custom parameters
  "batch_size": "16",
  "warmup_steps": "100"
}
```

### Different Instance Types

Change the training or inference instance types:

```hcl
# For training (in sagemaker-model module)
instance_type = "ml.p3.8xlarge"  # Different GPU instance

# For inference (in variables)
classifier_instance_type = "ml.c5.2xlarge"  # CPU instance for cost savings
```

## Troubleshooting

### Common Issues

#### 1. **Training Job Fails**

```bash
# Check training job logs
aws sagemaker describe-training-job --training-job-name <job-name>
aws logs get-log-events --log-group-name /aws/sagemaker/TrainingJobs --log-stream-name <job-name>
```

**Common causes**:

- Insufficient service quotas for G5 instances
- Network connectivity issues downloading dataset
- Insufficient disk space or memory

#### 2. **Model Deployment Issues**

```bash
# Check endpoint status
aws sagemaker describe-endpoint --endpoint-name <endpoint-name>
```

**Common causes**:

- Model artifacts not found in S3
- Incorrect inference container image
- IAM permission issues

#### 3. **Lambda Function Timeouts**

```bash
# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/your-prefix"
```

**Solutions**:

- Increase Lambda timeout and memory
- Check Docker image build process
- Verify ECR repository permissions

#### 4. **Dataset Download Issues**

**Error**: `ConnectionError` or `TimeoutError` during dataset download

**Solutions**:

- Increase Lambda timeout to 15 minutes
- Check internet connectivity from Lambda
- Use VPC endpoints if in private subnet

### Performance Optimization

#### 1. **Training Performance**

- Use larger instance types (ml.g5.24xlarge)
- Increase batch size in hyperparameters
- Use distributed training for large datasets

#### 2. **Inference Performance**

- Use GPU instances for faster inference
- Enable auto-scaling based on invocation rate
- Use SageMaker multi-model endpoints for multiple models

#### 3. **Cost Optimization**

- Use Spot instances for training (when available)
- Use smaller instance types for inference
- Enable auto-scaling to scale down during low usage

## Security Considerations

### Data Protection

- All data encrypted at rest with KMS
- In-transit encryption for all communications
- VPC endpoints for private connectivity (optional)

### Access Control

- IAM roles with least privilege principles
- Cognito authentication for web UI
- API-level authorization with AppSync

### Compliance

- CloudTrail logging for all API calls
- CloudWatch monitoring and alerting
- Data retention policies configurable

## Cost Estimation

### Training Costs (per run)

- **SageMaker Training**: ~$3-5 (ml.g5.12xlarge for 30 minutes)
- **Lambda Execution**: ~$0.10 (data processing)
- **Textract**: ~$2.40 (1,600 pages at $0.0015/page)
- **S3 Storage**: ~$0.05 (training data and model)

### Monthly Operating Costs (estimated)

- **SageMaker Endpoint**: ~$200-400 (ml.g4dn.xlarge, 24/7)
- **Lambda**: ~$10-50 (depending on usage)
- **S3**: ~$5-20 (depending on document volume)
- **Other Services**: ~$10-30 (CloudWatch, KMS, etc.)

**Total Monthly**: ~$225-500 (varies by usage and configuration)

## Support and Contributing

For issues, questions, or contributions:

1. **Documentation**: Check the module README files
2. **Issues**: Create GitHub issues for bugs
3. **Contributions**: Submit pull requests with improvements
4. **AWS Support**: Use AWS Support for service-specific issues

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](../../LICENSE) file for details.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.4.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_genai_idp_accelerator"></a> [genai\_idp\_accelerator](#module\_genai\_idp\_accelerator) | ../.. | n/a |
| <a name="module_sagemaker_model"></a> [sagemaker\_model](#module\_sagemaker\_model) | ./sagemaker-model | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.sagemaker_scaling_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.sagemaker_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cognito_identity_pool.identity_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool) | resource |
| [aws_cognito_identity_pool_roles_attachment.identity_pool_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool_roles_attachment) | resource |
| [aws_cognito_user.admin_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user) | resource |
| [aws_cognito_user_group.admin_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_in_group.admin_user_in_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_in_group) | resource |
| [aws_cognito_user_pool.user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.user_pool_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_glue_catalog_database.reporting_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_iam_role.authenticated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sagemaker_model_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.unauthenticated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.sagemaker_model_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.sagemaker_model_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.sagemaker_model_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.evaluation_baseline_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.reporting_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.working_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_notification.input_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_sagemaker_endpoint.udop_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_endpoint) | resource |
| [aws_sagemaker_endpoint_configuration.udop_endpoint_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_endpoint_configuration) | resource |
| [aws_sagemaker_model.udop_model](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_model) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Optional email address for the admin user. If provided, an admin user will be created in the Cognito User Pool. | `string` | `null` | no |
| <a name="input_classifier_instance_type"></a> [classifier\_instance\_type](#input\_classifier\_instance\_type) | SageMaker instance type for the classifier endpoint | `string` | `"ml.g4dn.xlarge"` | no |
| <a name="input_classifier_max_instance_count"></a> [classifier\_max\_instance\_count](#input\_classifier\_max\_instance\_count) | Maximum number of instances for the classifier endpoint | `number` | `4` | no |
| <a name="input_classifier_min_instance_count"></a> [classifier\_min\_instance\_count](#input\_classifier\_min\_instance\_count) | Minimum number of instances for the classifier endpoint | `number` | `1` | no |
| <a name="input_classifier_scale_in_cooldown_seconds"></a> [classifier\_scale\_in\_cooldown\_seconds](#input\_classifier\_scale\_in\_cooldown\_seconds) | Cooldown period after scaling in (seconds) for classifier | `number` | `300` | no |
| <a name="input_classifier_scale_out_cooldown_seconds"></a> [classifier\_scale\_out\_cooldown\_seconds](#input\_classifier\_scale\_out\_cooldown\_seconds) | Cooldown period after scaling out (seconds) for classifier | `number` | `60` | no |
| <a name="input_classifier_target_invocations_per_instance_per_minute"></a> [classifier\_target\_invocations\_per\_instance\_per\_minute](#input\_classifier\_target\_invocations\_per\_instance\_per\_minute) | Target invocations per instance per minute for classifier scaling | `number` | `20` | no |
| <a name="input_config_file_path"></a> [config\_file\_path](#input\_config\_file\_path) | Path to the configuration YAML file for document processing | `string` | `"../../sources/config_library/pattern-3/rvl-cdip-package-sample/config.yaml"` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | The retention period for document tracking data in days | `number` | `365` | no |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Enable GraphQL API for programmatic access and notifications | `bool` | `true` | no |
| <a name="input_enable_assessment"></a> [enable\_assessment](#input\_enable\_assessment) | Enable assessment functionality for document quality assessment | `bool` | `false` | no |
| <a name="input_enable_evaluation"></a> [enable\_evaluation](#input\_enable\_evaluation) | Enable evaluation functionality (simplified flag) | `bool` | `false` | no |
| <a name="input_enable_reporting"></a> [enable\_reporting](#input\_enable\_reporting) | Enable reporting functionality (simplified flag) | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption (will be created if not provided) | `string` | `null` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | Model ID for evaluation processing | `string` | `"anthropic.claude-3-sonnet-20240229-v1:0"` | no |
| <a name="input_force_rebuild_layers"></a> [force\_rebuild\_layers](#input\_force\_rebuild\_layers) | Force rebuild of Lambda layers regardless of requirements changes | `bool` | `false` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for the document processing components | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by the document processing components in days | `number` | `7` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_sagemaker_endpoint_name"></a> [sagemaker\_endpoint\_name](#input\_sagemaker\_endpoint\_name) | Name of the SageMaker endpoint for UDOP processing (SageMaker UDOP processor only) | `string` | `"udop-endpoint"` | no |
| <a name="input_summarization_enabled"></a> [summarization\_enabled](#input\_summarization\_enabled) | Enable document summarization for SageMaker UDOP processor | `bool` | `true` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Model ID for document summarization (SageMaker UDOP processor) | `string` | `"us.anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_training_config"></a> [training\_config](#input\_training\_config) | Configuration for SageMaker model training | <pre>object({<br/>    max_epochs    = optional(number, 3)<br/>    base_model    = optional(string, "microsoft/udop-large")<br/>    retrain_model = optional(bool, false)<br/>  })</pre> | <pre>{<br/>  "base_model": "microsoft/udop-large",<br/>  "max_epochs": 3,<br/>  "retrain_model": false<br/>}</pre> | no |
| <a name="input_web_ui"></a> [web\_ui](#input\_web\_ui) | Web UI configuration object | <pre>object({<br/>    enabled                    = optional(bool, true)<br/>    create_infrastructure      = optional(bool, true)<br/>    bucket_name                = optional(string, null)<br/>    cloudfront_distribution_id = optional(string, null)<br/>    logging_enabled            = optional(bool, false)<br/>    logging_bucket_arn         = optional(string, null)<br/>    enable_signup              = optional(string, "")<br/>  })</pre> | <pre>{<br/>  "bucket_name": null,<br/>  "cloudfront_distribution_id": null,<br/>  "create_infrastructure": true,<br/>  "enable_signup": "",<br/>  "enabled": true,<br/>  "logging_bucket_arn": null,<br/>  "logging_enabled": false<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api"></a> [api](#output\_api) | GraphQL API details |
| <a name="output_classifier"></a> [classifier](#output\_classifier) | SageMaker classifier endpoint details |
| <a name="output_classifier_endpoint_arn"></a> [classifier\_endpoint\_arn](#output\_classifier\_endpoint\_arn) | ARN of the SageMaker classifier endpoint |
| <a name="output_classifier_endpoint_name"></a> [classifier\_endpoint\_name](#output\_classifier\_endpoint\_name) | Name of the SageMaker classifier endpoint |
| <a name="output_classifier_model_arn"></a> [classifier\_model\_arn](#output\_classifier\_model\_arn) | ARN of the SageMaker classifier model |
| <a name="output_classifier_model_name"></a> [classifier\_model\_name](#output\_classifier\_model\_name) | Name of the SageMaker classifier model |
| <a name="output_configuration_table_arn"></a> [configuration\_table\_arn](#output\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings |
| <a name="output_encryption_key"></a> [encryption\_key](#output\_encryption\_key) | KMS key for encryption |
| <a name="output_input_bucket"></a> [input\_bucket](#output\_input\_bucket) | S3 bucket for input documents |
| <a name="output_model_training"></a> [model\_training](#output\_model\_training) | SageMaker model training details |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix used for all resources |
| <a name="output_output_bucket"></a> [output\_bucket](#output\_output\_bucket) | S3 bucket for processed output documents |
| <a name="output_processor_type"></a> [processor\_type](#output\_processor\_type) | Type of document processor used |
| <a name="output_queue_processor_arn"></a> [queue\_processor\_arn](#output\_queue\_processor\_arn) | ARN of the Lambda function that processes documents from the queue |
| <a name="output_queue_sender_arn"></a> [queue\_sender\_arn](#output\_queue\_sender\_arn) | ARN of the Lambda function that sends documents to the processing queue |
| <a name="output_step_function_arn"></a> [step\_function\_arn](#output\_step\_function\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_training_data_bucket"></a> [training\_data\_bucket](#output\_training\_data\_bucket) | S3 bucket containing training data and model artifacts |
| <a name="output_user_identity"></a> [user\_identity](#output\_user\_identity) | User identity details |
| <a name="output_web_ui"></a> [web\_ui](#output\_web\_ui) | Web UI details |
| <a name="output_web_ui_url"></a> [web\_ui\_url](#output\_web\_ui\_url) | Web UI URL (if enabled) |
| <a name="output_working_bucket"></a> [working\_bucket](#output\_working\_bucket) | S3 bucket for working files |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
