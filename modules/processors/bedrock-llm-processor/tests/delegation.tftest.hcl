# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the Bedrock-LLM processor façade (task 3.4).
#
# Asserts the façade delegates the expected inputs down to the nested
# `module.engine` (unified-processor):
#   * use_bda = false — observable because the engine creates NO BDA-branch
#     Lambdas on the use_bda = false path (lambda_bda.tf:
#     count = var.use_bda ? 1 : 0). Their absence from the engine's
#     `lambda_functions` output proves use_bda = false was delegated, while the
#     pipeline Lambdas (ocr/classification/extraction) remain present.
#   * bda_project_arn = null — the Bedrock-LLM façade hardcodes this to null.
#
# Offline: the aws provider is mocked, so the plan needs no credentials/network.
# The archive provider runs for real (zip the engine Lambda sources from the
# read-only `sources/` snapshot).
#
# Validates: Requirements 2.5, Property 1

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
  name                    = "test-llm"
  input_bucket_arn        = "arn:aws:s3:::test-input"
  output_bucket_arn       = "arn:aws:s3:::test-output"
  working_bucket_arn      = "arn:aws:s3:::test-working"
  configuration_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/test-config"
  tracking_table_arn      = "arn:aws:dynamodb:us-east-1:123456789012:table/test-tracking"
  concurrency_table_arn   = "arn:aws:dynamodb:us-east-1:123456789012:table/test-concurrency"
  metric_namespace        = "TestNamespace"
  log_level               = "INFO"
  idp_common_layer_arn    = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
  base_layer_arn          = "arn:aws:lambda:us-east-1:123456789012:layer:base:1"
  config = {
    classification = { model = "us.amazon.nova-lite-v1:0" }
    extraction     = { model = "us.amazon.nova-lite-v1:0" }
  }
}

run "bedrock_llm_facade_delegates_use_bda_false" {
  command = plan

  # use_bda = false: the engine omits all BDA-branch Lambdas.
  assert {
    condition     = output.lambda_functions.bda_invoke == null
    error_message = "Engine BDA invoke Lambda must be absent on the Bedrock-LLM façade (use_bda = false)."
  }
  assert {
    condition     = output.lambda_functions.bda_process_results == null
    error_message = "Engine BDA process-results Lambda must be absent (use_bda = false)."
  }
  assert {
    condition     = output.lambda_functions.bda_completion == null
    error_message = "Engine BDA completion Lambda must be absent (use_bda = false)."
  }

  # The pipeline branch is always present regardless of use_bda.
  assert {
    condition     = output.lambda_functions.ocr != null && output.lambda_functions.classification != null && output.lambda_functions.extraction != null
    error_message = "Engine pipeline Lambdas (ocr/classification/extraction) must always be present."
  }

  # classification.model is NOT forced to the LambdaHook seam — contrast with
  # the SageMaker-UDOP façade which pins classification_model_id = "LambdaHook".
  # (The engine resolves classification.model to coalesce(classification_model_id,
  # model_id); the Bedrock-LLM façade leaves both unset, so it falls back to the
  # engine's default model_id rather than "LambdaHook".)
  assert {
    condition     = output.classification_model != "LambdaHook"
    error_message = "Bedrock-LLM façade must NOT force classification through the LambdaHook bridge."
  }
}
