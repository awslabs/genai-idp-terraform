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
cd genaiic-idp-accelerator-terraform/examples/sagemaker-udop-processor
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
enable_assessment = true
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
