# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for config model-authority (config-ownership-and-seeding).
#
# Asserts that classification/extraction/summarization models are resolved from
# the YAML configuration and upstream system defaults ONLY — Terraform no longer
# assigns per-stage model IDs — and that the per-step Bedrock IAM grant is
# derived from the SAME resolved model the runtime will invoke, including the
# system-default model the seeder merges in when the config YAML names none.
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
# Extraction is the discriminating step: its system default (claude-sonnet-5)
# differs from the classification default, so it proves resolution came from the
# config/defaults and not from a hard-coded fallback.

mock_provider "archive" {}
mock_provider "time" {}
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
  # defaults (the seeder merges them in), and IAM must match.
  config  = {}
  use_bda = false
}

# ---------------------------------------------------------------------------
# No config model: the resolved model comes from the system default. Extraction
# is the discriminator (claude-sonnet-5 differs from the classification default).
# ---------------------------------------------------------------------------
run "sparse_config_resolves_extraction_to_system_default" {
  command = plan

  assert {
    condition     = output.extraction_model == "us.anthropic.claude-sonnet-5"
    error_message = "Extraction model must resolve to the system default (us.anthropic.claude-sonnet-5)."
  }
  assert {
    condition     = output.summarization_model == null
    error_message = "Summarization is disabled by default, so its resolved model output must be null."
  }
}

# ---------------------------------------------------------------------------
# The extraction IAM grant is scoped to the system-default model.
# claude-sonnet-5 (prefix stripped) must appear as the foundation resource and
# the cross-region inference profile must keep its geo prefix.
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
}

# ---------------------------------------------------------------------------
# Config YAML is authoritative: a model declared in the config wins over the
# system default, in BOTH the resolved model and the IAM policy.
# ---------------------------------------------------------------------------
run "config_yaml_model_is_authoritative" {
  command = plan

  variables {
    config = {
      extraction = { model = "us.anthropic.claude-3-5-haiku" }
    }
  }

  assert {
    condition     = output.extraction_model == "us.anthropic.claude-3-5-haiku"
    error_message = "A model declared in the config YAML must be the resolved extraction model."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/anthropic.claude-3-5-haiku")
    error_message = "Extraction IAM must scope the config-YAML-declared model."
  }
  # The system default must NOT appear once the config names its own model.
  assert {
    condition     = !strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/anthropic.claude-sonnet-5\"")
    error_message = "Extraction IAM must not also grant the system default when the config names a model."
  }
}

# ---------------------------------------------------------------------------
# Models named by an ADDITIONAL (non-active) config version are also granted,
# because that version can be activated from the UI. Regression for the
# AccessDenied-on-activate class this refactor guarantees against.
# ---------------------------------------------------------------------------
run "additional_config_models_are_granted" {
  command = plan

  variables {
    config = {
      extraction = { model = "us.anthropic.claude-sonnet-5" }
    }
    additional_configurations = {
      "haiku-variant" = {
        extraction = { model = "us.anthropic.claude-3-5-haiku" }
      }
    }
  }

  # Both the active model and the additional version's model are granted.
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/anthropic.claude-sonnet-5")
    error_message = "Extraction IAM must scope the active config's model."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/anthropic.claude-3-5-haiku")
    error_message = "Extraction IAM must scope an additional config version's model (it can be activated in the UI)."
  }
}

# ---------------------------------------------------------------------------
# The operator escape hatch (allowed_bedrock_model_ids) still adds models on
# top of the config-resolved set.
# ---------------------------------------------------------------------------
run "operator_allowlist_adds_models" {
  command = plan

  variables {
    config                    = { extraction = { model = "us.anthropic.claude-sonnet-5" } }
    allowed_bedrock_model_ids = ["us.amazon.nova-pro-v1:0"]
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.extraction_lambda.policy, "foundation-model/amazon.nova-pro-v1:0")
    error_message = "The operator allowlist model must be granted on top of the config-resolved model."
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
  # Escalation model granted as invoked: :1m is a header, not part of the ID, so
  # the grant carries the stripped form. This also makes the escalation ARN
  # identical to the extraction model's, which is why "did not fall back to the
  # extraction model" is asserted by the nova-lite checks above, not by the
  # absence of claude-sonnet-5.
  assert {
    condition     = strcontains(aws_iam_role_policy.assessment_lambda.policy, "foundation-model/anthropic.claude-sonnet-5\"")
    error_message = "Assessment IAM must scope extraction.confidence.escalation_model."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.assessment_lambda.policy, "inference-profile/us.anthropic.claude-sonnet-5\"")
    error_message = "Assessment IAM must scope the escalation model's cross-region inference profile."
  }
  assert {
    condition     = !strcontains(aws_iam_role_policy.assessment_lambda.policy, ":1m")
    error_message = "No grant may carry a :1m suffix; Bedrock authorizes the stripped model ID."
  }
}

# ---------------------------------------------------------------------------
# Plan-time shape validation fails on a malformed model ID sourced from config.
# ---------------------------------------------------------------------------
run "malformed_config_model_id_fails_plan" {
  command = plan

  variables {
    config = {
      extraction = { model = "not a valid model id!!" }
    }
  }

  expect_failures = [
    terraform_data.bedrock_model_id_validation,
  ]
}
