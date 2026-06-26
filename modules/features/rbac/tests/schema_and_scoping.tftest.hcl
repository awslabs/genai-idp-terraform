# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the RBAC submodule. Two checks:
#
#   * Schema directives: every RBAC-governed operation in the shipped AppSync
#     schema carries a server-side `@aws_auth(cognito_groups: [...])` directive,
#     so authorization is enforced server-side by AppSync rather than
#     client-side. Asserted STATICALLY against the read-only v0.5.12 snapshot
#     (`sources/nested/appsync/src/api/schema.graphql`) — the directives ship in
#     `sources/`, so RBAC's contribution is to make them enforceable, not to
#     inject SDL.
#
#   * Server-side scoping wiring: Reviewer document filtering and
#     `allowedConfigVersions` scoping are enforced server-side. The filtering
#     LOGIC ships in the snapshot's resolver Lambdas; RBAC's Terraform job is the
#     WIRING — the `USERS_TABLE_NAME` env var and the least-privilege Users-table
#     read path (GetItem/Query on the table + its `EmailIndex` GSI). This file
#     asserts that wiring via the module's `reviewer_filtering_*` outputs and the
#     feature-plugin `contract`. (`allowedConfigVersions` on the profile query is
#     verified statically in the schema run, since it is satisfied by the shipped
#     `User` type, not by injected SDL.)
#
# This file is COMPLEMENTARY to groups.tftest.hcl and
# role_least_privilege.tftest.hcl; it does not touch them. `terraform test` runs
# all three.

# =============================================================================
# Static schema-directive invariant
# =============================================================================
# The production RBAC module deliberately does NOT read the GraphQL schema, so
# this run targets a small test-only fixture (./schema_fixture) that loads the
# read-only shipped schema via `file()` and exposes it. All invariant assertions
# use `regexall(...)` against that text and live here for visibility. The fixture
# has no providers/resources, so no AWS mock is needed for this run.
run "schema_aws_auth_directive_invariant" {
  command = plan

  module {
    source = "./tests/schema_fixture"
  }

  # (a) The schema actually carries `@aws_auth(cognito_groups: [...])` directives
  # at all — the foundation of server-side RBAC enforcement.
  assert {
    condition     = length(regexall("@aws_auth\\(cognito_groups:\\s*\\[", output.schema)) > 0
    error_message = "The shipped schema must carry @aws_auth(cognito_groups: [...]) directives for server-side RBAC enforcement."
  }

  # Each RBAC-governed user-management mutation carries the Admin-only directive
  # IMMEDIATELY after its signature (only whitespace between the return type and
  # `@aws_auth`), so the directive is genuinely ATTACHED to that operation and
  # the match cannot bleed onto a later operation's directive. This is the
  # "no RBAC-governed user-management operation lacks the directive" assertion:
  # exactly one attached-directive match per operation.
  assert {
    condition     = length(regexall("createUser\\([^)]*\\):\\s*User\\s+@aws_auth\\(cognito_groups:\\s*\\[\"Admin\"\\]\\)", output.schema)) == 1
    error_message = "createUser must carry an attached @aws_auth(cognito_groups: [\"Admin\"]) directive."
  }
  assert {
    condition     = length(regexall("updateUser\\([^)]*\\):\\s*User\\s+@aws_auth\\(cognito_groups:\\s*\\[\"Admin\"\\]\\)", output.schema)) == 1
    error_message = "updateUser must carry an attached @aws_auth(cognito_groups: [\"Admin\"]) directive."
  }
  assert {
    condition     = length(regexall("deleteUser\\([^)]*\\):\\s*Boolean\\s+@aws_auth\\(cognito_groups:\\s*\\[\"Admin\"\\]\\)", output.schema)) == 1
    error_message = "deleteUser must carry an attached @aws_auth(cognito_groups: [\"Admin\"]) directive."
  }

  # Config-version deletion is Admin-only and RBAC-governed (config-version
  # governance) — assert its attached directive too.
  assert {
    condition     = length(regexall("deleteConfigVersion\\([^)]*\\):[^@]*\\s+@aws_auth\\(cognito_groups:\\s*\\[\"Admin\"\\]\\)", output.schema)) == 1
    error_message = "deleteConfigVersion must carry an attached @aws_auth(cognito_groups: [\"Admin\"]) directive."
  }

  # Admin+Author and Admin+Reviewer governed operations are present, proving the
  # role-to-operation mapping is server-side (not just Admin-only).
  assert {
    condition     = length(regexall("@aws_auth\\(cognito_groups:\\s*\\[\"Admin\",\\s*\"Author\"\\]\\)", output.schema)) > 0
    error_message = "Admin+Author governed operations must carry server-side @aws_auth directives."
  }
  assert {
    condition     = length(regexall("@aws_auth\\(cognito_groups:\\s*\\[\"Admin\",\\s*\"Reviewer\"\\]\\)", output.schema)) > 0
    error_message = "Admin+Reviewer (HITL) governed operations must carry server-side @aws_auth directives."
  }

  # (b) The profile query exposes `allowedConfigVersions` so the web UI can
  # reflect scoping. `getMyProfile: User` returns the `User` type, which
  # declares `allowedConfigVersions: [String]`. Both are asserted against the
  # shipped schema (no SDL injection by RBAC).
  assert {
    condition     = length(regexall("type\\s+User\\s+@aws_cognito_user_pools", output.schema)) == 1
    error_message = "The shipped schema must declare the `User` type."
  }
  assert {
    condition     = length(regexall("allowedConfigVersions:\\s*\\[String\\]", output.schema)) > 0
    error_message = "The `User` type must expose `allowedConfigVersions` so the profile query reflects config-version scoping."
  }
  assert {
    condition     = length(regexall("getMyProfile:\\s*User", output.schema)) == 1
    error_message = "The schema must expose `getMyProfile: User` so callers can read their `allowedConfigVersions`."
  }
}

