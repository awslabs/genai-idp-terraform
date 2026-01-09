# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Bedrock LLM Processor Example with Web UI and VPC
 *
 * This example demonstrates how to use the Bedrock LLM processor from the GenAI IDP Accelerator
 * with the integrated Web UI deployed in a VPC. It creates all the necessary resources including 
 * VPC, S3 buckets, KMS key, and uses the top-level module to deploy the complete solution with 
 * the Bedrock LLM processor running in private subnets.
 */

provider "aws" {
  region = var.region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values
locals {
  name_prefix = "${var.prefix}-${random_string.suffix.result}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  # VPC configuration - use existing or create new
  create_vpc_resources   = var.vpc == null
  vpc_id                 = var.vpc != null ? var.vpc.vpc_id : aws_vpc.main[0].id
  vpc_subnet_ids         = var.vpc != null ? var.vpc.vpc_subnet_ids : aws_subnet.isolated[*].id
  vpc_security_group_ids = var.vpc != null ? var.vpc.vpc_security_group_ids : [aws_security_group.lambda[0].id]
}

#
# VPC Resources
#

# VPC
resource "aws_vpc" "main" {
  count = local.create_vpc_resources ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# No Internet Gateway - fully isolated network

# Isolated Subnets (no internet access)
resource "aws_subnet" "isolated" {
  count = local.create_vpc_resources ? length(local.azs) : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-isolated-${local.azs[count.index]}"
    Type = "Isolated"
  })
}

# No NAT Gateways or EIPs needed for isolated network

# Route Table for Isolated Subnets (no internet routes)
resource "aws_route_table" "isolated" {
  count = local.create_vpc_resources ? length(local.azs) : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-isolated-rt-${local.azs[count.index]}"
  })
}

# Route Table Associations for Isolated Subnets
resource "aws_route_table_association" "isolated" {
  count = local.create_vpc_resources ? length(local.azs) : 0

  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated[count.index].id
}

# Security Group for Lambda Functions
resource "aws_security_group" "lambda" {
  count = local.create_vpc_resources ? 1 : 0

  name_prefix = "${local.name_prefix}-lambda-"
  vpc_id      = aws_vpc.main[0].id
  description = "Security group for Lambda functions in isolated VPC"

  # Egress to VPC endpoints (Interface endpoints)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to Interface VPC endpoints"
  }

  # Egress for Gateway endpoints (S3, DynamoDB) - these use AWS service IPs
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services via Gateway endpoints"
  }

  # DNS resolution (required for all AWS service calls)
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "DNS resolution within VPC"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "DNS resolution within VPC (TCP)"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-lambda-sg"
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = local.create_vpc_resources ? 1 : 0

  name_prefix = "${local.name_prefix}-vpc-endpoints-"
  vpc_id      = aws_vpc.main[0].id
  description = "Security group for VPC endpoints"

  # Ingress from Lambda functions and VPC CIDR
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC resources"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  })
}

# VPC Endpoints for AWS services (based on CDK sample requirements)

# Gateway Endpoints (free)
resource "aws_vpc_endpoint" "s3" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.isolated[*].id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.isolated[*].id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-dynamodb-endpoint"
  })
}

# Interface Endpoints (required for isolated network)
resource "aws_vpc_endpoint" "ssm" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cloudwatch-logs-endpoint"
  })
}

resource "aws_vpc_endpoint" "cloudwatch_monitoring" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cloudwatch-monitoring-endpoint"
  })
}

resource "aws_vpc_endpoint" "kms" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-kms-endpoint"
  })
}

resource "aws_vpc_endpoint" "bedrock" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.bedrock"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bedrock-endpoint"
  })
}

resource "aws_vpc_endpoint" "bedrock_runtime" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bedrock-runtime-endpoint"
  })
}

resource "aws_vpc_endpoint" "bedrock_agent_runtime" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.bedrock-agent-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bedrock-agent-runtime-endpoint"
  })
}

resource "aws_vpc_endpoint" "sts" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-sts-endpoint"
  })
}

resource "aws_vpc_endpoint" "codebuild" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.codebuild"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-codebuild-endpoint"
  })
}

resource "aws_vpc_endpoint" "eventbridge" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.events"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eventbridge-endpoint"
  })
}

resource "aws_vpc_endpoint" "lambda" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-lambda-endpoint"
  })
}

resource "aws_vpc_endpoint" "sqs" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-sqs-endpoint"
  })
}

resource "aws_vpc_endpoint" "step_functions" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.states"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-step-functions-endpoint"
  })
}

resource "aws_vpc_endpoint" "textract" {
  count = local.create_vpc_resources ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.textract"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = local.create_vpc_resources ? [aws_security_group.vpc_endpoints[0].id] : local.vpc_security_group_ids
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-textract-endpoint"
  })
}

