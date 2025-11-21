# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # SQS Queues
 *
 * This file defines the SQS queues used by the BDA processor.
 * Each Lambda function has its own Dead Letter Queue for error handling.
 */

# BDA Invoke function DLQ
resource "aws_sqs_queue" "invoke_bda_dlq" {
  name                       = "${var.name}-invoke-bda-dlq-${random_string.suffix.result}"
  kms_master_key_id          = local.encryption_key_id
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days

  tags = var.tags
}

# BDA Completion function DLQ
resource "aws_sqs_queue" "bda_completion_dlq" {
  name                       = "${var.name}-bda-completion-dlq-${random_string.suffix.result}"
  kms_master_key_id          = local.encryption_key_id
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days

  tags = var.tags
}

# Process Results function DLQ
resource "aws_sqs_queue" "process_results_dlq" {
  name                       = "${var.name}-process-results-dlq-${random_string.suffix.result}"
  kms_master_key_id          = local.encryption_key_id
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days

  tags = var.tags
}

# Summarization function DLQ
resource "aws_sqs_queue" "summarization_dlq" {
  name                       = "${var.name}-summarization-dlq-${random_string.suffix.result}"
  kms_master_key_id          = local.encryption_key_id
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days

  tags = var.tags
}

# Evaluation function DLQ (optional)
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_sqs_queue" "evaluation_dlq" {
#   count                      = var.evaluation_baseline_bucket != null ? 1 : 0
#   name                       = "${var.name}-evaluation-dlq-${random_string.suffix.result}"
#   kms_master_key_id          = local.encryption_key_id
#   visibility_timeout_seconds = 30
#   message_retention_seconds  = 345600 # 4 days
# 
#   tags = var.tags
# }
