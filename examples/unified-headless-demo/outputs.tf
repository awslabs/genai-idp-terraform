# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "input_bucket" {
  description = "Input bucket. Upload with config-version=default (Bedrock-LLM) or config-version=bda (BDA)."
  value       = aws_s3_bucket.input_bucket.id
}

output "state_machine_arn" {
  description = "The single Step Functions state machine routing both branches."
  value       = module.genai_idp_accelerator.processor.state_machine_arn
}

output "tracking_table_arn" {
  description = "DynamoDB tracking table (DynamoDB-only mode, no GraphQL)."
  value       = module.genai_idp_accelerator.processing_environment.tracking_table_arn
}

output "configuration_table_arn" {
  description = "DynamoDB configuration table (seeds default + bda versions)."
  value       = module.genai_idp_accelerator.processing_environment.configuration_table_arn
}

output "bda_project_arn" {
  value = local.effective_bda_project_arn
}
