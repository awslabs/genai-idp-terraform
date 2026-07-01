# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "input_bucket" {
  description = "S3 bucket for input documents. Upload here with config-version metadata to route."
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

output "config_versions" {
  description = "Configuration versions seeded on this deployment and their routing branch."
  value = {
    default                = "Bedrock-LLM - upload with config-version=default"
    (var.bda_version_name) = "BDA - upload with config-version=${var.bda_version_name}"
  }
}

output "bda_config_version" {
  description = "Name of the BDA-linked configuration version. Tag an upload with config-version=<this> to route it through the BDA branch."
  value       = var.bda_version_name
}

output "bda_project_arn" {
  description = "BDA project ARN linked to the BDA configuration version (empty if unlinked)."
  # Effective ARN: the project this example created (create_bda_project = true)
  # or the existing one passed via var.bda_project_arn. Using var.bda_project_arn
  # directly reported "" whenever the example created the project itself.
  value = local.effective_bda_project_arn
}

output "knowledge_base_id" {
  description = "ID of the optional Bedrock Knowledge Base (null when create_knowledge_base = false)."
  value       = local.knowledge_base_enabled ? aws_bedrockagent_knowledge_base.knowledge_base[0].id : null
}

output "knowledge_base_arn" {
  description = "ARN of the optional Bedrock Knowledge Base (null when create_knowledge_base = false)."
  value       = local.knowledge_base_enabled ? aws_bedrockagent_knowledge_base.knowledge_base[0].arn : null
}

output "web_ui_url" {
  description = "Web UI URL (if enabled)"
  value       = var.web_ui.enabled ? module.genai_idp_accelerator.web_ui.url : null
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
  description = "ARN of the single Step Functions state machine that routes both branches"
  value       = module.genai_idp_accelerator.processor.state_machine_arn
}

output "configuration_table_arn" {
  description = "ARN of the DynamoDB table that stores configuration versions (incl. BdaProjectArn)"
  value       = module.genai_idp_accelerator.processing_environment.configuration_table_arn
}
