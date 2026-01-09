# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = local.create_vpc_resources ? aws_vpc.main[0].cidr_block : null
}

output "isolated_subnet_ids" {
  description = "IDs of the isolated subnets (no internet access)"
  value       = local.vpc_subnet_ids
}

output "lambda_security_group_id" {
  description = "ID of the security group for Lambda functions"
  value       = local.create_vpc_resources ? aws_security_group.lambda[0].id : null
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = local.create_vpc_resources ? aws_security_group.vpc_endpoints[0].id : null
}

# S3 Bucket Outputs
output "input_bucket" {
  description = "S3 bucket for input documents"
  value = {
    name = aws_s3_bucket.input_bucket.id
    arn  = aws_s3_bucket.input_bucket.arn
  }
}

output "output_bucket" {
  description = "S3 bucket for processed output documents"
  value = {
    name = aws_s3_bucket.output_bucket.id
    arn  = aws_s3_bucket.output_bucket.arn
  }
}

output "working_bucket" {
  description = "S3 bucket for working files"
  value = {
    name = aws_s3_bucket.working_bucket.id
    arn  = aws_s3_bucket.working_bucket.arn
  }
}

output "encryption_key" {
  description = "KMS key for encryption"
  value = {
    id  = aws_kms_key.encryption_key.id
    arn = aws_kms_key.encryption_key.arn
  }
}

output "name_prefix" {
  description = "Name prefix used for all resources"
  value       = module.genai_idp_accelerator.name_prefix
}

output "processor_type" {
  description = "Type of document processor used"
  value       = module.genai_idp_accelerator.processor_type
}

output "step_function_arn" {
  description = "ARN of the Step Functions state machine for document processing"
  value       = module.genai_idp_accelerator.processor.state_machine_arn
}

output "queue_processor_arn" {
  description = "ARN of the Lambda function that processes documents from the queue"
  value       = module.genai_idp_accelerator.processor.queue_processor_arn
}

output "queue_sender_arn" {
  description = "ARN of the Lambda function that sends documents to the processing queue"
  value       = module.genai_idp_accelerator.processor.queue_sender_arn
}

output "configuration_table_arn" {
  description = "ARN of the DynamoDB table that stores configuration settings"
  value       = module.genai_idp_accelerator.processing_environment.configuration_table_arn
}

# API Outputs (when API is enabled)
output "api" {
  description = "API configuration and endpoints (when enabled)"
  value       = local.api_config.enabled ? module.genai_idp_accelerator.api : null
}

output "api_graphql_url" {
  description = "GraphQL API URL (when API is enabled)"
  value       = local.api_config.enabled ? module.genai_idp_accelerator.api.graphql_url : null
}

output "api_id" {
  description = "API ID (when API is enabled)"
  value       = local.api_config.enabled ? module.genai_idp_accelerator.api.api_id : null
}
