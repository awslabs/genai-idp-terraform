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

# Routing topology exposed so terraform test can assert routing at plan time (the
# full definition string is unknown at plan because it interpolates computed ARNs).
output "state_machine_start_at" {
  description = "The StartAt state of the document-processing state machine. Always 'PreprocessingHook' (IDP v0.6): the preprocessing extension point runs before the BDA/pipeline routing decision, so it fires in both modes. Documents then route at runtime by their config version's use_bda flag."
  value       = "PreprocessingHook"
}

output "state_machine_state_names" {
  description = "The set of state names in the document-processing state machine definition (both BDA-branch and pipeline-branch states)."
  value       = keys(local.sfn_states)
}

output "state_machine_transition_targets" {
  description = "Every state name referenced as a transition target by a top-level state (Next / Choices[*].Next / Catch[*].Next / Default). Exposed for graph-closure assertions in terraform test."
  value       = local.sfn_transition_targets
}

output "max_processing_concurrency" {
  description = "Maximum number of concurrent document processing tasks"
  value       = var.max_processing_concurrency
}

output "configuration" {
  description = "Configuration for the unified processor engine"
  value       = local.config_with_overrides
}

output "classification_model" {
  description = "The classification model the runtime will invoke (resolved: per-step variable > config YAML > system default > model_id). This is the model the Bedrock IAM grant is scoped to."
  value       = local.bedrock_step_model_ids.classification
}

output "extraction_model" {
  description = "The extraction model the runtime will invoke (resolved: per-step variable > config YAML > system default > model_id). This is the model the Bedrock IAM grant is scoped to."
  value       = local.bedrock_step_model_ids.extraction
}

output "summarization_model" {
  description = "The summarization model the runtime will invoke (resolved: per-step variable > config YAML > system default > model_id), or null when summarization is off."
  value       = var.is_summarization_enabled ? local.bedrock_step_model_ids.summarization : null
}

output "evaluation_model" {
  description = "The evaluation model the runtime will invoke (resolved: per-step variable > config YAML > system default > model_id), or null when evaluation is off."
  value       = var.evaluation_enabled ? local.bedrock_step_model_ids.evaluation : null
}

output "schema_definition" {
  description = "The JSON Schema definition for unified processor engine configuration"
  value       = jsondecode(file("${path.module}/schema.json"))
}

output "lambda_functions" {
  description = "Lambda functions used by the unified processor engine"
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
    # Rule-validation functions, deployed and wired into the workflow only when
    # var.enable_rule_validation is set (null otherwise).
    rule_validation = var.enable_rule_validation ? {
      name = aws_lambda_function.rule_validation_function[0].function_name
      arn  = aws_lambda_function.rule_validation_function[0].arn
    } : null
    rule_validation_orchestration = var.enable_rule_validation ? {
      name = aws_lambda_function.rule_validation_orchestration_function[0].function_name
      arn  = aws_lambda_function.rule_validation_orchestration_function[0].arn
    } : null
    rule_validation_policy_classification = var.enable_rule_validation ? {
      name = aws_lambda_function.rule_validation_policy_classification_function[0].function_name
      arn  = aws_lambda_function.rule_validation_policy_classification_function[0].arn
    } : null
    # BDA branch functions, always deployed (count = 1).
    bda_invoke = {
      name = aws_lambda_function.bda_invoke[0].function_name
      arn  = aws_lambda_function.bda_invoke[0].arn
    }
    bda_process_results = {
      name = aws_lambda_function.bda_process_results[0].function_name
      arn  = aws_lambda_function.bda_process_results[0].arn
    }
    bda_completion = {
      name = aws_lambda_function.bda_completion[0].function_name
      arn  = aws_lambda_function.bda_completion[0].arn
    }
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


output "evaluation_function_arn" {
  description = "ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled). Null when evaluation is disabled."
  value       = var.evaluation_enabled && var.evaluation_baseline_bucket_arn != null ? aws_lambda_function.evaluation_function[0].arn : null
}
