# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the BDA processor façade (task 3.4).
#
# Asserts the façade delegates the expected inputs down to the nested
# `module.engine` (unified-processor):
#   * use_bda = true  — observable because the engine creates the BDA-branch
#     Lambdas ONLY on the use_bda = true path (lambda_bda.tf:
#     count = var.use_bda ? 1 : 0). Their presence in the engine's
#     `lambda_functions` output therefore proves use_bda = true was delegated.
#   * bda_project_arn = the supplied Data Automation Project ARN — observable via
#     the façade's `data_automation_project` output, which surfaces the same ARN
#     the façade forwards to the engine as `bda_project_arn`.
#
# Offline: the aws provider is mocked, so the plan needs no credentials/network.
# The archive/time providers run for real (zip the engine Lambda sources from
# the read-only `sources/` snapshot).
#
# Validates: Requirements 2.4, 1.2, Property 1

mock_provider "aws" {
  # A real partition string is required: generated mock values fail the AWS
  # provider's ARN partition validation (^aws(-[a-z]+)*$) on policy_arn fields.
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_data "aws_region" {
    defaults = {
      id   = "us-east-1"
      name = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  # data.aws_arn.data_automation_project decomposes the supplied project ARN so
  # the façade can parse the project id (element(split("/", resource), 1)). The
  # mocked value must contain a "/" so that split succeeds at plan time.
  mock_data "aws_arn" {
    defaults = {
      resource = "data-automation-project/test-project-id"
    }
  }
}

variables {
  name                        = "test-bda"
  input_bucket_arn            = "arn:aws:s3:::test-input"
  output_bucket_arn           = "arn:aws:s3:::test-output"
  working_bucket_arn          = "arn:aws:s3:::test-working"
  configuration_table_arn     = "arn:aws:dynamodb:us-east-1:123456789012:table/test-config"
  tracking_table_arn          = "arn:aws:dynamodb:us-east-1:123456789012:table/test-tracking"
  concurrency_table_arn       = "arn:aws:dynamodb:us-east-1:123456789012:table/test-concurrency"
  metric_namespace            = "TestNamespace"
  log_level                   = "INFO"
  idp_common_layer_arn        = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
  base_layer_arn              = "arn:aws:lambda:us-east-1:123456789012:layer:base:1"
  data_automation_project_arn = "arn:aws:bedrock:us-east-1:123456789012:data-automation-project/test-project-id"
  config = {
    classification = { model = "us.amazon.nova-lite-v1:0" }
    extraction     = { model = "us.amazon.nova-lite-v1:0" }
  }
}

run "bda_facade_delegates_use_bda_true_and_project_arn" {
  command = plan

  # bda_project_arn delegation: the façade forwards the supplied project ARN to
  # the engine and re-exposes it.
  assert {
    condition     = output.data_automation_project.arn == var.data_automation_project_arn
    error_message = "BDA façade must forward the supplied Data Automation Project ARN to the engine (bda_project_arn)."
  }

  # use_bda = true is observable via the engine's BDA-branch Lambdas, which only
  # exist on the use_bda = true path.
  assert {
    condition     = output.lambda_functions.bda_invoke != null
    error_message = "Engine BDA invoke Lambda must be present (use_bda = true delegated by the BDA façade)."
  }
  assert {
    condition     = output.lambda_functions.bda_process_results != null
    error_message = "Engine BDA process-results Lambda must be present (use_bda = true)."
  }
  assert {
    condition     = output.lambda_functions.bda_completion != null
    error_message = "Engine BDA completion Lambda must be present (use_bda = true)."
  }
}
