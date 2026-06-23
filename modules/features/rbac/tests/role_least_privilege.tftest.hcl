# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the RBAC submodule — Property 5 (task 6.6): the
# user-management execution role is least-privilege.
#
# Property 5 (Requirement 2.4): the user-management role's inline policy grants
# NO wildcard ("*") resource on the Cognito-admin actions or the Users-table
# actions. The Cognito statement is scoped to exactly the supplied user-pool ARN
# and the DynamoDB statement is scoped to exactly the Users table ARN (+ its
# index), never "*".
#
# This file is COMPLEMENTARY to groups.tftest.hcl (Property 2 — four groups,
# default/override names), which it does not touch. `terraform test` runs both.
#
# Offline harness: the aws provider is mocked. The inline policy
# (`aws_iam_role_policy.user_management.policy`) is `jsonencode(...)` over the
# Users-table ARN, the log-group ARN, and the (input-derived) user-pool ARN.
# Because those resource ARNs are computed attributes, the runs use
# `command = apply` so the mock provider materializes them and the policy JSON
# is fully known for `jsondecode`-based assertions (per the testing guidance
# that computed ARNs require apply even when mocked).

# The Lambda resource validates that its execution-role ARN is a well-formed
# ARN. The default mock provider returns a random short string for computed
# attributes, which fails that validation on apply, so the IAM role's `arn` is
# overridden with a valid ARN. (The policy under test is unaffected — it is
# `jsonencode`d from the Users-table/log-group ARNs and the user-pool ARN.)
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/idp-test-user-management"
    }
  }
}

variables {
  name_prefix   = "idp-test"
  user_pool_id  = "us-east-1_TESTPOOL"
  user_pool_arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_TESTPOOL"
}

# ---------------------------------------------------------------------------
# Property 5: least-privilege user-management role — no wildcard resources.
# ---------------------------------------------------------------------------
run "user_management_role_is_least_privilege" {
  command = apply

  # No statement in the policy may use a bare "*" resource. Resource is either a
  # string (Logging, Cognito) or a list (Users table, KMS); a list compared to
  # the string "*" is unequal, so this catches a wildcard on any statement.
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      s.Resource != "*"
    ])
    error_message = "No user-management policy statement may use a wildcard ('*') resource."
  }

  # The Cognito-admin statement must be scoped to exactly the supplied user-pool
  # ARN (never "*", never broader).
  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      s.Resource if s.Sid == "CognitoGroupMembership"
    ]) == var.user_pool_arn
    error_message = "The Cognito-admin statement must be scoped to exactly the supplied user-pool ARN."
  }

  # The Cognito statement's resource is a single scalar ARN, not "*".
  assert {
    condition = !contains([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      tostring(s.Resource) if s.Sid == "CognitoGroupMembership"
    ], "*")
    error_message = "The Cognito-admin statement resource must not be a wildcard."
  }

  # The Users-table statement must target exactly the Users table ARN and its
  # index ARN — never "*". Comparing against the resource's own computed ARN
  # (same mock value) verifies the scoping is to the table, not a wildcard.
  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      s.Resource[0] if s.Sid == "UsersTableAccess"
    ]) == aws_dynamodb_table.users.arn
    error_message = "The Users-table statement must be scoped to exactly the Users table ARN."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      s.Resource[1] if s.Sid == "UsersTableAccess"
    ]) == "${aws_dynamodb_table.users.arn}/index/*"
    error_message = "The Users-table statement must additionally scope to the table's indexes (arn/index/*), not a bare wildcard."
  }

  # The Users-table statement resource list must contain no bare "*" entry.
  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      [for r in s.Resource : r != "*"] if s.Sid == "UsersTableAccess"
    ]))
    error_message = "The Users-table statement must not include a wildcard ('*') resource."
  }
}

# ---------------------------------------------------------------------------
# Property 5 holds under group-name overrides too: renaming groups changes only
# names, never the role's resource scoping.
# ---------------------------------------------------------------------------
run "least_privilege_preserved_under_overrides" {
  command = apply

  variables {
    group_names = {
      admin    = "Administrators"
      reviewer = "Approvers"
    }
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      s.Resource != "*"
    ])
    error_message = "Group-name overrides must not introduce a wildcard resource in the user-management policy."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.user_management.policy).Statement :
      s.Resource if s.Sid == "CognitoGroupMembership"
    ]) == var.user_pool_arn
    error_message = "Under overrides, the Cognito-admin statement must remain scoped to exactly the user-pool ARN."
  }
}
