# SageMaker UDOP Model Training Module (Enhanced)

This enhanced Terraform module creates and trains a SageMaker UDOP model using the RVL-CDIP dataset with enhanced features including Docker container images and robust Lambda deployment using the `terraform-aws-modules/lambda/aws` module.

## Features

### 🚀 **Enhanced Architecture**

- **Docker Container Images**: Lambda functions with all dependencies included
- **terraform-aws-modules/lambda**: Battle-tested Lambda deployment with best practices
- **Pure Terraform Orchestration**: No CloudFormation dependencies
- **Comprehensive Error Handling**: Robust error handling and status monitoring
- **ECR Integration**: Automatic Docker image building and pushing

### 🔧 **Enhanced Capabilities**

- **Automated Data Generation**: Downloads and processes RVL-CDIP dataset with Textract
- **SageMaker Training**: Creates and manages training jobs with proper monitoring
- **Training Completion Polling**: Pure Terraform polling mechanism for job completion
- **Comprehensive Outputs**: Detailed outputs for integration and monitoring

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Docker Build  │    │   ECR Registry   │    │  Lambda Deploy  │
│   (Local)       │───▶│   (AWS)          │───▶│  (terraform-aws │
│                 │    │                  │    │   -modules)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Training Workflow                            │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Data Gen      │ Training Job    │      Completion Check       │
│ (Lambda+Docker) │ (Lambda+Docker) │     (Lambda+Polling)        │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      S3 Model Artifacts                         │
│              (Ready for SageMaker Endpoint)                    │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools

- **Docker**: For building Lambda container images
- **Terraform**: >= 1.0 with Docker provider support
- **AWS CLI**: Configured with appropriate permissions
- **Python 3.11**: For training status checking script

### AWS Permissions

- **Lambda**: Create functions, invoke, manage container images
- **ECR**: Create repositories, push/pull images
- **SageMaker**: Create training jobs, manage models
- **S3**: Create buckets, read/write objects
- **IAM**: Create roles and policies
- **Textract**: Process document images

## Usage

### Basic Usage

```hcl
module "sagemaker_model" {
  source = "./sagemaker-model"
  
  name_prefix = "my-udop-model"
  kms_key_id  = aws_kms_key.encryption_key.key_id
  
  # Training configuration
  max_epochs    = 3
  base_model    = "microsoft/udop-large"
  retrain_model = false
  
  tags = {
    Environment = "production"
    Project     = "document-processing"
  }
}
```

### Advanced Configuration

```hcl
module "sagemaker_model" {
  source = "./sagemaker-model"
  
  name_prefix = "advanced-udop-model"
  kms_key_id  = aws_kms_key.encryption_key.key_id
  
  # Enhanced training configuration
  max_epochs    = 5
  base_model    = "microsoft/udop-large"
  retrain_model = true  # Retrain on each apply
  
  tags = {
    Environment = "production"
    Project     = "document-processing"
    CostCenter  = "ml-training"
  }
}

# Use the trained model
resource "aws_sagemaker_model" "udop_classifier" {
  name               = "udop-classifier"
  execution_role_arn = module.sagemaker_model.sagemaker_execution_role_arn
  
  primary_container {
    image          = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.1.0-gpu-py310"
    model_data_url = module.sagemaker_model.model_data_uri
  }
  
  depends_on = [module.sagemaker_model]
}
```

## Enhanced Features

### 1. **Docker Container Images**

Lambda functions use Docker containers with all dependencies:

```dockerfile
# Example: src/generate_demo_data/Dockerfile
FROM public.ecr.aws/lambda/python:3.11

# Install system dependencies
RUN yum update -y && \
    yum install -y gcc g++ git && \
    yum clean all

# Install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY index.py ${LAMBDA_TASK_ROOT}

CMD [ "index.lambda_handler" ]
```

### 2. **terraform-aws-modules/lambda Integration**

Uses the community-maintained Lambda module for best practices:

```hcl
module "generate_demo_data_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${local.name_prefix}-generate-demo-data"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.generate_demo_data.repository_url}:latest"
  
  # Automatic IAM policy management
  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = ["s3:GetObject", "s3:PutObject"]
      resources = ["${aws_s3_bucket.data_bucket.arn}/*"]
    }
  }
}
```

