# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the shared unified-processor engine: `use_bda`
# routing.
#
# The engine receives a non-null boolean `use_bda` set by the instantiating
# façade; the BDA branch resources (invoke/process-results/completion Lambdas +
# DLQ + EventBridge wiring) are created ONLY on the `use_bda = true` path, and
# the state machine routes through `RouteByProcessingMode`. On the
# `use_bda = false` path the pipeline branch (OCR → classification → extraction)
# is the entry point and the BDA-branch resources are absent (count 0).
#
# Offline by design: the AWS provider is mocked so the suite runs with no AWS
# credentials and no network. `command = plan` is used throughout — assertions
# target input-derived resource counts and the rendered state-machine
# definition / IAM, which the mock provider makes known at plan time. The real
# `archive`/`time`/`null` providers stay live so the `archive_file` data sources
# also verify that every `sources/patterns/unified/...` path resolves.

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
# Per-run `variables` blocks below only flip `use_bda` (+ `bda_project_arn`).
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
# use_bda = true  →  BDA branch present, state machine routes via the router.
# ---------------------------------------------------------------------------
run "use_bda_true_creates_bda_branch" {
  command = plan

  variables {
    use_bda         = true
    bda_project_arn = "arn:aws:bedrock:us-east-1:123456789012:data-automation-project/abc123"
  }

  # BDA invoke Lambda is present on the BDA path.
  assert {
    condition     = length(aws_lambda_function.bda_invoke) == 1
    error_message = "BDA invoke Lambda must be created when use_bda = true."
  }

  # BDA process-results Lambda is present on the BDA path.
  assert {
    condition     = length(aws_lambda_function.bda_process_results) == 1
    error_message = "BDA process-results Lambda must be created when use_bda = true."
  }

  # BDA async completion Lambda is present on the BDA path.
  assert {
    condition     = length(aws_lambda_function.bda_completion) == 1
    error_message = "BDA completion Lambda must be created when use_bda = true."
  }

  # The BDA completion DLQ is present on the BDA path.
  assert {
    condition     = length(aws_sqs_queue.bda_completion_dlq) == 1
    error_message = "BDA completion DLQ must be created when use_bda = true."
  }

  # The pipeline branch is ALWAYS present (it is the non-BDA path), so OCR /
  # classification / extraction exist on the BDA path too.
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

  # The state machine enters at the runtime router and routes the BDA branch.
  # (The full rendered `definition` interpolates computed Lambda ARNs and is
  # unknown at plan, so we assert on the engine's routing-topology outputs,
  # which derive purely from `var.use_bda`.)
  assert {
    condition     = output.state_machine_start_at == "RouteByProcessingMode"
    error_message = "State machine must start at RouteByProcessingMode when use_bda = true."
  }
  assert {
    condition     = contains(output.state_machine_state_names, "BDA_InvokeDataAutomation")
    error_message = "State machine must include the BDA invoke branch when use_bda = true."
  }
  assert {
    condition     = contains(output.state_machine_state_names, "RouteByProcessingMode")
    error_message = "State machine must include the BDA router state when use_bda = true."
  }
}

# ---------------------------------------------------------------------------
# use_bda = false  →  BDA branch absent, state machine starts at the pipeline.
# ---------------------------------------------------------------------------
run "use_bda_false_omits_bda_branch" {
  command = plan

  variables {
    use_bda = false
  }

  # No BDA-branch resources on the pipeline path (count 0).
  assert {
    condition     = length(aws_lambda_function.bda_invoke) == 0
    error_message = "BDA invoke Lambda must NOT be created when use_bda = false."
  }
  assert {
    condition     = length(aws_lambda_function.bda_process_results) == 0
    error_message = "BDA process-results Lambda must NOT be created when use_bda = false."
  }
  assert {
    condition     = length(aws_lambda_function.bda_completion) == 0
    error_message = "BDA completion Lambda must NOT be created when use_bda = false."
  }
  assert {
    condition     = length(aws_sqs_queue.bda_completion_dlq) == 0
    error_message = "BDA completion DLQ must NOT be created when use_bda = false."
  }

  # The pipeline branch is exercised: OCR / classification / extraction present.
  assert {
    condition     = aws_lambda_function.ocr.function_name == "unified-test-ocr"
    error_message = "Pipeline OCR Lambda must be present when use_bda = false."
  }
  assert {
    condition     = aws_lambda_function.classification.function_name == "unified-test-classification"
    error_message = "Pipeline classification Lambda must be present when use_bda = false."
  }
  assert {
    condition     = aws_lambda_function.extraction.function_name == "unified-test-extraction"
    error_message = "Pipeline extraction Lambda must be present when use_bda = false."
  }

  # State machine starts directly at the pipeline (no BDA router state).
  assert {
    condition     = output.state_machine_start_at == "OCRStep"
    error_message = "State machine must start at the pipeline OCRStep when use_bda = false."
  }
  assert {
    condition     = contains(output.state_machine_state_names, "OCRStep")
    error_message = "State machine must include the pipeline OCRStep when use_bda = false."
  }
  assert {
    condition     = !contains(output.state_machine_state_names, "RouteByProcessingMode")
    error_message = "State machine must NOT include the BDA router when use_bda = false."
  }
  assert {
    condition     = !contains(output.state_machine_state_names, "BDA_InvokeDataAutomation")
    error_message = "State machine must NOT include the BDA invoke branch when use_bda = false."
  }
}
