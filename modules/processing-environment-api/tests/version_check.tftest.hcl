# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for C14 — the version-check sub-feature on the
# processing-environment-api module (task 2.2).
#
# Property 2 — Version check is input-gated and least-privilege
# (Requirements 5.1, 5.3, 5.4):
#   * bucket unset (public_artifacts_bucket = "") -> 0 version_check Lambda,
#     AppSync data source, and resolver (default-off, no plan diff);
#   * bucket set -> the Lambda, data source, and resolver are all present, the
#     Lambda env `PUBLIC_ARTIFACTS_BUCKET` equals the input, and the resolver
#     role's S3 statement is scoped to exactly that bucket (its arn + `/*`),
#     never a `*` wildcard (asserted via `jsondecode` on the inline policy).
#
# Validates: Requirements 5.1, 5.3, 5.4
#
# Gating is input-derived (`local.version_check_enabled = var.public_artifacts_bucket
# != ""`), so the count assertions and the env assertion are known at `plan`.
# The S3-scoping assertion `jsondecode`s `aws_iam_role_policy.version_check_resolver`,
# whose JSON embeds the (computed) log-group ARN; that string is only fully known
# after apply, so the scoping run uses `command = apply` with a mocked IAM-role
# ARN — mirroring the RBAC `role_least_privilege` test — while the S3 statement's
# own resources are derived from the bucket input + partition and are exact.

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

  # On apply the mock provider returns random short strings for computed
  # attributes, which fail the AWS provider's ARN-shape validation on the many
  # cross-resource references in this module (AppSync data-source function ARNs,
  # IAM policy-attachment ARNs, the AppSync API `uris` output). Override the
  # computed attributes the apply-mode scoping run touches with well-formed
  # values. None of these affect the policy under test — it is `jsonencode`d from
  # the bucket input, the partition, and the log-group ARN.
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
  mock_resource "aws_appsync_graphql_api" {
    defaults = {
      uris = {
        GRAPHQL  = "https://example.appsync-api.us-east-1.amazonaws.com/graphql"
        REALTIME = "wss://example.appsync-realtime-api.us-east-1.amazonaws.com/graphql"
      }
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

  # Keep the plan focused on the version-check resources: switch off the optional
  # feature subsystems that would otherwise instantiate extra Lambdas.
  enable_agent_companion_chat = false
  enable_hitl                 = false
  enable_test_studio          = false
  enable_capacity_planning    = false
  enable_edit_sections        = false
}

# ---------------------------------------------------------------------------
# Bucket unset -> the version-check feature is inert: 0 Lambda / DS / resolver
# (Req 5.4, default-off).
# ---------------------------------------------------------------------------
run "version_check_disabled_when_bucket_unset" {
  command = plan

  # public_artifacts_bucket defaults to "" — leave it unset.

  assert {
    condition     = length(aws_lambda_function.version_check_resolver) == 0
    error_message = "With public_artifacts_bucket unset, no version_check_resolver Lambda may be created."
  }

  assert {
    condition     = length(aws_appsync_datasource.version_check) == 0
    error_message = "With public_artifacts_bucket unset, no version_check AppSync data source may be created."
  }

  assert {
    condition     = length(aws_appsync_resolver.get_latest_published_version) == 0
    error_message = "With public_artifacts_bucket unset, no getLatestPublishedVersion resolver may be created."
  }

  assert {
    condition     = length(aws_iam_role.version_check_resolver) == 0
    error_message = "With public_artifacts_bucket unset, no version-check execution role may be created."
  }
}

# ---------------------------------------------------------------------------
# Bucket set -> all three resources present and the env carries the bucket input
# (Req 5.1, 5.3). Input-derived, so `plan` is sufficient here.
# ---------------------------------------------------------------------------
run "version_check_enabled_when_bucket_set" {
  command = plan

  variables {
    public_artifacts_bucket = "my-public-idp-artifacts"
  }

  assert {
    condition     = length(aws_lambda_function.version_check_resolver) == 1
    error_message = "With public_artifacts_bucket set, the version_check_resolver Lambda must be created."
  }

  assert {
    condition     = length(aws_appsync_datasource.version_check) == 1
    error_message = "With public_artifacts_bucket set, the version_check AppSync data source must be created."
  }

  assert {
    condition     = length(aws_appsync_resolver.get_latest_published_version) == 1
    error_message = "With public_artifacts_bucket set, the getLatestPublishedVersion resolver must be created."
  }

  # The resolver must bind the Query.getLatestPublishedVersion field (no SDL
  # injection — the field already ships in the read-only schema).
  assert {
    condition = (aws_appsync_resolver.get_latest_published_version[0].type == "Query" &&
    aws_appsync_resolver.get_latest_published_version[0].field == "getLatestPublishedVersion")
    error_message = "The resolver must bind the Query.getLatestPublishedVersion field."
  }

  # The Lambda env must thread the bucket input under the exact key the shipped
  # resolver reads (Req 5.2/5.3 grounding).
  assert {
    condition     = aws_lambda_function.version_check_resolver[0].environment[0].variables["PUBLIC_ARTIFACTS_BUCKET"] == "my-public-idp-artifacts"
    error_message = "The Lambda env PUBLIC_ARTIFACTS_BUCKET must equal the public_artifacts_bucket input."
  }
}

# ---------------------------------------------------------------------------
# Bucket set -> the execution role's S3 statement is least-privilege: scoped to
# exactly the bucket arn + `/*`, never a `*` wildcard (Req 5.3). The inline
# policy JSON embeds the computed log-group ARN, so this run uses `apply` to
# materialize it for `jsondecode`.
# ---------------------------------------------------------------------------
run "version_check_role_is_least_privilege" {
  command = apply

  variables {
    public_artifacts_bucket = "my-public-idp-artifacts"
  }

  # No statement in the policy may use a bare "*" resource. Resource is a list on
  # every statement; a list compared to the string "*" is unequal, so this
  # catches a wildcard on any statement.
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver[0].policy).Statement :
      s.Resource != "*"
    ])
    error_message = "No version-check policy statement may use a wildcard ('*') resource."
  }

  # No individual resource entry across any statement may be a bare "*".
  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver[0].policy).Statement :
      [for r in s.Resource : r != "*"]
    ]))
    error_message = "No version-check policy resource entry may be a wildcard ('*')."
  }

  # The S3 statement (the one carrying s3:GetObject) must be scoped to exactly
  # the public artifacts bucket arn and its objects (arn + '/*') — and nothing
  # broader.
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver[0].policy).Statement :
      toset(s.Resource) == toset([
        "arn:aws:s3:::my-public-idp-artifacts",
        "arn:aws:s3:::my-public-idp-artifacts/*",
      ]) if contains(s.Action, "s3:GetObject")
    ])
    error_message = "The S3 statement must be scoped to exactly the public artifacts bucket arn + '/*'."
  }

  # Exactly one S3 statement exists, confirming the assertion above is not
  # vacuously true.
  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.version_check_resolver[0].policy).Statement :
      s if contains(s.Action, "s3:GetObject")
    ]) == 1
    error_message = "There must be exactly one S3 (s3:GetObject) statement in the version-check role policy."
  }
}