### 3. **Pure Terraform Training Completion Polling**

No CloudFormation dependencies - uses pure Terraform constructs:

```hcl
# Wait for training to start
resource "time_sleep" "initial_wait" {
  create_duration = "5m"
}

# Poll for completion using external data source
data "external" "training_status" {
  program = ["python3", local_file.training_status_checker.filename]
  
  query = {
    request_id = "terraform-${random_string.request_id.result}"
    max_attempts = "60"  # 30 minutes
  }
}
```

### 4. **Comprehensive Status Monitoring**

Detailed training status and progress tracking:

```bash
# Check training status
terraform output training_status

# Example output:
# {
#   "status" = "complete"
#   "message" = "Training job completed successfully"
#   "attempts" = "15"
#   "complete" = true
# }
```

## Training Process

### Phase 1: Docker Image Building (2-5 minutes)

- Builds Lambda container images with all dependencies
- Pushes images to ECR repositories
- Handles dependency management automatically

### Phase 2: Data Generation (10-15 minutes)

- Downloads RVL-CDIP dataset from Hugging Face
- Processes 1,600 document images with AWS Textract
- Stores processed data in S3 with proper structure

### Phase 3: Model Training (15-30 minutes)

- Creates SageMaker training job with PyTorch framework
- Uses ml.g5.12xlarge instance for GPU acceleration
- Monitors training progress with comprehensive logging

### Phase 4: Completion Verification (1-2 minutes)

- Polls training job status every 30 seconds
- Verifies model artifacts are properly stored
- Provides detailed completion status

## Monitoring and Debugging

### Training Job Monitoring

```bash
# Check training job status
aws sagemaker describe-training-job --training-job-name $(terraform output -raw training_job_name)

# View training logs
aws logs get-log-events \
  --log-group-name /aws/sagemaker/TrainingJobs \
  --log-stream-name $(terraform output -raw training_job_name)/algo-1-$(date +%s)
```

### Lambda Function Monitoring

```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$(terraform output -json lambda_functions | jq -r '.generate_demo_data.function_name')"

# View recent logs
aws logs tail "/aws/lambda/$(terraform output -json lambda_functions | jq -r '.generate_demo_data.function_name')" --follow
```

### ECR Repository Management

```bash
# List images in repository
aws ecr list-images --repository-name $(terraform output -json ecr_repositories | jq -r '.generate_demo_data.repository_url' | cut -d'/' -f2)

# View image details
aws ecr describe-images --repository-name $(terraform output -json ecr_repositories | jq -r '.generate_demo_data.repository_url' | cut -d'/' -f2)
```

## Troubleshooting

### Common Issues

#### 1. **Docker Build Failures**

```bash
# Check Docker daemon
docker info

# Verify Dockerfile syntax
docker build --no-cache src/generate_demo_data/

# Check ECR authentication
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
```

#### 2. **Lambda Container Image Issues**

```bash
# Test container locally
docker run --rm -p 9000:8080 <image-name>:latest

# Check Lambda function configuration
aws lambda get-function --function-name <function-name>
```

#### 3. **Training Job Failures**

```bash
# Check training job details
aws sagemaker describe-training-job --training-job-name <job-name>

# View failure reason
aws sagemaker describe-training-job --training-job-name <job-name> --query 'FailureReason'
```

### Performance Optimization

#### 1. **Docker Image Optimization**

- Use multi-stage builds to reduce image size
- Leverage Docker layer caching
- Use .dockerignore to exclude unnecessary files

#### 2. **Lambda Performance**

- Increase memory allocation for data processing
- Use provisioned concurrency for consistent performance
- Optimize Python code for Lambda environment

#### 3. **Training Performance**

- Use larger SageMaker instances for faster training
- Implement distributed training for large datasets
- Use Spot instances for cost optimization

## Cost Optimization

### Training Costs

- **Docker Builds**: Free (local builds)
- **ECR Storage**: ~$0.10/GB/month
- **Lambda Execution**: ~$0.10-1.00 per training run
- **SageMaker Training**: ~$3-5 per run (ml.g5.12xlarge)

### Optimization Strategies

