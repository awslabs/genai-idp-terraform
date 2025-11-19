# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "queue_processor" {
  description = "The Lambda function that processes documents from the queue"
  value = {
    function_name = aws_lambda_function.queue_processor.function_name
    function_arn  = aws_lambda_function.queue_processor.arn
  }
}

output "evaluation_function" {
  description = "The Lambda function that evaluates document extraction results (if enabled)"
  value = var.evaluation_options != null ? {
    function_name = aws_lambda_function.evaluation_function[0].function_name
    function_arn  = aws_lambda_function.evaluation_function[0].arn
  } : null
}

output "s3_event_rule" {
  description = "The EventBridge rule for S3 events"
  value = {
    rule_name = aws_cloudwatch_event_rule.s3_event_rule.name
    rule_arn  = aws_cloudwatch_event_rule.s3_event_rule.arn
  }
}

output "workflow_state_change_rule" {
  description = "The EventBridge rule for Step Functions state changes"
  value = {
    rule_name = aws_cloudwatch_event_rule.workflow_state_change_rule.name
    rule_arn  = aws_cloudwatch_event_rule.workflow_state_change_rule.arn
  }
}

output "evaluation_rule" {
  description = "The EventBridge rule for evaluation function (if enabled)"
  value = var.evaluation_options != null ? {
    rule_name = aws_cloudwatch_event_rule.evaluation_function_rule[0].name
    rule_arn  = aws_cloudwatch_event_rule.evaluation_function_rule[0].arn
  } : null
}
