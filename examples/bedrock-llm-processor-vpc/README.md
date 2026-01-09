# Bedrock LLM Processor Example with Isolated VPC

This example demonstrates how to deploy the GenAI IDP Accelerator with the Bedrock LLM processor in a fully isolated VPC environment. This configuration provides maximum security by running Lambda functions in isolated subnets with no internet access, using VPC endpoints for all AWS service communication.

## Architecture Overview

This example creates:

### VPC Infrastructure

- **VPC**: Custom VPC with configurable CIDR block (default: 10.0.0.0/16)
- **Isolated Subnets**: 2 isolated subnets across different AZs for Lambda functions (no internet access)
- **Route Tables**: Route tables for isolated subnets (no internet routes)

### Security Groups

- **Lambda Security Group**: Allows outbound HTTPS traffic to VPC endpoints within the VPC CIDR
- **VPC Endpoints Security Group**: Allows inbound HTTPS traffic from VPC resources (Lambda functions)

### VPC Endpoints

- **S3 Gateway Endpoint**: Direct access to S3 without internet routing
- **DynamoDB Interface Endpoint**: Private access to DynamoDB without internet routing
- **Bedrock Interface Endpoints**: Private access to Amazon Bedrock services
- **Textract Interface Endpoint**: Private access to Amazon Textract services
- **CloudWatch Interface Endpoints**: Private access to CloudWatch Logs and Monitoring
- **KMS Interface Endpoint**: Private access to AWS KMS
- **Lambda Interface Endpoint**: Private access to AWS Lambda service
- **Step Functions Interface Endpoint**: Private access to AWS Step Functions
- **SQS Interface Endpoint**: Private access to Amazon SQS
- **EventBridge Interface Endpoint**: Private access to Amazon EventBridge
- **STS Interface Endpoint**: Private access to AWS STS
- **SSM Interface Endpoint**: Private access to AWS Systems Manager
- **CodeBuild Interface Endpoint**: Private access to AWS CodeBuild

### Document Processing Components

- **Bedrock LLM Processor**: Uses Claude models for document classification and extraction
- **S3 Buckets**: Input, output, and working buckets for document processing
- **Step Functions**: Orchestrates the document processing workflow
- **Lambda Functions**: Run in private subnets with VPC configuration

## Prerequisites

Before deploying this example, ensure you have:

### Required Tools