# Create KMS key for encryption
resource "aws_kms_key" "encryption_key" {
  description             = "KMS key for IDP Processing Environment"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.id}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "encryption_key" {
  name          = "alias/idp-bedrock-llm-vpc-${random_string.suffix.result}"
  target_key_id = aws_kms_key.encryption_key.key_id
}

# Create S3 buckets for document processing
resource "aws_s3_bucket" "input_bucket" {
  bucket        = "${var.prefix}-input-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "output_bucket" {
  bucket        = "${var.prefix}-output-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "working_bucket" {
  bucket        = "${var.prefix}-working-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

# Optional buckets (created conditionally)

resource "aws_s3_bucket" "evaluation_baseline_bucket" {
  count         = var.enable_evaluation ? 1 : 0
  bucket        = "${var.prefix}-evaluation-baseline-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "reporting_bucket" {
  count         = var.enable_reporting ? 1 : 0
  bucket        = "${var.prefix}-reporting-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

# Optional: Create Glue database for reporting if reporting is enabled
resource "aws_glue_catalog_database" "reporting_database" {
  count       = var.enable_reporting ? 1 : 0
  name        = "${var.prefix}-reporting-database-${random_string.suffix.result}"
  description = "Database containing tables for evaluation metrics and document processing analytics"
  tags        = var.tags
}

# Enable EventBridge notifications on input bucket (required for processor to work)
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket      = aws_s3_bucket.input_bucket.id
  eventbridge = true
}

# Read configuration from config library (pattern-2 for Bedrock LLM processor)
locals {
  config_file_path = var.config_file_path
  config_yaml      = file(local.config_file_path)
  config           = yamldecode(local.config_yaml)

  # Backward compatibility: merge old individual variables with new api structure
  # New api variable takes precedence when both are provided
  api_config = var.api.enabled || var.discovery != null || var.chat_with_document != null || var.process_changes != null ? {
    enabled = var.api.enabled || var.discovery != null || var.chat_with_document != null || var.process_changes != null
    
    agent_analytics = var.api.agent_analytics
    
    discovery = var.api.enabled ? var.api.discovery : (
      var.discovery != null ? var.discovery : { enabled = false }
    )
    
    chat_with_document = var.api.enabled ? var.api.chat_with_document : (
      var.chat_with_document != null ? var.chat_with_document : { enabled = false }
    )
    
    process_changes = var.api.enabled ? var.api.process_changes : (
      var.process_changes != null ? var.process_changes : { enabled = false }
    )
    
    knowledge_base = var.api.knowledge_base
  } : {
    enabled = false
    agent_analytics = { enabled = false }
    discovery = { enabled = false }
    chat_with_document = { enabled = false }
    process_changes = { enabled = false }
    knowledge_base = { enabled = false }
  }
}

# Deploy the GenAI IDP Accelerator with Bedrock LLM processor
module "genai_idp_accelerator" {
  source = "../.."

  # Processor configuration
  bedrock_llm_processor = {
    classification_model_id = var.classification_model_id
    extraction_model_id     = var.extraction_model_id
    summarization = {
      enabled  = var.summarization_enabled
      model_id = var.summarization_model_id
    }
    config            = local.config
  }

  # Resource ARNs
  input_bucket_arn   = aws_s3_bucket.input_bucket.arn
  output_bucket_arn  = aws_s3_bucket.output_bucket.arn
  working_bucket_arn = aws_s3_bucket.working_bucket.arn
  encryption_key_arn = aws_kms_key.encryption_key.arn

  # VPC Configuration
  vpc_subnet_ids         = local.vpc_subnet_ids
  vpc_security_group_ids = local.vpc_security_group_ids

  # Evaluation configuration
  evaluation = var.enable_evaluation ? {
    enabled             = true
    model_id            = var.evaluation_model_id != null ? var.evaluation_model_id : "us.anthropic.claude-3-haiku-20240307-v1:0"
    baseline_bucket_arn = aws_s3_bucket.evaluation_baseline_bucket[0].arn
  } : { enabled = false }

  # Reporting configuration
  reporting = var.enable_reporting ? {
    enabled       = true
    bucket_arn    = aws_s3_bucket.reporting_bucket[0].arn
    database_name = aws_glue_catalog_database.reporting_database[0].name
  } : { enabled = false }

  # API configuration (consolidated structure)
  api = local.api_config

  # Chat with Document configuration (backward compatibility)
  chat_with_document = local.api_config.chat_with_document

  # Process Changes configuration (backward compatibility)  
  process_changes = local.api_config.process_changes

  # Feature flags
  enable_api = local.api_config.enabled

  # Web UI configuration (disabled)
  web_ui = {
    enabled = false
  }

  # General configuration
  prefix                       = var.prefix
  log_level                    = var.log_level
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days

  tags = var.tags
}
