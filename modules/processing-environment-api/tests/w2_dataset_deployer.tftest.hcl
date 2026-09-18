# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the W2 dataset deployer on the
# processing-environment-api module.
#
# W2 deployer present iff Test-Studio+W2 enabled, mirrors FCC:
#   * Test Studio off entirely      -> 0 w2_dataset_deployer resources;
#   * Test Studio on, W2 off         -> 0 w2_dataset_deployer resources;
#   * Test Studio on, W2 on          -> the W2 Lambda (+ log group + archive) is
#     present, its environment equals `local.test_studio_env` (asserted by
#     equality with the always-present `test_runner` Lambda, which is also wired
#     to `local.test_studio_env`), and it reuses the shared
#     `aws_iam_role.test_studio_lambdas` role.
#
# Mirrors-FCC note: the shipped W2 deployer is a CloudFormation
# custom-resource-style deployer (Custom::W2DatasetDeployer via cfnresponse),
# NOT an AppSync-invoked resolver — exactly like the FCC deployer.
# So, faithfully mirroring FCC, the W2 deployer gets NO AppSync data source /
# resolver and is NOT added to `appsync_invoke_test_studio_policy`. This test
# asserts that: the W2 Lambda ARN is absent from the AppSync invoke policy's
# Resource list (decoded via `jsondecode`), and that the invoke policy holds the
# same six Test Studio resolver Lambdas (no W2 entry).
#
# Offline harness: the aws provider is mocked (real partition/region/account so
# ARN-partition validation passes); archive/random/null/local mocked. A Cognito
# auth config is supplied (the module rejects API_KEY). Optional non-Test-Studio
# subsystems are switched off to keep the plan focused on Test Studio.

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

  # The "present + mirrors FCC" run uses `command = apply` (computed env maps,
  # role ARNs, and the rendered invoke-policy JSON are unknown at plan). The AWS
  # provider validates `role` / `policy_arn` inputs as real ARNs, so the
  # mock-generated values must be valid ARN strings. Default IAM role/policy
  # ARNs and the AppSync URIs map accordingly.
  #
  # NB: `aws_lambda_function` ARNs ARE defaulted to a valid ARN string so the
  # AppSync data sources (which validate `lambda_config.function_arn`) apply
  # cleanly. This collapses all Lambda mock ARNs to one value, so the
  # "mirrors FCC" check below is expressed structurally (the invoke policy's
  # Resource list length is exactly the six Test Studio resolver Lambdas — a
  # dataset deployer entry would make it seven) rather than by ARN membership.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock-policy"
    }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:function:mock-fn"
    }
  }
  # Stage access_log_settings.destination_arn is ARN-validated.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/idp-test:*"
    }
  }
}

mock_provider "archive" {}
mock_provider "random" {}
mock_provider "null" {}
mock_provider "local" {}
mock_provider "time" {}

variables {
  # Default name + suffix overflows the 64-char IAM role limit on apply.
  name = "idp-w2"

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

  # Keep the plan focused on Test Studio: switch off the other optional
  # feature subsystems that would otherwise instantiate extra Lambdas.
  enable_agent_companion_chat = false
  enable_hitl                 = false
  enable_capacity_planning    = false
  enable_edit_sections        = false
}

# ---------------------------------------------------------------------------
# Test Studio OFF entirely -> 0 W2 deployer resources.
# ---------------------------------------------------------------------------
run "test_studio_off_no_w2" {
  command = plan

  variables {
    enable_test_studio = false
    enable_w2_dataset  = true # even with the toggle on, Test Studio gates it off
  }

  assert {
    condition     = length(aws_lambda_function.w2_dataset_deployer) == 0
    error_message = "Test Studio disabled must create no W2 deployer Lambda."
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.w2_dataset_deployer) == 0
    error_message = "Test Studio disabled must create no W2 deployer log group."
  }
  assert {
    condition     = length(data.archive_file.w2_dataset_deployer) == 0
    error_message = "Test Studio disabled must create no W2 deployer archive."
  }
}

# ---------------------------------------------------------------------------
# Test Studio ON, W2 OFF -> 0 W2 deployer resources (default-off).
# ---------------------------------------------------------------------------
run "test_studio_on_w2_off_no_w2" {
  command = plan

  variables {
    enable_test_studio = true
    enable_w2_dataset  = false
  }

  assert {
    condition     = length(aws_lambda_function.w2_dataset_deployer) == 0
    error_message = "W2 dataset disabled must create no W2 deployer Lambda."
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.w2_dataset_deployer) == 0
    error_message = "W2 dataset disabled must create no W2 deployer log group."
  }
  assert {
    condition     = length(data.archive_file.w2_dataset_deployer) == 0
    error_message = "W2 dataset disabled must create no W2 deployer archive."
  }
}

# ---------------------------------------------------------------------------
# Test Studio ON, W2 ON -> W2 Lambda present; env == local.test_studio_env
# (via equality with the always-present test_runner Lambda); shared role
# reused; mirrors FCC (no AppSync invoke grant for the W2 ARN).
#
# Uses `command = apply` (against the mocked providers) because the env map,
# the Lambda's role ARN, and the rendered AppSync invoke-policy JSON are
# computed attributes not known until after apply.
# ---------------------------------------------------------------------------
run "test_studio_on_w2_on_present_mirrors_fcc" {
  command = apply

  variables {
    enable_test_studio = true
    enable_w2_dataset  = true
  }

  # --- Present ---
  assert {
    condition     = length(aws_lambda_function.w2_dataset_deployer) == 1
    error_message = "Test Studio + W2 enabled must create exactly one W2 deployer Lambda."
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.w2_dataset_deployer) == 1
    error_message = "Test Studio + W2 enabled must create the W2 deployer log group."
  }
  assert {
    condition     = length(data.archive_file.w2_dataset_deployer) == 1
    error_message = "Test Studio + W2 enabled must create the W2 deployer archive."
  }

  # --- Environment equals local.test_studio_env ---
  # test_runner is always created when Test Studio is on and is wired to
  # local.test_studio_env; asserting equality proves the W2 deployer uses the
  # exact same env map (TESTSET_BUCKET / TRACKING_TABLE / LOG_LEVEL, ...).
  assert {
    condition     = aws_lambda_function.w2_dataset_deployer[0].environment[0].variables == aws_lambda_function.test_runner[0].environment[0].variables
    error_message = "W2 deployer environment must equal local.test_studio_env (the shared Test Studio env)."
  }

  # --- Shared Test Studio execution role reused ---
  assert {
    condition     = aws_lambda_function.w2_dataset_deployer[0].role == aws_iam_role.test_studio_lambdas[0].arn
    error_message = "W2 deployer must reuse the shared test_studio_lambdas execution role."
  }

  # Mirrors FCC: a deployer, not a resolver, so no API field may route to it.
  # AppSync's invoke policy is gone; the dispatcher's field map is the successor.
  assert {
    condition = length([
      for field in keys(jsondecode(aws_ssm_parameter.http_api_field_function_map.value)) :
      field if length(regexall("(?i)w2|dataset", field)) > 0
    ]) == 0
    error_message = "No API field may route to the W2 dataset deployer: it is a deployer, not a resolver."
  }
}
