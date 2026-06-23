# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for B3 — AppSyncVisibility wiring on the
# processing-environment-api module (task 2.2).
#
# Property 13 (visibility portion) — Requirements 9.1, 9.2, 9.4:
#   * visibility in {GLOBAL, PRIVATE} reaches the API
#     (aws_appsync_graphql_api.api.visibility == the input);
#   * unset -> defaults to GLOBAL;
#   * any other value -> the variable validation fails, naming the allowed
#     values (asserted with expect_failures on var.visibility).
#
# The API module's `var.visibility` (default "GLOBAL", validated to
# GLOBAL/PRIVATE) feeds `aws_appsync_graphql_api.api.visibility = var.visibility`
# directly, so the value is input-derived and a `plan` is sufficient.
#
# Offline harness: the aws provider is mocked; `mock_data` supplies a real
# partition/region/account so AWS ARN-partition validation passes. Optional
# features that would pull in extra Lambdas/resources are switched off to keep
# the plan focused on the AppSync API resource under test. A Cognito
# authorization config is supplied so the API is wired with a non-API_KEY auth
# type (per the module's authorization validation).

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

mock_provider "archive" {}
mock_provider "random" {}
mock_provider "null" {}
mock_provider "local" {}

variables {
  input_bucket_arn        = "arn:aws:s3:::idp-test-input"
  output_bucket_arn       = "arn:aws:s3:::idp-test-output"
  tracking_table_arn      = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-test-tracking"
  configuration_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-test-config"
  encryption_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-1234-1234-1234-123456789012"

  authorization_config = {
    default_authorization = {
      authorization_type = "AMAZON_COGNITO_USER_POOLS"
      user_pool_config = {
        user_pool_id = "us-east-1_TESTPOOL"
        aws_region   = "us-east-1"
      }
    }
  }

  # Keep the plan focused on the AppSync API resource: switch off the optional
  # feature subsystems that would otherwise instantiate extra Lambdas.
  enable_agent_companion_chat = false
  enable_hitl                 = false
  enable_test_studio          = false
  enable_capacity_planning    = false
  enable_edit_sections        = false
}

# ---------------------------------------------------------------------------
# Unset -> default visibility is GLOBAL (Req 9.4).
# ---------------------------------------------------------------------------
run "default_visibility_is_global" {
  command = plan

  assert {
    condition     = aws_appsync_graphql_api.api.visibility == "GLOBAL"
    error_message = "Unset visibility must default to GLOBAL on the AppSync API."
  }
}

# ---------------------------------------------------------------------------
# Explicit GLOBAL reaches the API (Req 9.1).
# ---------------------------------------------------------------------------
run "visibility_global_reaches_api" {
  command = plan

  variables {
    visibility = "GLOBAL"
  }

  assert {
    condition     = aws_appsync_graphql_api.api.visibility == "GLOBAL"
    error_message = "visibility = GLOBAL must reach aws_appsync_graphql_api.api.visibility."
  }
}

# ---------------------------------------------------------------------------
# Explicit PRIVATE reaches the API (Req 9.1).
# ---------------------------------------------------------------------------
run "visibility_private_reaches_api" {
  command = plan

  variables {
    visibility = "PRIVATE"
  }

  assert {
    condition     = aws_appsync_graphql_api.api.visibility == "PRIVATE"
    error_message = "visibility = PRIVATE must reach aws_appsync_graphql_api.api.visibility."
  }
}

# ---------------------------------------------------------------------------
# Any other value -> variable validation fails naming the allowed values
# (Req 9.2). expect_failures on var.visibility needs no resources.
# ---------------------------------------------------------------------------
run "invalid_visibility_rejected" {
  command = plan

  variables {
    visibility = "public"
  }

  expect_failures = [
    var.visibility,
  ]
}
