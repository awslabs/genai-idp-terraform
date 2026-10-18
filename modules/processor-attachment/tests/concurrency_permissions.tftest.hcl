# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

mock_provider "archive" {}
mock_provider "null" {}
mock_provider "random" {}
mock_provider "aws" {
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/test-processor" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/test-processor" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/test-processor" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1", name = "us-east-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  name                           = "test-processor"
  input_bucket_arn               = "arn:aws:s3:::test-input"
  output_bucket_arn              = "arn:aws:s3:::test-output"
  working_bucket_arn             = "arn:aws:s3:::test-working"
  configuration_table_arn        = "arn:aws:dynamodb:us-east-1:123456789012:table/test-config"
  tracking_table_arn             = "arn:aws:dynamodb:us-east-1:123456789012:table/test-tracking"
  concurrency_table_arn          = "arn:aws:dynamodb:us-east-1:123456789012:table/test-concurrency"
  document_queue_arn             = "arn:aws:sqs:us-east-1:123456789012:documents"
  document_queue_url             = "https://sqs.us-east-1.amazonaws.com/123456789012/documents"
  queue_sender_function_name     = "queue-sender"
  queue_sender_function_arn      = "arn:aws:lambda:us-east-1:123456789012:function:queue-sender"
  workflow_tracker_function_name = "workflow-tracker"
  workflow_tracker_function_arn  = "arn:aws:lambda:us-east-1:123456789012:function:workflow-tracker"
  idp_common_layer_arn           = "arn:aws:lambda:us-east-1:123456789012:layer:test:1"
  metric_namespace               = "TestNamespace"
  log_level                      = "INFO"
  processor = {
    state_machine_arn          = "arn:aws:states:us-east-1:123456789012:stateMachine:test-processor"
    max_processing_concurrency = 100
  }
}

run "queue_reconciliation_permissions" {
  command = apply

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_policy.queue_processor_policy.policy).Statement : statement
      if statement.Resource == var.processor.state_machine_arn &&
      statement.Effect == "Allow" &&
      toset(statement.Action) == toset(["states:StartExecution", "states:ListExecutions"])
    ]) == 1
    error_message = "QueueProcessor must retain StartExecution and allow ListExecutions for counter reconciliation on only its configured state machine."
  }
  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_policy.queue_processor_policy.policy).Statement :
      statement.Resource == var.processor.state_machine_arn
      if contains(statement.Action, "states:ListExecutions")
    ])
    error_message = "ListExecutions must not be granted on wildcard resources or other state machines."
  }
}
