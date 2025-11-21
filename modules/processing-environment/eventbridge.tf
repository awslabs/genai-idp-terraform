# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# # EventBridge rule for S3 events
# resource "aws_cloudwatch_event_rule" "s3_event_rule" {
#   name        = "idp-s3-event-rule-${random_string.suffix.result}"
#   description = "Rule for S3 object created events"

#   event_pattern = jsonencode({
#     source      = ["aws.s3"]
#     "detail-type" = ["Object Created"]
#     detail = {
#       bucket = {
#         name = [local.input_bucket_name]
#       }
#     }
#   })

#   tags = var.tags
# }

# # EventBridge target for S3 events
# resource "aws_cloudwatch_event_target" "s3_event_target" {
#   rule      = aws_cloudwatch_event_rule.s3_event_rule.name
#   target_id = "SendToQueueSender"
#   arn       = aws_lambda_function.queue_sender.arn
# }

# # Lambda permission for EventBridge to invoke QueueSender
# resource "aws_lambda_permission" "allow_eventbridge_to_invoke_queue_sender" {
#   statement_id  = "AllowExecutionFromEventBridge"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.queue_sender.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.s3_event_rule.arn
# }
