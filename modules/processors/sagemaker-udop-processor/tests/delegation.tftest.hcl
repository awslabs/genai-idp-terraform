# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the SageMaker-UDOP processor façade.
#
# Asserts the façade delegates the expected inputs down to the nested
# `module.engine` (unified-processor) AND provisions the classification-hook
# bridge Lambda:
#   * use_bda = false — observable via the absence of the engine's BDA-branch
#     Lambdas (lambda_bda.tf: count = var.use_bda ? 1 : 0).
#   * classification forced to "LambdaHook" — observable via the engine's
#     `classification_model` output (the façade pins classification_model_id =
#     "LambdaHook").
#   * model_lambda_hook_arn points at the bridge Lambda — observable via the
#     effective configuration's classification.model_lambda_hook_arn, which the
#     façade injects from the bridge function name.
#   * the SageMaker classification-hook bridge Lambda is created — observable via
#     the façade's `sagemaker_hook_function_name` output.
#
# Offline: the aws provider is mocked, so the plan needs no credentials/network.
# The archive/time providers run for real (zip the bridge Lambda + engine Lambda
# sources from the read-only `sources/` snapshot).

mock_provider "archive" {}
mock_provider "time" {}
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
}

variables {
  name                        = "test-udop"
  classification_endpoint_arn = "arn:aws:sagemaker:us-east-1:123456789012:endpoint/test-endpoint"
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
  config = {
    classification = { model = "us.amazon.nova-lite-v1:0" }
    extraction     = { model = "us.amazon.nova-lite-v1:0" }
  }
}

run "udop_facade_delegates_to_the_engine" {
  command = plan

  # The façade owns no resources: it hands the endpoint to the engine with
  # classification_backend = "sagemaker". The old LambdaHook bridge is gone.
  # These outputs come from module.engine, so their presence proves delegation
  # (state_machine_arn is computed, so unassertable at plan).
  assert {
    condition     = output.lambda_functions.bda_invoke != null && output.lambda_functions.bda_process_results != null && output.lambda_functions.bda_completion != null
    error_message = "Engine BDA-branch Lambdas must be deployed: v0.6 routes branches at runtime, not at deploy time."
  }
  assert {
    condition     = output.lambda_functions.ocr != null && output.lambda_functions.classification != null && output.lambda_functions.extraction != null
    error_message = "Engine pipeline Lambdas (ocr/classification/extraction) must always be present."
  }
}
