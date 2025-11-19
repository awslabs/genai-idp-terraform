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
enable_assessment = true
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
