# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the version-check sub-feature.
#
# The resolver is created UNCONDITIONALLY, matching upstream, which gives its
# VersionCheckResolverFunction no Condition. Only the S3 read grant and the
# PUBLIC_ARTIFACTS_BUCKET env are gated on the bucket input. Gating the Lambda
# itself left `getLatestPublishedVersion` unmapped, so the dispatcher answered 404
# on every page load; the resolver already reports `checkEnabled: false` itself
# when the bucket is unset.
#
# The S3-scoping runs use `command = apply`: the inline policy JSON embeds the
# computed log-group ARN, which is only known after apply.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_data "aws_region" {
    defaults = {
      # `region` is what the derived ARNs read (provider v6 rename); an unmocked
      # attribute gets a random value and fails ARN-shape validation.
      region = "us-east-1"
      id     = "us-east-1"
      name   = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  # On apply the mock provider returns random strings for computed attributes,
  # which fail the provider's ARN-shape validation on cross-resource references.
  # None of these affect the policy under test.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/idp-test-version-check"
    }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:function:idp-test-fn"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/idp-test-policy"
    }
  }
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
  # Short, and fixed rather than suffixed: the default
  # "ProcessingEnvironmentApi-<suffix>" pushes derived IAM role names past the
  # 64-char limit, which fails every apply-mode run.
  name = "idp-vc"

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

  enable_agent_companion_chat = false
  enable_hitl                 = false
  enable_test_studio          = false
  enable_capacity_planning    = false
  enable_edit_sections        = false
}

# Bucket unset: the resolver still exists and is still routed, but carries no
# bucket env. This is the regression guard for the 404 — a `count` here is what
# removed the field from the dispatcher map.
run "resolver_exists_and_is_routed_when_bucket_unset" {
  # apply, not plan: the function/role names derive from a computed suffix.
  command = apply

  assert {
    condition     = aws_lambda_function.version_check_resolver.function_name != ""
    error_message = "The version-check resolver must be created even when public_artifacts_bucket is unset, or getLatestPublishedVersion is unmapped and the dispatcher 404s."
  }

  assert {
    condition     = aws_iam_role.version_check_resolver.name != ""
    error_message = "The version-check execution role must be created unconditionally alongside the Lambda."
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.version_check_resolver.environment[0].variables), "PUBLIC_ARTIFACTS_BUCKET")
    error_message = "With no bucket configured the Lambda must not receive PUBLIC_ARTIFACTS_BUCKET; it reports checkEnabled=false from its absence."
  }
}

# Bucket set: the env threads the input under the key the shipped resolver reads.
run "bucket_input_threads_into_the_env" {
  command = plan

  variables {
    public_artifacts_bucket = "my-public-idp-artifacts"
  }

  assert {
    condition     = aws_lambda_function.version_check_resolver.environment[0].variables["PUBLIC_ARTIFACTS_BUCKET"] == "my-public-idp-artifacts"
    error_message = "The Lambda env PUBLIC_ARTIFACTS_BUCKET must equal the public_artifacts_bucket input."
  }
}

# Bucket unset: no S3 grant at all. Interpolating an empty bucket name would
# otherwise produce the invalid ARN `arn:aws:s3:::`.
run "no_s3_grant_when_bucket_unset" {
  command = apply

  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver.policy).Statement :
      s if contains(s.Action, "s3:GetObject")
    ]) == 0
    error_message = "With no bucket configured the role must carry no S3 statement."
  }
}

# Bucket set: the S3 statement is scoped to exactly that bucket, never a wildcard.
run "s3_grant_is_least_privilege_when_bucket_set" {
  command = apply

  variables {
    public_artifacts_bucket = "my-public-idp-artifacts"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver.policy).Statement :
      s.Resource != "*"
    ])
    error_message = "No version-check policy statement may use a wildcard ('*') resource."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver.policy).Statement :
      [for r in s.Resource : r != "*"]
    ]))
    error_message = "No version-check policy resource entry may be a wildcard ('*')."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver.policy).Statement :
      toset(s.Resource) == toset([
        "arn:aws:s3:::my-public-idp-artifacts",
        "arn:aws:s3:::my-public-idp-artifacts/*",
      ]) if contains(s.Action, "s3:GetObject")
    ])
    error_message = "The S3 statement must be scoped to exactly the public artifacts bucket arn + '/*'."
  }

  # Confirms the assertion above is not vacuously true.
  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver.policy).Statement :
      s if contains(s.Action, "s3:GetObject")
    ]) == 1
    error_message = "There must be exactly one S3 (s3:GetObject) statement in the version-check role policy."
  }
}
