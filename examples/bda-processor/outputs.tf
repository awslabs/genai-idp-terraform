# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
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

output "api" {
  description = "GraphQL API details"
  value       = var.api.enabled ? module.genai_idp_accelerator.api : null
}

output "web_ui" {
  description = "Web UI details"
  value       = var.web_ui.enabled ? module.genai_idp_accelerator.web_ui : null
}

output "web_ui_url" {
  description = "Web UI URL (if enabled)"
  value       = var.web_ui.enabled ? module.genai_idp_accelerator.web_ui.url : null
}

output "user_identity" {
  description = "User identity details"
  value       = module.genai_idp_accelerator.user_identity
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

output "workflow_tracker_arn" {
  description = "ARN of the Lambda function that tracks workflow execution status"
  value       = module.genai_idp_accelerator.processing_environment.workflow_tracker_arn
}

output "evaluation_function_arn" {
  description = "ARN of the Lambda function that evaluates document extraction results (if enabled)"
  value       = module.genai_idp_accelerator.processor.evaluation_function_arn
}

# Knowledge Base Outputs
output "knowledge_base" {
  description = "Knowledge base details (if enabled)"
  value = local.knowledge_base_enabled ? {
    id                        = aws_bedrockagent_knowledge_base.knowledge_base[0].id
    arn                       = aws_bedrockagent_knowledge_base.knowledge_base[0].arn
    data_source_id            = aws_bedrockagent_data_source.knowledge_base_data_source[0].data_source_id
    opensearch_collection_arn = aws_opensearchserverless_collection.knowledge_base_collection[0].arn
    opensearch_endpoint       = aws_opensearchserverless_collection.knowledge_base_collection[0].collection_endpoint
    ingestion_function_arn    = aws_lambda_function.knowledge_base_ingestion[0].arn
  } : null
}

output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base (if enabled)"
  value       = local.knowledge_base_enabled ? aws_bedrockagent_knowledge_base.knowledge_base[0].id : null
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base (if enabled)"
  value       = local.knowledge_base_enabled ? aws_bedrockagent_knowledge_base.knowledge_base[0].arn : null
}
