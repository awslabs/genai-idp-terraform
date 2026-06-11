# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Public outputs for the BDA processor façade. Processing outputs are re-exposed
# from the shared engine (`module.engine`); the Data Automation Project surface
# is the façade's own pattern-specific concern.

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine for document processing"
  value       = module.engine.state_machine_arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine for document processing"
  value       = module.engine.state_machine_name
}

output "max_processing_concurrency" {
  description = "Maximum number of concurrent document processing tasks"
  value       = module.engine.max_processing_concurrency
}

output "data_automation_project" {
  description = "Information about the Bedrock Data Automation Project"
  value = {
    arn        = var.data_automation_project_arn
    project_id = local.project_id
  }
}

output "data_automation_project_arn" {
  description = "ARN of the BDA Data Automation Project (consumed by processing-environment-api for BDA sync resolver)"
  value       = var.data_automation_project_arn
}

output "configuration" {
  description = "Effective configuration for the BDA processor (from the shared engine)"
  value       = module.engine.configuration
}

output "evaluation_model" {
  description = "The model used for evaluating extraction results"
  value       = module.engine.evaluation_model
}

output "summarization_model" {
  description = "The model used for document summarization"
  value       = module.engine.summarization_model
}

output "lambda_functions" {
  description = "Lambda functions used by the BDA processor (from the shared engine)"
  value       = module.engine.lambda_functions
}

output "evaluation_function_arn" {
  description = "ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled)"
  value       = module.engine.evaluation_function_arn
}
