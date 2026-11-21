# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Apply only mocked resources so computed IAM policy inputs are known; no AWS calls.
mock_provider "archive" {}
mock_provider "null" {}
mock_provider "random" {}
mock_provider "aws" {
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:test-queue" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/test-tracker" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/test-tracker" }
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

override_resource {
  target = random_string.suffix
  values = { result = "test1234" }
}
override_resource {
  target = aws_sqs_queue.workflow_tracker_dlq
  values = { arn = "arn:aws:sqs:us-east-1:123456789012:tracker-dlq" }
}
override_module {
  target = module.lambda_layers
  outputs = {
    layer_arns = { update_configuration = "arn:aws:lambda:us-east-1:123456789012:layer:test:1" }
  }
}

variables {
  input_bucket_arn        = "arn:aws:s3:::test-input"
  output_bucket_arn       = "arn:aws:s3:::test-output"
  working_bucket_arn      = "arn:aws:s3:::test-working"
  configuration_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/test-config"
  tracking_table_arn      = "arn:aws:dynamodb:us-east-1:123456789012:table/test-tracking"
  concurrency_table_arn   = "arn:aws:dynamodb:us-east-1:123456789012:table/test-concurrency"
  idp_common_layer_arn    = "arn:aws:lambda:us-east-1:123456789012:layer:test:1"
  metric_namespace        = "TestNamespace"
}

run "existing_table_transaction_permissions" {
  command = apply

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_policy.workflow_tracker_policy.policy).Statement : statement
      if try(statement.Resource == var.concurrency_table_arn, false) &&
      statement.Effect == "Allow" &&
      toset(statement.Action) == toset(["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"])
    ]) == 1
    error_message = "WorkflowTracker must allow the transaction's PutItem marker and UpdateItem counter only on the supplied concurrency table, retaining GetItem."
  }
}

run "created_table_transaction_permissions" {
  command = apply

  variables {
    concurrency_table_arn = null
  }
  override_module {
    target = module.concurrency_table[0]
    outputs = {
      table_name = "created-concurrency"
      table_arn  = "arn:aws:dynamodb:us-east-1:123456789012:table/created-concurrency"
    }
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_policy.workflow_tracker_policy.policy).Statement : statement
      if try(statement.Resource == "arn:aws:dynamodb:us-east-1:123456789012:table/created-concurrency", false) &&
      statement.Effect == "Allow" &&
      toset(statement.Action) == toset(["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"])
    ]) == 1
    error_message = "The same transaction permissions must use the created concurrency table's ARN, not a wildcard or an unrelated table."
  }
}
