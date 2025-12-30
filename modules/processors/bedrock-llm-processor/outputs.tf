# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "state_machine_arn" {
  description = "ARN of the Step Functions state machine for document processing"
  value       = aws_sfn_state_machine.document_processing.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine for document processing"
  value       = aws_sfn_state_machine.document_processing.name
}

output "max_processing_concurrency" {
  description = "Maximum number of concurrent document processing tasks"
  value       = var.max_processing_concurrency
}

output "configuration" {
  description = "Configuration for the Bedrock LLM processor"
  value       = local.config_with_overrides
}

output "classification_model" {
  description = "The classification model being used (from variable override or config.yaml)"
  value       = local.config_with_overrides.classification.model
}

output "extraction_model" {
  description = "The extraction model being used (from variable override or config.yaml)"
  value       = local.config_with_overrides.extraction.model
}

output "summarization_model" {
  description = "The summarization model being used (from variable override or config.yaml)"
  value       = var.is_summarization_enabled ? local.config_with_overrides.summarization.model : null
}

output "evaluation_model" {
  description = "The evaluation model being used (from variable override or config.yaml)"
  value       = var.evaluation_enabled ? local.config_with_overrides.evaluation.llm_method.model : null
}

output "schema_definition" {
  description = "The JSON Schema definition for Bedrock LLM processor configuration"
  value       = jsondecode(file("${path.module}/schema.json"))
}

output "lambda_functions" {
  description = "Lambda functions used by the Bedrock LLM processor"
  value = {
    ocr = {
      name = aws_lambda_function.ocr.function_name
      arn  = aws_lambda_function.ocr.arn
    }
    classification = {
      name = aws_lambda_function.classification.function_name
      arn  = aws_lambda_function.classification.arn
    }
    extraction = {
      name = aws_lambda_function.extraction.function_name
      arn  = aws_lambda_function.extraction.arn
    }
    process_results = {
      name = aws_lambda_function.process_results.function_name
      arn  = aws_lambda_function.process_results.arn
    }
    summarization = var.is_summarization_enabled ? {
      name = aws_lambda_function.summarization[0].function_name
      arn  = aws_lambda_function.summarization[0].arn
    } : null
    hitl_wait = var.enable_hitl ? {
      name = aws_lambda_function.hitl_wait[0].function_name
      arn  = aws_lambda_function.hitl_wait[0].arn
    } : null
    hitl_status_update = var.enable_hitl ? {
      name = aws_lambda_function.hitl_status_update[0].function_name
      arn  = aws_lambda_function.hitl_status_update[0].arn
    } : null
  }
}

output "classification_max_workers" {
  description = "The maximum number of concurrent workers for document classification"
  value       = var.classification_max_workers
}

output "ocr_max_workers" {
  description = "The maximum number of concurrent workers for OCR processing"
  value       = var.ocr_max_workers
}

output "evaluation_enabled" {
  description = "Whether extraction results evaluation is enabled"
  value       = var.evaluation_enabled
}

output "is_summarization_enabled" {
  description = "Whether document summarization is enabled"
  value       = var.is_summarization_enabled
}
# Debug output for model permissions
output "model_permission_debug" {
  description = "Debug information for model permissions"
  value = {
    partition  = data.aws_partition.current.partition
    account_id = data.aws_caller_identity.current.account_id
    models = {
      for model_name, model_config in local.bedrock_model_permissions : model_name => model_config != null ? {
        type          = model_config.is_cross_region ? "cross_region_inference_profile" : "foundation_model"
        is_arn        = model_config.is_arn
        base_model_id = model_config.base_model_id
        foundation_permissions = {
          actions   = model_config.foundation_statement.actions
          resources = model_config.foundation_statement.resources
        }
        inference_profile_permissions = model_config.inference_profile_statement != null ? {
          actions   = model_config.inference_profile_statement.actions
          resources = model_config.inference_profile_statement.resources
        } : null
      } : null
    }
  }
}