- **[Terraform](https://www.terraform.io/)**: Version 1.0 or later
- **[AWS CLI](https://aws.amazon.com/cli/)**: Configured with appropriate credentials

### AWS Requirements

- **AWS Account**: With appropriate permissions for VPC, Lambda, Bedrock, etc.
- **Bedrock Model Access**: Enable access to required models in the AWS Console
- **Service Quotas**: Ensure adequate quotas for Lambda, VPC endpoints, etc.

### Enable Bedrock Model Access

**⚠️ Important**: Before deploying, you must enable access to Bedrock models:

1. Go to the [AWS Console](https://console.aws.amazon.com/)
2. Navigate to **Amazon Bedrock**
3. Click **"Model access"** in the left navigation
4. Request access to the models you plan to use:
   - **Claude 3.5 Sonnet**: `us.anthropic.claude-3-5-sonnet-20241022-v2:0`
   - **Nova Pro**: `us.amazon.nova-pro-v1:0`
   - **Claude 3 Sonnet**: `anthropic.claude-3-sonnet-20240229-v1:0`
5. Click the checkbox next to each model and **"Request model access"**

This is a one-time manual step that cannot be automated through Terraform.

## Quick Start

### 1. Configure Your Deployment

Copy and customize the example configuration:

```bash
# Navigate to the VPC example directory
cd examples/bedrock-llm-processor-vpc

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your specific values
nano terraform.tfvars
```

**Minimal configuration example**:

```hcl
# terraform.tfvars
region = "us-east-1"
prefix = "my-idp-vpc"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

tags = {
  Environment = "development"
  Project     = "document-processing-vpc"
}
```

### 2. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 3. Access Your Deployment

After deployment, Terraform will output important information:

```bash
# View deployment outputs
terraform output

# Example outputs:
# vpc_id = "vpc-1234567890abcdef0"
# private_subnet_ids = ["subnet-1234567890abcdef0", "subnet-0987654321fedcba0"]
```

## Configuration Options

### VPC Configuration

You can either create a new VPC or use an existing one:

#### Option 1: Create New VPC (Default)

```hcl
# terraform.tfvars
vpc_cidr = "10.0.0.0/16"
```

This will create:

- New VPC with specified CIDR
- Isolated subnets across 2 AZs
- Security groups for Lambda functions and VPC endpoints
- All required VPC endpoints

#### Option 2: Use Existing VPC

```hcl
# terraform.tfvars
vpc = {
  vpc_id                 = "vpc-12345678"
  vpc_subnet_ids         = ["subnet-12345678", "subnet-87654321"] 
  vpc_security_group_ids = ["sg-12345678"]
}
```

**Requirements for existing VPC:**

- Subnets must be isolated (no internet access)
- Security groups must allow HTTPS egress to VPC CIDR and AWS service IPs
- VPC must have DNS resolution and DNS hostnames enabled
- All three properties (vpc_id, vpc_subnet_ids, vpc_security_group_ids) must be provided

**Note**: When using existing VPC, no VPC endpoints will be created. You must ensure your existing VPC has the required VPC endpoints configured.

### Model Configuration

```hcl
# Use different models for different tasks
classification_model_id = "us.amazon.nova-pro-v1:0"
extraction_model_id     = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
summarization_model_id  = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
```

### Feature Toggles

```hcl
# Enable additional features
enable_evaluation = true
enable_reporting  = true
summarization_enabled = true
```

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                              VPC                                │
│                         (10.0.0.0/16)                          │
├─────────────────────────────────────────────────────────────────┤
│                    Isolated Subnets                            │
│                   (No Internet Access)                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │      Lambda Functions (Document Processing)             │   │
│  │      - Classification                                   │   │
│  │      - Extraction                                       │   │
│  │      - Summarization                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              VPC Endpoints                              │   │
│  │      - S3 (Gateway)                                     │   │
│  │      - DynamoDB (Gateway)                               │   │
│  │      - Bedrock Runtime (Interface)                      │   │
│  │      - Textract (Interface)                             │   │
│  │      - CloudWatch Logs/Monitoring (Interface)          │   │
│  │      - KMS, Lambda, SQS, Step Functions (Interface)    │   │
│  │      - EventBridge, STS, SSM, CodeBuild (Interface)    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  No Internet    │
                 │  Connectivity   │
                 └─────────────────┘
```

## Security Benefits

### Network Isolation

- **Isolated Subnets**: Lambda functions run in isolated subnets with no internet access
- **No NAT Gateways**: Eliminates potential internet-based attack vectors
- **Security Groups**: Restrictive security groups controlling network traffic to VPC endpoints only

### VPC Endpoints

- **S3 Gateway Endpoint**: Direct access to S3 without internet routing
- **Interface Endpoints**: Private access to AWS services (Bedrock, Textract, CloudWatch, etc.)
- **Reduced Attack Surface**: Eliminates internet routing for all AWS service calls

### Data Protection

- **KMS Encryption**: All data encrypted at rest and in transit
- **Private Communication**: Service-to-service communication stays within AWS network
- **Network Monitoring**: VPC Flow Logs can be enabled for network monitoring

## Cost Considerations

### VPC Endpoint Costs

- **Interface Endpoints**: ~$7.20/month per interface endpoint (14 endpoints = ~$100.80/month)
- **Gateway Endpoints**: S3 gateway endpoint is free
- **Data Processing**: Interface endpoint data processing charges apply

### Cost Optimization Benefits

- **No NAT Gateways**: Eliminates ~$45/month per NAT Gateway costs (saves ~$90/month for 2 AZs)
- **No Internet Data Transfer**: Eliminates NAT Gateway data processing charges
- **Reduced Attack Surface**: Lower security monitoring and incident response costs

### Cost Optimization Tips

- **Single AZ**: Use single AZ for development to reduce interface endpoint costs
- **Endpoint Policies**: Restrict VPC endpoint access to reduce data transfer costs
- **Monitor Usage**: Use CloudWatch to monitor endpoint usage and optimize

## Monitoring and Troubleshooting

### VPC-Specific Monitoring

```bash
# Check VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>"

# Monitor VPC endpoint usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/VPC-Endpoint \
  --metric-name PacketDropCount \
  --dimensions Name=VpcId,Value=<vpc-id>
```

### Common VPC Issues

#### 1. Lambda Timeout in Isolated VPC

```
Error: Task timed out after X seconds
```

**Solution**: Ensure all required VPC endpoints are configured and Lambda has access

#### 2. VPC Endpoint DNS Resolution

```
Error: Could not resolve hostname
```

**Solution**: Ensure VPC has DNS resolution and DNS hostnames enabled

#### 3. Security Group Rules

```
Error: Connection timeout
```

**Solution**: Verify security group allows outbound HTTPS (443) traffic to VPC CIDR

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Note**: This will delete all resources including the VPC, subnets, VPC endpoints, and all document processing components.

## Customization

### Custom VPC Configuration

You can modify the VPC configuration by adjusting:

- CIDR blocks for VPC and subnets
- Number of availability zones
- Additional VPC endpoints
- Security group rules

### Integration with Existing VPC

To use an existing VPC, modify the configuration to reference existing:

- VPC ID
- Subnet IDs
- Security Group IDs
- Route Table IDs

## Support

For issues specific to VPC deployment:

1. Check VPC Flow Logs for network connectivity issues
2. Verify VPC endpoints are properly configured
3. Ensure security group and NACL rules allow VPC endpoint traffic
4. Review DNS resolution settings

For general GenAI IDP Accelerator issues, refer to the main documentation.
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_genai_idp_accelerator"></a> [genai\_idp\_accelerator](#module\_genai\_idp\_accelerator) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_glue_catalog_database.reporting_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_kms_alias.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route_table.isolated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.isolated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.evaluation_baseline_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.reporting_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.working_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_notification.input_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_security_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.isolated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.bedrock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.bedrock_agent_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.bedrock_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.cloudwatch_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.step_functions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.sts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.textract](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_classification_model_id"></a> [classification\_model\_id](#input\_classification\_model\_id) | Model ID for document classification (Bedrock LLM processor only) | `string` | `null` | no |
| <a name="input_config_file_path"></a> [config\_file\_path](#input\_config\_file\_path) | Path to the configuration YAML file for document processing | `string` | `"../../sources/config_library/pattern-2/lending-package-sample/config.yaml"` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | The retention period for document tracking data in days | `number` | `365` | no |
| <a name="input_enable_assessment"></a> [enable\_assessment](#input\_enable\_assessment) | Enable assessment functionality | `bool` | `true` | no |
| <a name="input_enable_evaluation"></a> [enable\_evaluation](#input\_enable\_evaluation) | Enable evaluation functionality (simplified flag) | `bool` | `false` | no |
| <a name="input_enable_reporting"></a> [enable\_reporting](#input\_enable\_reporting) | Enable reporting functionality (simplified flag) | `bool` | `false` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | Model ID for evaluation processing | `string` | `null` | no |
| <a name="input_extraction_model_id"></a> [extraction\_model\_id](#input\_extraction\_model\_id) | Model ID for information extraction (Bedrock LLM processor only) | `string` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for the document processing components | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by the document processing components in days | `number` | `7` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_summarization_enabled"></a> [summarization\_enabled](#input\_summarization\_enabled) | Enable document summarization for Bedrock LLM processor | `bool` | `true` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Model ID for document summarization | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Existing VPC configuration. If provided, will use existing VPC instead of creating new one. All properties must be provided together. | <pre>object({<br/>    vpc_id                 = string<br/>    vpc_subnet_ids         = list(string)<br/>    vpc_security_group_ids = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC (only used when creating new VPC) | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configuration_table_arn"></a> [configuration\_table\_arn](#output\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings |
| <a name="output_encryption_key"></a> [encryption\_key](#output\_encryption\_key) | KMS key for encryption |
| <a name="output_input_bucket"></a> [input\_bucket](#output\_input\_bucket) | S3 bucket for input documents |
| <a name="output_isolated_subnet_ids"></a> [isolated\_subnet\_ids](#output\_isolated\_subnet\_ids) | IDs of the isolated subnets (no internet access) |
| <a name="output_lambda_security_group_id"></a> [lambda\_security\_group\_id](#output\_lambda\_security\_group\_id) | ID of the security group for Lambda functions |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix used for all resources |
| <a name="output_output_bucket"></a> [output\_bucket](#output\_output\_bucket) | S3 bucket for processed output documents |
| <a name="output_processor_type"></a> [processor\_type](#output\_processor\_type) | Type of document processor used |
| <a name="output_queue_processor_arn"></a> [queue\_processor\_arn](#output\_queue\_processor\_arn) | ARN of the Lambda function that processes documents from the queue |
| <a name="output_queue_sender_arn"></a> [queue\_sender\_arn](#output\_queue\_sender\_arn) | ARN of the Lambda function that sends documents to the processing queue |
| <a name="output_step_function_arn"></a> [step\_function\_arn](#output\_step\_function\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC |
| <a name="output_vpc_endpoints_security_group_id"></a> [vpc\_endpoints\_security\_group\_id](#output\_vpc\_endpoints\_security\_group\_id) | ID of the security group for VPC endpoints |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
| <a name="output_working_bucket"></a> [working\_bucket](#output\_working\_bucket) | S3 bucket for working files |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
