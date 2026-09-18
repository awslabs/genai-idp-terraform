# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for API visibility wiring on the
# processing-environment-api module.
#
# v0.6.0 removed AppSync, so `var.visibility` now drives `local.is_private_api`
# (rest-api.tf:24), which selects the REST API's endpoint type:
#   * unset or GLOBAL -> ["REGIONAL"]
#   * PRIVATE         -> ["PRIVATE"] + the supplied VPC endpoint id
#   * anything else   -> variable validation fails
#
# Offline harness: the aws provider is mocked; `mock_data` supplies a real
# partition/region/account so AWS ARN validation passes. Optional features that
# would pull in extra Lambdas are switched off to keep the plan focused. A
# Cognito authorization config is supplied so the API is wired with a
# non-API_KEY auth type (per the module's authorization validation).

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_data "aws_region" {
    defaults = {
      # `region` (provider v6 rename); unmocked -> random value -> invalid ARN.
      id     = "us-east-1"
      name   = "us-east-1"
      region = "us-east-1"
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
mock_provider "time" {}

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
# Unset -> default visibility is GLOBAL, i.e. a REGIONAL endpoint.
# ---------------------------------------------------------------------------
run "default_visibility_is_global" {
  command = plan

  assert {
    condition     = one(aws_api_gateway_rest_api.http_api.endpoint_configuration).types == tolist(["REGIONAL"])
    error_message = "Unset visibility must default to GLOBAL, giving a REGIONAL endpoint."
  }
}

# ---------------------------------------------------------------------------
# Explicit GLOBAL reaches the API.
# ---------------------------------------------------------------------------
run "visibility_global_reaches_api" {
  command = plan

  variables {
    visibility = "GLOBAL"
  }

  assert {
    condition     = one(aws_api_gateway_rest_api.http_api.endpoint_configuration).types == tolist(["REGIONAL"])
    error_message = "visibility = GLOBAL must give a REGIONAL REST API endpoint."
  }

}

# ---------------------------------------------------------------------------
# Explicit PRIVATE reaches the API.
# ---------------------------------------------------------------------------
run "visibility_private_reaches_api" {
  command = plan

  variables {
    visibility                  = "PRIVATE"
    api_gateway_vpc_endpoint_id = "vpce-0123456789abcdef0"
  }

  assert {
    condition     = one(aws_api_gateway_rest_api.http_api.endpoint_configuration).types == tolist(["PRIVATE"])
    error_message = "visibility = PRIVATE must give a PRIVATE REST API endpoint."
  }
  assert {
    condition     = one(aws_api_gateway_rest_api.http_api.endpoint_configuration).vpc_endpoint_ids == toset(["vpce-0123456789abcdef0"])
    error_message = "A PRIVATE API must be bound to the supplied VPC endpoint."
  }
  # The policy, not the endpoint type, is what confines invocation.
  assert {
    condition     = length(regexall("vpce-0123456789abcdef0", aws_api_gateway_rest_api.http_api.policy)) > 0
    error_message = "A PRIVATE API must carry a resource policy restricting invocation to its VPC endpoint."
  }
}

# ---------------------------------------------------------------------------
# Any other value -> variable validation fails naming the allowed values.
# expect_failures on var.visibility needs no resources.
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
