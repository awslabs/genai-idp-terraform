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

output "data_automation_project" {
  description = "Information about the Bedrock Data Automation Project"
  value = {
    arn        = var.data_automation_project_arn
    project_id = local.project_id
  }
}

output "configuration" {
  description = "Configuration for the BDA processor"
  value = {
    schema = jsondecode(file("${path.module}/schema.json"))
    config = local.config_with_overrides
  }
}

output "processor_configuration" {
  description = "Processor configuration results"
  value = {
    lambda_function_arn  = module.processor_configuration.lambda_function_arn
    lambda_function_name = module.processor_configuration.lambda_function_name
    default_seeded       = module.processor_configuration.default_seeded
    schema_seeded        = module.processor_configuration.schema_seeded
  }
}

output "evaluation_model" {
  description = "The invokable model used for evaluating extraction results"
  value       = var.evaluation_model_id
}

output "summarization_model" {
  description = "Optional invokable model used for document summarization"
  value       = var.summarization_model_id
}

output "lambda_functions" {
  description = "Lambda functions used by the BDA processor"
  value = {
    invoke_bda = {
      name = aws_lambda_function.invoke_bda.function_name
      arn  = aws_lambda_function.invoke_bda.arn
    }
    process_results = {
      name = aws_lambda_function.process_results.function_name
      arn  = aws_lambda_function.process_results.arn
    }
    summarization = {
      name = aws_lambda_function.summarization.function_name
      arn  = aws_lambda_function.summarization.arn
    }
    bda_completion = {
      name = aws_lambda_function.bda_completion.function_name
      arn  = aws_lambda_function.bda_completion.arn
    }
  }
}
