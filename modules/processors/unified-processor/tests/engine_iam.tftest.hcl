# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the shared unified-processor engine: Bedrock
# inference-profile IAM.
#
# The engine IAM allows `bedrock:GetInferenceProfile`, and its resource scope
# includes `arn:<partition>:bedrock:*:<account>:application-inference-profile/*`
# alongside the existing `inference-profile/*` and `foundation-model/*`
# resources.
#
# The grant lives in the engine's Bedrock-invoking Lambda policies — the
# evaluation Lambda policy (gated on `evaluation_enabled`) and the
# rule-validation Lambda policy (gated on `enable_rule_validation`). This suite
# enables both so it can assert against the rendered IAM policy documents in the
# plan. These `policy` attributes are `jsonencode(...)` of input-derived values,
# so they are known at `command = plan` with the mocked provider — no AWS creds
# or apply required.

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

  config = {}

  # Pipeline branch (non-BDA) — IAM scope is identical across branches.
  use_bda = false

  # Enable the two engine subsystems that carry the Bedrock grant.
  evaluation_enabled             = true
  evaluation_baseline_bucket_arn = "arn:aws:s3:::idp-baseline-bucket"
  evaluation_model_id            = "us.anthropic.claude-opus-4-7:1m"
  enable_rule_validation         = true
}

# ---------------------------------------------------------------------------
# Evaluation Lambda policy carries the full Bedrock inference-profile grant.
# ---------------------------------------------------------------------------
run "evaluation_policy_includes_application_inference_profile" {
  command = plan

  # bedrock:GetInferenceProfile action present.
  assert {
    condition     = strcontains(aws_iam_role_policy.evaluation_lambda[0].policy, "bedrock:GetInferenceProfile")
    error_message = "Evaluation engine policy must allow bedrock:GetInferenceProfile."
  }

  # application-inference-profile/* resource present.
  assert {
    condition     = strcontains(aws_iam_role_policy.evaluation_lambda[0].policy, "application-inference-profile/*")
    error_message = "Evaluation engine policy must scope application-inference-profile/*."
  }

  # Existing inference-profile/* resource still present.
  # Matches the non-application profile ARN specifically (a leading ':' rules
  # out an accidental substring match on application-inference-profile).
  assert {
    condition     = strcontains(aws_iam_role_policy.evaluation_lambda[0].policy, ":inference-profile/*")
    error_message = "Evaluation engine policy must retain inference-profile/*."
  }

  # Existing foundation-model/* resource still present.
  assert {
    condition     = strcontains(aws_iam_role_policy.evaluation_lambda[0].policy, "foundation-model/*")
    error_message = "Evaluation engine policy must retain foundation-model/*."
  }
}

# ---------------------------------------------------------------------------
# Rule-validation Lambda policy carries the same Bedrock grant.
# ---------------------------------------------------------------------------
run "rule_validation_policy_includes_application_inference_profile" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.rule_validation_policy[0].policy, "bedrock:GetInferenceProfile")
    error_message = "Rule-validation engine policy must allow bedrock:GetInferenceProfile."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.rule_validation_policy[0].policy, "application-inference-profile/*")
    error_message = "Rule-validation engine policy must scope application-inference-profile/*."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.rule_validation_policy[0].policy, ":inference-profile/*")
    error_message = "Rule-validation engine policy must retain inference-profile/*."
  }
  assert {
    condition     = strcontains(aws_iam_role_policy.rule_validation_policy[0].policy, "foundation-model/*")
    error_message = "Rule-validation engine policy must retain foundation-model/*."
  }
}
