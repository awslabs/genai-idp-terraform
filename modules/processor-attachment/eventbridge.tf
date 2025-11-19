# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SQS Event Source Mapping for Queue Processor
resource "aws_lambda_event_source_mapping" "queue_processor_event_source" {
  event_source_arn                   = var.document_queue_arn
  function_name                      = aws_lambda_function.queue_processor.arn
  batch_size                         = 50
  maximum_batching_window_in_seconds = 1
  function_response_types            = ["ReportBatchItemFailures"]

  depends_on = [
    aws_iam_role_policy_attachment.queue_processor_custom_policy
  ]
}

# EventBridge Rule for S3 Events (Object Created)
resource "aws_cloudwatch_event_rule" "s3_event_rule" {
  name        = "${var.name}-s3-event-rule-${random_string.suffix.result}"
  description = "Rule for S3 Object Created events"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = merge({
      bucket = {
        name = [local.input_bucket_name]
      }
      }, var.s3_prefix != null ? {
      object = {
        key = [{
          prefix = var.s3_prefix
        }]
      }
    } : {})
  })

  tags = var.tags
}

# EventBridge Target for S3 Events -> Queue Sender
resource "aws_cloudwatch_event_target" "s3_event_target" {
  rule      = aws_cloudwatch_event_rule.s3_event_rule.name
  target_id = "SendToQueueSender"
  arn       = var.queue_sender_function_arn

  retry_policy {
    maximum_event_age_in_seconds = 7200 # 2 hours
    maximum_retry_attempts       = 3
  }
}

# Lambda permission for EventBridge to invoke Queue Sender
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_queue_sender" {
  statement_id  = "AllowExecutionFromEventBridge-${random_string.suffix.result}"
  action        = "lambda:InvokeFunction"
  function_name = var.queue_sender_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_event_rule.arn
}

# EventBridge Rule for Step Functions State Changes
resource "aws_cloudwatch_event_rule" "workflow_state_change_rule" {
  name        = "${var.name}-workflow-rule-${random_string.suffix.result}"
  description = "Rule for Step Functions state machine status changes"

  event_pattern = jsonencode({
    source        = ["aws.states"]
    "detail-type" = ["Step Functions Execution Status Change"]
    detail = {
      stateMachineArn = [var.processor.state_machine_arn]
      status          = ["FAILED", "TIMED_OUT", "ABORTED", "SUCCEEDED"]
    }
  })

  tags = var.tags
}

# EventBridge Target for Step Functions State Changes -> Workflow Tracker
resource "aws_cloudwatch_event_target" "workflow_state_change_target" {
  rule      = aws_cloudwatch_event_rule.workflow_state_change_rule.name
  target_id = "SendToWorkflowTracker"
  arn       = var.workflow_tracker_function_arn

  retry_policy {
    maximum_event_age_in_seconds = 7200 # 2 hours
    maximum_retry_attempts       = 3
  }
}

# Lambda permission for EventBridge to invoke Workflow Tracker
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_workflow_tracker" {
  statement_id  = "AllowExecutionFromEventBridge-${random_string.suffix.result}"
  action        = "lambda:InvokeFunction"
  function_name = var.workflow_tracker_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.workflow_state_change_rule.arn
}