# =============================================================================
# Server-side scoping wiring
# =============================================================================
# The document-list and configuration AppSync resolver Lambdas ship the
# server-side Reviewer-filtering / `allowedConfigVersions`-scoping logic; they
# read `USERS_TABLE_NAME` and query the Users table by email via
# `IndexName="EmailIndex"`. RBAC's job is to give those Lambdas the env var and
# the least-privilege Users-table read path. This run asserts that wiring on the
# real RBAC module via its `reviewer_filtering_*` outputs and the `contract`.
#
# `command = apply` so the mock provider materializes the computed Users-table
# ARN that the IAM statements scope to (the same pattern as
# role_least_privilege.tftest.hcl). The Lambda validates its role ARN, so the
# IAM role's `arn` is mocked to a well-formed value.
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

run "reviewer_filtering_env_carries_users_table" {
  command = apply

  # The env fragment merged onto the resolver Lambdas carries exactly
  # `USERS_TABLE_NAME`, pointing at the Users table, so the shipped resolvers can
  # resolve the table at runtime to apply server-side scoping.
  assert {
    condition     = output.reviewer_filtering_environment["USERS_TABLE_NAME"] == aws_dynamodb_table.users.name
    error_message = "reviewer_filtering_environment must carry USERS_TABLE_NAME pointing at the Users table."
  }

  # The same env fragment must flow through the feature-plugin contract so the
  # API module merges it onto the resolver Lambdas (mirrors CDK enableInApi()).
  assert {
    condition     = output.contract.environment["USERS_TABLE_NAME"] == aws_dynamodb_table.users.name
    error_message = "The contract's environment must carry USERS_TABLE_NAME so the API module wires it onto the resolver Lambdas."
  }
}

run "reviewer_filtering_iam_grants_users_read_path" {
  command = apply

  # Exactly one filtering read statement is emitted when the table is
  # unencrypted (no KMS statement), and it is the Users-table read path.
  assert {
    condition = one([
      for s in output.reviewer_filtering_iam_statements :
      s.Sid if s.Sid == "RbacUsersTableReadForFiltering"
    ]) == "RbacUsersTableReadForFiltering"
    error_message = "reviewer_filtering_iam_statements must include the Users-table read statement (RbacUsersTableReadForFiltering)."
  }

  # That statement grants dynamodb:GetItem and dynamodb:Query — the read path the
  # shipped resolvers use to look the caller up by email and read back
  # `allowedConfigVersions`.
  assert {
    condition = alltrue([
      for s in output.reviewer_filtering_iam_statements :
      contains(s.Action, "dynamodb:GetItem") && contains(s.Action, "dynamodb:Query")
      if s.Sid == "RbacUsersTableReadForFiltering"
    ])
    error_message = "The filtering read statement must grant dynamodb:GetItem and dynamodb:Query on the Users table."
  }

  # The statement is scoped to exactly the Users table ARN and its EmailIndex
  # GSI (the resolvers query `IndexName=\"EmailIndex\"`) — never broader.
  assert {
    condition = one([
      for s in output.reviewer_filtering_iam_statements :
      s.Resource[0] if s.Sid == "RbacUsersTableReadForFiltering"
    ]) == aws_dynamodb_table.users.arn
    error_message = "The filtering read statement must be scoped to exactly the Users table ARN."
  }
  assert {
    condition = one([
      for s in output.reviewer_filtering_iam_statements :
      s.Resource[1] if s.Sid == "RbacUsersTableReadForFiltering"
    ]) == "${aws_dynamodb_table.users.arn}/index/EmailIndex"
    error_message = "The filtering read statement must additionally scope to the Users table's EmailIndex GSI."
  }

  # No statement in the filtering read path may use a wildcard ("*") resource.
  assert {
    condition = alltrue(flatten([
      for s in output.reviewer_filtering_iam_statements :
      [for r in s.Resource : r != "*"]
    ]))
    error_message = "The reviewer-filtering read path must not include a wildcard ('*') resource."
  }

  # The same least-privilege read path must flow through the feature-plugin
  # contract's iam_statements so the API module merges it onto the resolver
  # Lambda role (server-side enforcement wiring).
  assert {
    condition = one([
      for s in output.contract.iam_statements :
      s.Resource[0] if s.Sid == "RbacUsersTableReadForFiltering"
    ]) == aws_dynamodb_table.users.arn
    error_message = "The contract's iam_statements must carry the Users-table read path scoped to the Users table ARN."
  }
}
