# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the root exactly-one-processor validation
# (the `check "exactly_one_processor"` block in main.tf).
#
# The root validation succeeds if and only if
# exactly one of var.bda_processor / var.bedrock_llm_processor /
# var.sagemaker_udop_processor is non-null. Zero, two, or three → plan error.
#
# How the failing cases are asserted (TF check{}-vs-expect_failures note):
#   A `check {}` block is NOT a hard plan error — on its own it degrades a
#   failed assertion to a plan *warning*. However, `terraform test`'s
#   `expect_failures = [check.<name>]` is the first-class, faithful mechanism
#   for asserting a check assertion failed during a `command = plan` run: the
#   run PASSES iff the named check reported a failure, and FAILS if the check
#   unexpectedly held. We therefore assert the zero/two/three cases via
#   `expect_failures = [check.exactly_one_processor]` (no change to the
#   production validation was needed — the existing `check {}` is asserted as
#   shipped). The exactly-one (success) case asserts the plan is clean and the
#   correct processor was selected.
#
# Offline: the aws/awscc providers are mocked (mock_data overrides supply real
# partition/region/account so AWS ARN-partition validation passes); the archive
# provider zips Lambda sources from the read-only `sources/` snapshot for real.
# The root requires an `aws.us-east-1` provider alias (web-ui) — supplied as a
# second aliased mock so the mocked plan resolves without credentials/network.
#
# Zero-processor note: with no processor configured, `local.processor_type` is
# null. `output "processor"` was guarded (outputs.tf) to return null instead of
# calling `lookup(map, null, default)` — the latter raises an *uncatchable*
# function error that co-aborts the run before `expect_failures` can isolate the
# check. The guard is non-behavioral for every valid (exactly-one) deployment
# and only turns the already-invalid zero case from a hard crash into a clean
# check failure that this test can assert.

mock_provider "aws" {
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

mock_provider "aws" {
  alias = "us-east-1"
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

mock_provider "awscc" {}

# Pin the random suffix at PLAN time. Without this, resource names that embed
# `random_string.suffix.result` are unknown at plan; in particular the
# SageMaker-UDOP façade's classification-hook Lambda name feeds the engine's
# `aws_iam_role_policy.state_machine_hook_inference` count
# (`length(local.hook_function_names) > 0 ? 1 : 0`), which then errors with
# "Invalid count argument" on the three-processor case. `override_during = plan`
# makes the suffix known so the mocked plan reaches the check evaluation.
override_resource {
  target          = random_string.suffix
  override_during = plan
  values = {
    result = "testsuf1"
  }
}

# Shared inputs. web_ui + api are disabled so the only validation under test is
# `check "exactly_one_processor"` (the web_ui_requires_* checks stay satisfied).
variables {
  region             = "us-east-1"
  input_bucket_arn   = "arn:aws:s3:::idp-test-input"
  output_bucket_arn  = "arn:aws:s3:::idp-test-output"
  working_bucket_arn = "arn:aws:s3:::idp-test-working"
  encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-1234-1234-1234-123456789012"

  web_ui = { enabled = false }
  api    = { enabled = false }
}

# ---------------------------------------------------------------------------
# Zero processors → validation must fail.
# ---------------------------------------------------------------------------
run "zero_processors_fails" {
  command = plan

  variables {
    bda_processor            = null
    bedrock_llm_processor    = null
    sagemaker_udop_processor = null
  }

  expect_failures = [
    check.exactly_one_processor,
  ]
}

# ---------------------------------------------------------------------------
# Two processors (bda + bedrock-llm) → validation must fail.
# ---------------------------------------------------------------------------
run "two_processors_fails" {
  command = plan

  variables {
    bda_processor = {
      project_arn = "arn:aws:bedrock:us-east-1:123456789012:data-automation-project/test"
      config      = { classes = [] }
    }
    bedrock_llm_processor = {
      config = {
        classification = { model = "us.amazon.nova-lite-v1:0" }
        extraction     = { model = "us.amazon.nova-lite-v1:0" }
      }
    }
    sagemaker_udop_processor = null
  }

  expect_failures = [
    check.exactly_one_processor,
  ]
}

# ---------------------------------------------------------------------------
# Three processors → validation must fail.
# ---------------------------------------------------------------------------
run "three_processors_fails" {
  command = plan

  variables {
    bda_processor = {
      project_arn = "arn:aws:bedrock:us-east-1:123456789012:data-automation-project/test"
      config      = { classes = [] }
    }
    bedrock_llm_processor = {
      config = {
        classification = { model = "us.amazon.nova-lite-v1:0" }
        extraction     = { model = "us.amazon.nova-lite-v1:0" }
      }
    }
    sagemaker_udop_processor = {
      classification_endpoint_arn = "arn:aws:sagemaker:us-east-1:123456789012:endpoint/test-udop"
      config                      = { classes = [] }
    }
  }

  expect_failures = [
    check.exactly_one_processor,
  ]
}

# ---------------------------------------------------------------------------
# Exactly one processor → validation passes, correct processor selected.
# ---------------------------------------------------------------------------
run "exactly_one_bedrock_llm_succeeds" {
  command = plan

  variables {
    bda_processor = null
    bedrock_llm_processor = {
      config = {
        classification = { model = "us.amazon.nova-lite-v1:0" }
        extraction     = { model = "us.amazon.nova-lite-v1:0" }
      }
    }
    sagemaker_udop_processor = null
  }

  assert {
    condition     = output.processor_type == "bedrock-llm"
    error_message = "Exactly-one (bedrock-llm) must select the bedrock-llm processor and pass validation."
  }
}

run "exactly_one_bda_succeeds" {
  command = plan

  variables {
    bda_processor = {
      project_arn = "arn:aws:bedrock:us-east-1:123456789012:data-automation-project/test"
      config      = { classes = [] }
    }
    bedrock_llm_processor    = null
    sagemaker_udop_processor = null
  }

  assert {
    condition     = output.processor_type == "bda"
    error_message = "Exactly-one (bda) must select the bda processor and pass validation."
  }
}
