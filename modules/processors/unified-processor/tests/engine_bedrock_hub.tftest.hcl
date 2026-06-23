# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the shared unified-processor engine: B8 —
# BedrockHubRoleArn cross-account assume-role (task 1.2; Requirements 10.2,
# 10.3, 10.4).
#
# Property 12: `BedrockHubRoleArn` is fully additive and exactly scoped.
#   - empty `var.bedrock_hub_role_arn`  -> NO assume-role policy rendered on any
#     Bedrock-calling role AND no BEDROCK_ASSUME_ROLE_ARN env var on the
#     processing Lambdas (no B8-attributable resources; Req 10.2, 10.4).
#   - non-empty `var.bedrock_hub_role_arn` -> exactly ONE `sts:AssumeRole`
#     statement per Bedrock-calling role whose `Resource` is EXACTLY that ARN
#     and no other (Req 10.3), and `BEDROCK_ASSUME_ROLE_ARN` set on the
#     processing Lambdas' environment.
#
# Offline by design: the AWS provider is mocked so the suite runs with no AWS
# credentials and no network. `command = plan` is used throughout — the hub
# policy `policy` documents are `jsonencode(...)` of input-derived values and
# the Lambda `environment` maps are input-derived, so both are known at plan
# time with the mocked provider.

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

# Shared, realistic dummy inputs for the engine. The two gated Bedrock
# subsystems (summarization / evaluation / rule-validation) are enabled here so
# the suite can assert against EVERY Bedrock-calling role's hub policy. Per-run
# `variables` blocks below only flip `bedrock_hub_role_arn`.
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

  # Pipeline branch (non-BDA) — B8 placement is identical across branches.
  use_bda = false

  # Enable every gated Bedrock-calling subsystem so all six hub policies render
  # when the hub ARN is supplied.
  is_summarization_enabled       = true
  evaluation_enabled             = true
  evaluation_baseline_bucket_arn = "arn:aws:s3:::idp-baseline-bucket"
  evaluation_model_id            = "us.anthropic.claude-opus-4-7:1m"
  enable_rule_validation         = true
}

# ---------------------------------------------------------------------------
# Empty hub ARN (default) -> fully additive: no policy, no env var.
# ---------------------------------------------------------------------------
run "hub_disabled_renders_no_policy_or_env" {
  command = plan

  variables {
    bedrock_hub_role_arn = ""
  }

  # No assume-role policy rendered on ANY Bedrock-calling role (count 0 each) —
  # so there is no B8-attributable resource in the plan (Req 10.2, 10.4).
  assert {
    condition     = length(aws_iam_role_policy.classification_bedrock_hub_assume) == 0
    error_message = "B8: classification hub assume-role policy must not render when bedrock_hub_role_arn is empty (Req 10.2)."
  }
  assert {
    condition     = length(aws_iam_role_policy.extraction_bedrock_hub_assume) == 0
    error_message = "B8: extraction hub assume-role policy must not render when bedrock_hub_role_arn is empty (Req 10.2)."
  }
  assert {
    condition     = length(aws_iam_role_policy.assessment_bedrock_hub_assume) == 0
    error_message = "B8: assessment hub assume-role policy must not render when bedrock_hub_role_arn is empty (Req 10.2)."
  }
  assert {
    condition     = length(aws_iam_role_policy.summarization_bedrock_hub_assume) == 0
    error_message = "B8: summarization hub assume-role policy must not render when bedrock_hub_role_arn is empty (Req 10.2)."
  }
  assert {
    condition     = length(aws_iam_role_policy.evaluation_bedrock_hub_assume) == 0
    error_message = "B8: evaluation hub assume-role policy must not render when bedrock_hub_role_arn is empty (Req 10.2)."
  }
  assert {
    condition     = length(aws_iam_role_policy.rule_validation_bedrock_hub_assume) == 0
    error_message = "B8: rule-validation hub assume-role policy must not render when bedrock_hub_role_arn is empty (Req 10.2)."
  }

  # No BEDROCK_ASSUME_ROLE_ARN env var on the always-present processing Lambdas
  # (Req 10.4 — no B8-attributable diff on same-account deployments).
  assert {
    condition     = !contains(keys(aws_lambda_function.classification.environment[0].variables), "BEDROCK_ASSUME_ROLE_ARN")
    error_message = "B8: classification Lambda must not set BEDROCK_ASSUME_ROLE_ARN when the hub ARN is empty (Req 10.4)."
  }
  assert {
    condition     = !contains(keys(aws_lambda_function.extraction.environment[0].variables), "BEDROCK_ASSUME_ROLE_ARN")
    error_message = "B8: extraction Lambda must not set BEDROCK_ASSUME_ROLE_ARN when the hub ARN is empty (Req 10.4)."
  }
  assert {
    condition     = !contains(keys(aws_lambda_function.assessment.environment[0].variables), "BEDROCK_ASSUME_ROLE_ARN")
    error_message = "B8: assessment Lambda must not set BEDROCK_ASSUME_ROLE_ARN when the hub ARN is empty (Req 10.4)."
  }
}

