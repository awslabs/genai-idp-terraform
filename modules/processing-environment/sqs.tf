# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SQS Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "document_queue_dlq" {
  name                       = "idp-document-queue-dlq-${random_string.suffix.result}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days
  kms_master_key_id          = local.key != null ? local.key.key_id : null

  tags = var.tags
}

# SQS Queue
resource "aws_sqs_queue" "document_queue" {
  name                       = "idp-document-queue-${random_string.suffix.result}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400 # 1 day
  kms_master_key_id          = local.key != null ? local.key.key_id : null

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.document_queue_dlq.arn
    maxReceiveCount     = 1000
  })

  tags = var.tags
}

# SQS Dead Letter Queue (DLQ) for QueueSender
resource "aws_sqs_queue" "queue_sender_dlq" {
  name                       = "idp-queue-sender-dlq-${random_string.suffix.result}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days
  kms_master_key_id          = local.key != null ? local.key.key_id : null

  tags = var.tags
}

# SQS Dead Letter Queue (DLQ) for WorkflowTracker
resource "aws_sqs_queue" "workflow_tracker_dlq" {
  name                       = "idp-workflow-tracker-dlq-${random_string.suffix.result}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days
  kms_master_key_id          = local.key != null ? local.key.key_id : null

  tags = var.tags
}
