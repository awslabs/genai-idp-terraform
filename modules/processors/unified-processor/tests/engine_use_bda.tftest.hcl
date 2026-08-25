# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the shared unified-processor engine: BDA vs
# step-by-step pipeline routing.
#
# The engine deploys BOTH branches unconditionally and routes per document at
# RUNTIME, on the `use_bda` flag of the config version the document is pinned to
# (see `RouteByProcessingMode`, and the `count = 1` note at the top of
# lambda_bda.tf). There is deliberately no `use_bda` input variable: a single
# deployment must be able to serve a BDA config version and a Bedrock-LLM config
# version at the same time, so the branch cannot be selected at plan time.
#
# This file previously asserted the opposite — that `use_bda = false` omitted the
# BDA Lambdas and started the machine at OCRStep. That predates the
# always-both-branches refactor, and the assertions had gone permanently red.
# They are rewritten here to pin the behaviour the engine actually has.
#
# Offline by design: the AWS provider is mocked so the suite runs with no AWS
# credentials and no network. `command = plan` is used throughout — assertions
# target input-derived resource counts and the routing-topology outputs, which
# the mock provider makes known at plan time. The real `archive`/`time`/`null`
# providers stay live so the `archive_file` data sources also verify that every
# `sources/patterns/unified/...` path resolves.

# The mocked AWS provider must return a valid partition/region/account for the
# many `arn:${data.aws_partition.current.partition}:...` interpolations, or the
# AWS provider's ARN validation rejects the random mock values at plan time.
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
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

# Shared, realistic dummy inputs for the engine ↔ façade delegation contract.
variables {
  name = "unified-test"

  # Shared processing-environment ARNs (realistic dummy values).
  input_bucket_arn        = "arn:aws:s3:::idp-input-bucket"
  output_bucket_arn       = "arn:aws:s3:::idp-output-bucket"
  working_bucket_arn      = "arn:aws:s3:::idp-working-bucket"
  configuration_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-configuration"
  tracking_table_arn      = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-tracking"
  concurrency_table_arn   = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-concurrency"

  metric_namespace = "IDP/Test"
  log_level        = "INFO"

  # Lambda layers (realistic dummy ARNs).
  idp_common_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
  base_layer_arn       = "arn:aws:lambda:us-east-1:123456789012:layer:idp-base:1"

  # Sparse document config — the engine merges per-step model overrides onto it.
  config = {}
}

# ---------------------------------------------------------------------------
# Both branches are provisioned, and the state machine can route to either.
# ---------------------------------------------------------------------------
run "both_branches_are_always_provisioned" {
  command = plan

  # BDA branch: invoke, process-results, async completion, and the completion DLQ.
  assert {
    condition     = length(aws_lambda_function.bda_invoke) == 1
    error_message = "BDA invoke Lambda must always be created; routing is a runtime decision."
  }
  assert {
    condition     = length(aws_lambda_function.bda_process_results) == 1
    error_message = "BDA process-results Lambda must always be created; routing is a runtime decision."
  }
  assert {
    condition     = length(aws_lambda_function.bda_completion) == 1
    error_message = "BDA completion Lambda must always be created; routing is a runtime decision."
  }
  assert {
    condition     = length(aws_sqs_queue.bda_completion_dlq) == 1
    error_message = "BDA completion DLQ must always be created; routing is a runtime decision."
  }

  # Pipeline branch: OCR → classification → extraction.
  assert {
    condition     = aws_lambda_function.ocr.function_name == "unified-test-ocr"
    error_message = "Pipeline OCR Lambda must always be present."
  }
  assert {
    condition     = aws_lambda_function.classification.function_name == "unified-test-classification"
    error_message = "Pipeline classification Lambda must always be present."
  }
  assert {
    condition     = aws_lambda_function.extraction.function_name == "unified-test-extraction"
    error_message = "Pipeline extraction Lambda must always be present."
  }
}

# ---------------------------------------------------------------------------
# Routing topology: the machine enters at the v0.6 preprocessing hook, then
# reaches the runtime router, which can send a document down either branch.
# ---------------------------------------------------------------------------
run "state_machine_routes_both_branches_at_runtime" {
  command = plan

  # StartAt is the flat preprocessing hook, which runs BEFORE the routing
  # decision so it fires in both processing modes (and even when OCR is off).
  assert {
    condition     = output.state_machine_start_at == "PreprocessingHook"
    error_message = "State machine must start at PreprocessingHook so the v0.6 preprocessing hook precedes BDA/pipeline routing."
  }

  # The runtime router and both branch entry points are all present.
  assert {
    condition = alltrue([for s in [
      "RouteByProcessingMode",
      "BDA_CheckExistingData",
      "BDA_InvokeDataAutomation",
      "OCRStep",
    ] : contains(output.state_machine_state_names, s)])
    error_message = "The runtime router and both branch entry points must all be rendered."
  }

  # The router is reachable from the preprocessing halt check, so a document with
  # no preprocessing hook configured still routes normally.
  assert {
    condition     = contains(output.state_machine_transition_targets, "RouteByProcessingMode")
    error_message = "RouteByProcessingMode must be a transition target; otherwise routing is unreachable behind the preprocessing hook."
  }
}