- Use ECR lifecycle policies to clean up old images
- Implement training job scheduling for off-peak hours
- Use SageMaker Spot instances when available

## Production Considerations

### Security

- ECR image scanning enabled by default
- KMS encryption for all data at rest
- IAM roles with least privilege principles
- VPC endpoints for private connectivity (optional)

### Reliability

- Comprehensive error handling in Lambda functions
- Training job retry logic
- CloudWatch monitoring and alerting
- Backup strategies for model artifacts

### Scalability

- Auto-scaling Lambda concurrency
- Multiple ECR repositories for different models
- Parallel training job support
- Multi-region deployment capability

## Migration from Simplified Version

If migrating from the simplified version:

1. **Install Docker**: Ensure Docker is available in your environment
2. **Update Terraform**: Add Docker provider to your configuration
3. **Rebuild Dependencies**: Let Terraform handle Docker image building
4. **Test Thoroughly**: Verify all Lambda functions work with container images

## Support

For issues and questions:

- **Docker Issues**: Check Docker documentation and ECR guides
- **Lambda Module**: Refer to terraform-aws-modules/lambda documentation
- **SageMaker**: Use AWS SageMaker documentation and support
- **Training Issues**: Check CloudWatch logs and SageMaker training job details

This enhanced implementation provides a comprehensive foundation for SageMaker model training with Terraform, closely matching the capabilities of the original CDK implementation while maintaining pure Terraform architecture.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | >= 3.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_docker"></a> [docker](#provider\_docker) | 3.6.2 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.5 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.6.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_generate_demo_data_lambda"></a> [generate\_demo\_data\_lambda](#module\_generate\_demo\_data\_lambda) | terraform-aws-modules/lambda/aws | ~> 7.0 |
| <a name="module_sagemaker_train_is_complete_lambda"></a> [sagemaker\_train\_is\_complete\_lambda](#module\_sagemaker\_train\_is\_complete\_lambda) | terraform-aws-modules/lambda/aws | ~> 7.0 |
| <a name="module_sagemaker_train_lambda"></a> [sagemaker\_train\_lambda](#module\_sagemaker\_train\_lambda) | terraform-aws-modules/lambda/aws | ~> 7.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.generate_demo_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository.sagemaker_train](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_iam_role.sagemaker_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.sagemaker_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.sagemaker_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_invocation.generate_demo_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.sagemaker_train](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_s3_bucket.data_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.data_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.data_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.data_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [docker_image.generate_demo_data](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image) | resource |
| [docker_image.sagemaker_train](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image) | resource |
| [local_file.training_status_checker](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.push_generate_demo_data](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.push_sagemaker_train](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.request_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.initial_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.model_upload_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [external_external.training_status](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base_model"></a> [base\_model](#input\_base\_model) | Base model to use for training | `string` | `"microsoft/udop-large"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID for encryption | `string` | n/a | yes |
| <a name="input_max_epochs"></a> [max\_epochs](#input\_max\_epochs) | Maximum number of epochs for training | `number` | `3` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_retrain_model"></a> [retrain\_model](#input\_retrain\_model) | Whether to retrain the model on each apply | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_bucket_name"></a> [data\_bucket\_name](#output\_data\_bucket\_name) | Name of the S3 bucket containing training data |
| <a name="output_ecr_repositories"></a> [ecr\_repositories](#output\_ecr\_repositories) | ECR repository details |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Lambda function details |
| <a name="output_model_data_bucket"></a> [model\_data\_bucket](#output\_model\_data\_bucket) | S3 bucket name containing the trained model |
| <a name="output_model_data_key"></a> [model\_data\_key](#output\_model\_data\_key) | S3 object key for the trained model |
| <a name="output_model_data_uri"></a> [model\_data\_uri](#output\_model\_data\_uri) | Full S3 URI for the trained model |
| <a name="output_sagemaker_execution_role_arn"></a> [sagemaker\_execution\_role\_arn](#output\_sagemaker\_execution\_role\_arn) | ARN of the SageMaker execution role |
| <a name="output_training_job_name"></a> [training\_job\_name](#output\_training\_job\_name) | Name of the SageMaker training job |
| <a name="output_training_status"></a> [training\_status](#output\_training\_status) | Status of the training job completion |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