# ---------------------------------------------------------------------------
# Non-empty hub ARN -> exactly one sts:AssumeRole statement per Bedrock-calling
# role, scoped to EXACTLY that ARN, and the env var set on the Lambdas.
# ---------------------------------------------------------------------------
run "hub_enabled_scopes_assume_role_exactly_and_sets_env" {
  command = plan

  variables {
    bedrock_hub_role_arn = "arn:aws:iam::222222222222:role/bedrock-hub-access"
  }

  # --- classification role: exactly one statement, exactly that ARN ---------
  assert {
    condition     = length(aws_iam_role_policy.classification_bedrock_hub_assume) == 1
    error_message = "B8: classification hub assume-role policy must render exactly once when the hub ARN is set (Req 10.1)."
  }
  assert {
    condition     = length(jsondecode(aws_iam_role_policy.classification_bedrock_hub_assume[0].policy).Statement) == 1
    error_message = "B8: classification hub policy must contain exactly one statement (Req 10.3)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.classification_bedrock_hub_assume[0].policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "B8: classification hub statement action must be exactly sts:AssumeRole (Req 10.3)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.classification_bedrock_hub_assume[0].policy).Statement[0].Resource == var.bedrock_hub_role_arn
    error_message = "B8: classification hub statement Resource must be exactly the supplied hub ARN and no other (Req 10.3)."
  }

  # --- extraction role ------------------------------------------------------
  assert {
    condition     = length(aws_iam_role_policy.extraction_bedrock_hub_assume) == 1
    error_message = "B8: extraction hub assume-role policy must render exactly once when the hub ARN is set (Req 10.1)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.extraction_bedrock_hub_assume[0].policy).Statement[0].Resource == var.bedrock_hub_role_arn
    error_message = "B8: extraction hub statement Resource must be exactly the supplied hub ARN and no other (Req 10.3)."
  }

  # --- assessment role ------------------------------------------------------
  assert {
    condition     = length(aws_iam_role_policy.assessment_bedrock_hub_assume) == 1
    error_message = "B8: assessment hub assume-role policy must render exactly once when the hub ARN is set (Req 10.1)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.assessment_bedrock_hub_assume[0].policy).Statement[0].Resource == var.bedrock_hub_role_arn
    error_message = "B8: assessment hub statement Resource must be exactly the supplied hub ARN and no other (Req 10.3)."
  }

  # --- summarization role (gated on is_summarization_enabled = true) --------
  assert {
    condition     = length(aws_iam_role_policy.summarization_bedrock_hub_assume) == 1
    error_message = "B8: summarization hub assume-role policy must render once when enabled and the hub ARN is set (Req 10.1)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.summarization_bedrock_hub_assume[0].policy).Statement[0].Resource == var.bedrock_hub_role_arn
    error_message = "B8: summarization hub statement Resource must be exactly the supplied hub ARN and no other (Req 10.3)."
  }

  # --- evaluation role (gated on evaluation_enabled = true) -----------------
  assert {
    condition     = length(aws_iam_role_policy.evaluation_bedrock_hub_assume) == 1
    error_message = "B8: evaluation hub assume-role policy must render once when enabled and the hub ARN is set (Req 10.1)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.evaluation_bedrock_hub_assume[0].policy).Statement[0].Resource == var.bedrock_hub_role_arn
    error_message = "B8: evaluation hub statement Resource must be exactly the supplied hub ARN and no other (Req 10.3)."
  }

  # --- rule-validation role (gated on enable_rule_validation = true) --------
  assert {
    condition     = length(aws_iam_role_policy.rule_validation_bedrock_hub_assume) == 1
    error_message = "B8: rule-validation hub assume-role policy must render once when enabled and the hub ARN is set (Req 10.1)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.rule_validation_bedrock_hub_assume[0].policy).Statement[0].Resource == var.bedrock_hub_role_arn
    error_message = "B8: rule-validation hub statement Resource must be exactly the supplied hub ARN and no other (Req 10.3)."
  }

  # --- env var wired onto the processing Lambdas ----------------------------
  assert {
    condition     = aws_lambda_function.classification.environment[0].variables["BEDROCK_ASSUME_ROLE_ARN"] == var.bedrock_hub_role_arn
    error_message = "B8: classification Lambda must set BEDROCK_ASSUME_ROLE_ARN to the hub ARN (Req 10.1)."
  }
  assert {
    condition     = aws_lambda_function.extraction.environment[0].variables["BEDROCK_ASSUME_ROLE_ARN"] == var.bedrock_hub_role_arn
    error_message = "B8: extraction Lambda must set BEDROCK_ASSUME_ROLE_ARN to the hub ARN (Req 10.1)."
  }
  assert {
    condition     = aws_lambda_function.assessment.environment[0].variables["BEDROCK_ASSUME_ROLE_ARN"] == var.bedrock_hub_role_arn
    error_message = "B8: assessment Lambda must set BEDROCK_ASSUME_ROLE_ARN to the hub ARN (Req 10.1)."
  }
}
