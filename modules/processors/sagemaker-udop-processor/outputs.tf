# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs for SageMaker UDOP Processor

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.document_processing.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.document_processing.name
}

output "lambda_functions" {
  description = "Information about the Lambda functions"
  value = {
    ocr_function = {
      function_name = aws_lambda_function.ocr_function.function_name
      function_arn  = aws_lambda_function.ocr_function.arn
    }
    classification_function = {
      function_name = aws_lambda_function.classification_function.function_name
      function_arn  = aws_lambda_function.classification_function.arn
    }
    extraction_function = {
      function_name = aws_lambda_function.extraction_function.function_name
      function_arn  = aws_lambda_function.extraction_function.arn
    }
    process_results_function = {
      function_name = aws_lambda_function.process_results_function.function_name
      function_arn  = aws_lambda_function.process_results_function.arn
    }
    summarization_function = {
      function_name = aws_lambda_function.summarization_function.function_name
      function_arn  = aws_lambda_function.summarization_function.arn
    }
  }
}

output "iam_roles" {
  description = "Information about the IAM roles"
  value = {
    step_functions_role = {
      role_name = aws_iam_role.step_functions_role.name
      role_arn  = aws_iam_role.step_functions_role.arn
    }
    ocr_function_role = {
      role_name = aws_iam_role.ocr_function_role.name
      role_arn  = aws_iam_role.ocr_function_role.arn
    }
    classification_function_role = {
      role_name = aws_iam_role.classification_function_role.name
      role_arn  = aws_iam_role.classification_function_role.arn
    }
    extraction_function_role = {
      role_name = aws_iam_role.extraction_function_role.name
      role_arn  = aws_iam_role.extraction_function_role.arn
    }
    process_results_function_role = {
      role_name = aws_iam_role.process_results_function_role.name
      role_arn  = aws_iam_role.process_results_function_role.arn
    }
    summarization_function_role = {
      role_name = aws_iam_role.summarization_function_role.name
      role_arn  = aws_iam_role.summarization_function_role.arn
    }
  }
}

output "max_processing_concurrency" {
  description = "Maximum number of concurrent document processing workflows"
  value       = var.max_processing_concurrency
}

output "cloudwatch_log_groups" {
  description = "Information about the CloudWatch log groups"
  value = {
    step_functions_logs = {
      log_group_name = aws_cloudwatch_log_group.step_functions_logs.name
      log_group_arn  = aws_cloudwatch_log_group.step_functions_logs.arn
    }
    ocr_function_logs = {
      log_group_name = aws_cloudwatch_log_group.ocr_function_logs.name
      log_group_arn  = aws_cloudwatch_log_group.ocr_function_logs.arn
    }
    classification_function_logs = {
      log_group_name = aws_cloudwatch_log_group.classification_function_logs.name
      log_group_arn  = aws_cloudwatch_log_group.classification_function_logs.arn
    }
    extraction_function_logs = {
      log_group_name = aws_cloudwatch_log_group.extraction_function_logs.name
      log_group_arn  = aws_cloudwatch_log_group.extraction_function_logs.arn
    }
    process_results_function_logs = {
      log_group_name = aws_cloudwatch_log_group.process_results_function_logs.name
      log_group_arn  = aws_cloudwatch_log_group.process_results_function_logs.arn
    }
    summarization_function_logs = {
      log_group_name = aws_cloudwatch_log_group.summarization_function_logs.name
      log_group_arn  = aws_cloudwatch_log_group.summarization_function_logs.arn
    }
  }
}

output "configuration" {
  description = "Configuration information"
  value = {
    final_config = local.config_with_overrides
  }
}

output "evaluation_function_arn" {
  description = "ARN of the evaluation Lambda function"
  value       = aws_lambda_function.evaluation_function.arn
}
