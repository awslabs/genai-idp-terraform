# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the single `processor` variable and its type
# validations (variables.tf).
#
# The deployment has exactly one processor by construction: the required
# `var.processor` object with a `type` discriminator. These runs assert the
# variable validations (type-in-set, per-type required fields, max_pages shape)
# and that a valid config selects the matching processor.
#
# Failing variable validations are asserted with
# `expect_failures = [var.processor]` during a `command = plan` run.
#
# Offline: the aws/awscc providers are mocked; the archive provider zips Lambda
# sources from the read-only `sources/` snapshot for real. The root requires an
# `aws.us-east-1` provider alias (web-ui), supplied as a second aliased mock.

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

# Pin the random suffix at PLAN time so resource names that embed
# `random_string.suffix.result` are known during the mocked plan.
override_resource {
  target          = random_string.suffix
  override_during = plan
  values = {
    result = "testsuf1"
  }
}

# Shared inputs. web_ui + api are disabled so the only thing under test is the
# processor variable validation.
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
# Invalid type → validation must fail.
# ---------------------------------------------------------------------------
run "invalid_type_fails" {
  command = plan

  variables {
    processor = {
      type   = "not-a-processor"
      config = { classes = [] }
    }
  }

  expect_failures = [
    var.processor,
  ]
}

# ---------------------------------------------------------------------------
# bda without project_arn → validation must fail.
# ---------------------------------------------------------------------------
run "bda_without_project_arn_fails" {
  command = plan

  variables {
    processor = {
      type   = "bda"
      config = { classes = [] }
    }
  }

  expect_failures = [
    var.processor,
  ]
}

# ---------------------------------------------------------------------------
# sagemaker-udop without classification_endpoint_arn → validation must fail.
# ---------------------------------------------------------------------------
run "sagemaker_udop_without_endpoint_fails" {
  command = plan

  variables {
    processor = {
      type   = "sagemaker-udop"
      config = { classes = [] }
    }
  }

  expect_failures = [
    var.processor,
  ]
}

# ---------------------------------------------------------------------------
# Non-numeric, non-ALL max_pages_for_classification → validation must fail.
# ---------------------------------------------------------------------------
run "bad_max_pages_fails" {
  command = plan

  variables {
    processor = {
      type                         = "bedrock-llm"
      max_pages_for_classification = "some"
      config = {
        classification = { model = "us.amazon.nova-lite-v1:0" }
        extraction     = { model = "us.amazon.nova-lite-v1:0" }
      }
    }
  }

  expect_failures = [
    var.processor,
  ]
}

# ---------------------------------------------------------------------------
# Valid bedrock-llm → passes, selects the bedrock-llm processor.
# ---------------------------------------------------------------------------
run "bedrock_llm_succeeds" {
  command = plan

  variables {
    processor = {
      type = "bedrock-llm"
      config = {
        classification = { model = "us.amazon.nova-lite-v1:0" }
        extraction     = { model = "us.amazon.nova-lite-v1:0" }
      }
    }
  }

  assert {
    condition     = output.processor_type == "bedrock-llm"
    error_message = "type=bedrock-llm must select the bedrock-llm processor."
  }
}

# ---------------------------------------------------------------------------
# Valid bda → passes, selects the bda processor.
# ---------------------------------------------------------------------------
run "bda_succeeds" {
  command = plan

  variables {
    processor = {
      type        = "bda"
      project_arn = "arn:aws:bedrock:us-east-1:123456789012:data-automation-project/test"
      config      = { classes = [] }
    }
  }

  assert {
    condition     = output.processor_type == "bda"
    error_message = "type=bda must select the bda processor."
  }
}
