# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Public outputs for the SageMaker-UDOP processor façade.
#
# Document-processing outputs are re-exposed from the shared engine
# (module.engine). Classification runs through idp_common's native SageMaker
# backend against the consumer-supplied endpoint.

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

output "configuration" {
  description = "Configuration for the SageMaker-UDOP processor"
  value       = module.engine.configuration
}

output "classification_model" {
  description = "The classification model being used (classification runs via the native SageMaker backend)"
  value       = module.engine.classification_model
}

output "extraction_model" {
  description = "The extraction model being used (from variable override or config.yaml)"
  value       = module.engine.extraction_model
}

output "summarization_model" {
  description = "The summarization model being used (from variable override or config.yaml)"
  value       = module.engine.summarization_model
}

output "evaluation_model" {
  description = "The evaluation model being used (from variable override or config.yaml)"
  value       = module.engine.evaluation_model
}

output "schema_definition" {
  description = "The JSON Schema definition for the processor configuration"
  value       = module.engine.schema_definition
}

output "lambda_functions" {
  description = "Lambda functions used by the processor (engine functions)"
  value       = module.engine.lambda_functions
}

output "classification_max_workers" {
  description = "The maximum number of concurrent workers for document classification"
  value       = module.engine.classification_max_workers
}

output "ocr_max_workers" {
  description = "The maximum number of concurrent workers for OCR processing"
  value       = module.engine.ocr_max_workers
}

output "evaluation_enabled" {
  description = "Whether extraction results evaluation is enabled"
  value       = module.engine.evaluation_enabled
}

output "is_summarization_enabled" {
  description = "Whether document summarization is enabled"
  value       = module.engine.is_summarization_enabled
}

output "evaluation_function_arn" {
  description = "ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled). Null when evaluation is disabled."
  value       = module.engine.evaluation_function_arn
}

output "build_mode" {
  description = "Active build path for the processor's container images: \"codebuild\" or \"local\"."
  value       = var.lambda_local ? "local" : "codebuild"
}
