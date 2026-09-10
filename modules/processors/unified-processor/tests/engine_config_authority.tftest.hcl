# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for config model-authority (config-ownership-and-seeding).
#
# Asserts that classification/extraction/summarization models are
# YAML/system-default authoritative rather than force-pinned to var.model_id,
# and that the per-step Bedrock IAM grant is derived from the SAME resolved
# model the runtime will invoke — including the upstream system-default model
# the seeder merges in when neither a variable nor the config YAML names one.
#
# All assertions are at `command = plan` against the mocked provider: the
# resolved model IDs (module output) and the rendered IAM policy documents
# (jsonencode of input-derived values) are known without AWS creds or apply.
#
# System-default step models (sources/.../system_defaults/base-*.yaml), which
# the resolution reads directly so IAM matches the seeder's merge:
#   classification = us.amazon.nova-2-lite-v1:0
#   extraction     = us.anthropic.claude-sonnet-5
#   summarization  = us.anthropic.claude-sonnet-5:1m
# var.model_id defaults to us.amazon.nova-2-lite-v1:0, so extraction is the
# discriminating step: its default (claude-sonnet-5) differs from model_id.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { id = "us-east-1", name = "us-east-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  name = "unified-test"

  input_bucket_arn        = "arn:aws:s3:::idp-input-bucket"
  output_bucket_arn       = "arn:aws:s3:::idp-output-bucket"
  working_bucket_arn      = "arn:aws:s3:::idp-working-bucket"
  configuration_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-configuration"
  tracking_table_arn      = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-tracking"
  concurrency_table_arn   = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-concurrency"

  metric_namespace = "IDP/Test"
  log_level        = "INFO"

  idp_common_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
  base_layer_arn       = "arn:aws:lambda:us-east-1:123456789012:layer:idp-base:1"
  evaluation_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-eval:1"

  # A sparse config that declares NO step model — the realistic case for the
  # shipped example configs. Models must therefore come from the system
  # defaults, not from var.model_id.
  config  = {}
  use_bda = false
}

# ---------------------------------------------------------------------------
# No model variables set: the resolved model comes from the system default,
# NOT from var.model_id. Extraction is the discriminator (claude-sonnet-5).
# ---------------------------------------------------------------------------
run "no_vars_resolves_extraction_to_system_default_not_model_id" {
  command = plan

  assert {
    condition     = output.extraction_model == "us.anthropic.claude-sonnet-5"
    error_message = "Extraction model must resolve to the system default (us.anthropic.claude-sonnet-5), not var.model_id."
  }
  assert {
    condition     = output.summarization_model == null
    error_message = "Summarization is disabled by default, so its resolved model output must be null."
  }
}

# ---------------------------------------------------------------------------
# The extraction IAM grant is scoped to the system-default model, not model_id.
# claude-sonnet-5 (prefix stripped) must appear; nova-2-lite (model_id) must NOT
# be the extraction grant's foundation resource.
# ---------------------------------------------------------------------------
run "extraction_iam_scopes_system_default_model" {
  command = plan

  # Foundation-model ARN uses the geo-prefix-stripped base id.
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/anthropic.claude-sonnet-5")
    error_message = "Extraction IAM must scope the system-default extraction model (anthropic.claude-sonnet-5)."
  }
  # Cross-region inference-profile keeps the geo prefix.
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "inference-profile/us.anthropic.claude-sonnet-5")
    error_message = "Extraction IAM must scope the cross-region inference profile for the system-default model."
  }
  # The var.model_id fallback (nova-2-lite) must NOT be the extraction grant.
  assert {
    condition     = !strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/amazon.nova-2-lite-v1:0")
    error_message = "Extraction IAM must NOT fall back to var.model_id when a system default exists."
  }
}

# ---------------------------------------------------------------------------
# Config YAML wins over the system default (YAML-authoritative).
# ---------------------------------------------------------------------------
run "config_yaml_model_wins_over_system_default" {
  command = plan

  variables {
    config = {
      extraction = { model = "us.anthropic.claude-3-5-haiku" }
    }
  }

  assert {
    condition     = output.extraction_model == "us.anthropic.claude-3-5-haiku"
    error_message = "A model declared in the config YAML must win over the system default."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/anthropic.claude-3-5-haiku")
    error_message = "Extraction IAM must scope the config-YAML-declared model."
  }
}

# ---------------------------------------------------------------------------
# An explicit per-step variable wins over everything, in BOTH the resolved
# model and the IAM policy (task 7.6).
# ---------------------------------------------------------------------------
run "explicit_variable_override_wins_in_config_and_iam" {
  command = plan

  variables {
    extraction_model_id = "us.amazon.nova-pro-v1:0"
    config = {
      extraction = { model = "us.anthropic.claude-3-5-haiku" }
    }
  }

  assert {
    condition     = output.extraction_model == "us.amazon.nova-pro-v1:0"
    error_message = "An explicit extraction_model_id must win over the config YAML and system default."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/amazon.nova-pro-v1:0")
    error_message = "Extraction IAM must scope the explicit variable override."
  }
}

# ---------------------------------------------------------------------------
# Assessment reads extraction.confidence.model (v0.6 location) and the
# escalation model — NOT the extraction default. Regression for the live
# AccessDenied where the assessment Lambda invoked the confidence model
# (nova-lite) while IAM only granted the extraction default (claude-sonnet-5).
# ---------------------------------------------------------------------------
run "assessment_iam_scopes_confidence_and_escalation_models" {
  command = plan

  variables {
    config = {
      extraction = {
        model = "us.anthropic.claude-sonnet-5"
        confidence = {
          model            = "us.amazon.nova-lite-v1:0"
          escalation_model = "us.anthropic.claude-sonnet-5:1m"
        }
      }
    }
  }

  # Primary confidence model granted (geo-prefix stripped foundation + profile).
  assert {
    condition     = strcontains(aws_iam_role_policy.assessment_lambda.policy, "foundation-model/amazon.nova-lite-v1:0")
    error_message = "Assessment IAM must scope extraction.confidence.model (nova-lite), not the extraction default."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.assessment_lambda.policy, "inference-profile/us.amazon.nova-lite-v1:0")
    error_message = "Assessment IAM must scope the confidence model's cross-region inference profile."
  }
  # Escalation model also granted.
  assert {
    condition     = strcontains(aws_iam_role_policy.assessment_lambda.policy, "foundation-model/anthropic.claude-sonnet-5:1m")
    error_message = "Assessment IAM must scope extraction.confidence.escalation_model."
  }
  # The assessment grant must NOT be the extraction model when confidence differs.
  assert {
    condition     = !strcontains(aws_iam_role_policy.assessment_lambda.policy, "foundation-model/anthropic.claude-sonnet-5\"")
    error_message = "Assessment IAM must not fall back to the extraction model when a confidence model is set."
  }
}

# ---------------------------------------------------------------------------
# Plan-time shape validation fails on a malformed resolved model ID (task 5.3).
# ---------------------------------------------------------------------------
run "malformed_model_id_fails_plan" {
  command = plan

  variables {
    extraction_model_id = "not a valid model id!!"
  }

  expect_failures = [
    terraform_data.bedrock_model_id_validation,
  ]
}
