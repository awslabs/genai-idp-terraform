# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the Round 2 root RBAC + IdP-federation feature
# wiring (task 8.3 — features.tf `local.feature_enable.{rbac,federation}`, the
# count-gated `module.rbac` / `module.idp_federation`, the
# `local.enabled_feature_contracts` merge, and the `check "rbac_requires_cognito"`
# block).
#
# This file is the RBAC/federation analog of feature-plugin-enablement.tftest.hcl
# (which covers MCP/Chat) — it reuses that file's offline harness exactly and is
# a SEPARATE file so it does not clobber the existing one.
#
# Properties asserted (Validates: Requirements 1.2, 1.6, 4.2, 4.4, 5.6):
#
#   * Property 1 — Feature plugin present iff enabled (RBAC + federation
#     default-off). Default (no var.rbac / var.idp_federation) →
#     length(module.rbac) == 0, length(module.idp_federation) == 0, and neither
#     "rbac" nor "federation" appears in keys(local.enabled_feature_contracts).
#     RBAC on WITH Cognito → module.rbac instantiated + "rbac" in the contract
#     map; federation on → module.idp_federation instantiated + "federation" in
#     the contract map. (Req 1.2, 1.6, 4.2, 5.6)
#
#   * Property 7 — RBAC without Cognito fails at plan time. var.rbac.enabled =
#     true with NO Cognito (no var.user_identity, api/web_ui off ⇒
#     local.user_pool_id == null) ⇒ the root `check "rbac_requires_cognito"`
#     reports a failure during `command = plan`. (Req 4.4)
#
#   * Property 4 — Multi-group membership grants the union of permissions.
#     PLAN-TIME PROVABLE PORTION ONLY: assert module.rbac creates exactly the
#     four Cognito groups Admin/Author/Reviewer/Viewer (the groups the shipped
#     `@aws_auth(cognito_groups: […])` directives resolve against), with the
#     default-or-override names. The RUNTIME union-of-permissions semantics are
#     AppSync-enforced (a caller in a subset of groups receives the union of
#     those groups' directives) and are validated via the deployed integration
#     examples per the tasks.md PBT-framing note — NOT at plan time, since
#     AppSync directive evaluation is not a plannable Terraform value.
#
# check{}-vs-expect_failures note (same mechanism as exactly-one-processor and
# private-endpoint-gap tftests): a `check {}` assertion failure is only a plan
# *warning* in a normal plan, but `terraform test`'s
# `expect_failures = [check.<name>]` is the first-class way to assert a check
# failed during `command = plan` — the run PASSES iff the named check reported a
# failure. Property 7 is asserted that way; the passing cases assert clean
# module counts / contract-map keys / group names.
#
# Offline harness (identical to feature-plugin-enablement.tftest.hcl): aws +
# an aliased aws.us-east-1 provider are mocked (mock_data supplies real
# partition/region/account so AWS ARN-partition validation passes); awscc is
# mocked; the archive provider zips the user-management / group-mapping Lambda
# sources from the read-only `sources/` snapshot for real; random_string.suffix
# is pinned at plan so suffix-embedded resource names are known at plan. web_ui
# and api stay disabled so the only validations in play are the processor gate
# and the RBAC-requires-Cognito check — RBAC and federation modules do not
# consume `module.processing_environment_api`, so this stays a faithful
# ROOT-level feature-wiring test (no override_module needed for the API module).
#
# Validates: Requirements 1.2, 1.6, 4.2, 4.4, 5.6

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

mock_provider "aws" {
  alias = "us-east-1"
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

mock_provider "awscc" {}

# Pin the random suffix at plan time so suffix-embedded resource names resolve
# (the SageMaker hook-count path and others are unknown-at-plan otherwise).
override_resource {
  target          = random_string.suffix
  override_during = plan
  values = {
    result = "testsuf1"
  }
}

# Shared inputs. web_ui + api disabled, exactly one processor configured so the
# only validations exercised are the processor gate and the RBAC-requires-Cognito
# check. The RBAC/federation submodules read the processing_environment tables +
# layers (always created), not the API module.
variables {
  region             = "us-east-1"
  input_bucket_arn   = "arn:aws:s3:::idp-test-input"
  output_bucket_arn  = "arn:aws:s3:::idp-test-output"
  working_bucket_arn = "arn:aws:s3:::idp-test-working"
  encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-1234-1234-1234-123456789012"

  web_ui = { enabled = false }

  bedrock_llm_processor = {
    config = {
      classification = { model = "us.amazon.nova-lite-v1:0" }
      extraction     = { model = "us.amazon.nova-lite-v1:0" }
    }
  }
}

# A full external Cognito user identity, supplied to the runs that need
# local.user_pool_id != null (RBAC on / federation on). Defined as a reusable
# block per-run below.

# ---------------------------------------------------------------------------
# Property 1 (default-off): no var.rbac / var.idp_federation set → neither
# feature module is instantiated and neither contract is in the merge map. This
# preserves the pre-Round-2 single-tenant auth behavior (Req 1.6, 5.6).
# ---------------------------------------------------------------------------
run "rbac_and_federation_off_by_default" {
  command = plan

  variables {
    api = { enabled = false }
  }

  assert {
    condition     = local.feature_enable.rbac == false
    error_message = "feature_enable.rbac must default to false when var.rbac is unset."
  }
  assert {
    condition     = local.feature_enable.federation == false
    error_message = "feature_enable.federation must default to false when var.idp_federation is unset."
  }
  assert {
    condition     = length(module.rbac) == 0
    error_message = "RBAC submodule must NOT be instantiated when RBAC is disabled (default-off, Req 1.6)."
  }
  assert {
    condition     = length(module.idp_federation) == 0
    error_message = "Federation submodule must NOT be instantiated when federation is disabled (default-off, Req 5.6)."
  }
  assert {
    condition     = !contains(keys(local.enabled_feature_contracts), "rbac")
    error_message = "rbac contract must be ABSENT from enabled_feature_contracts when RBAC is disabled."
  }
  assert {
    condition     = !contains(keys(local.enabled_feature_contracts), "federation")
    error_message = "federation contract must be ABSENT from enabled_feature_contracts when federation is disabled."
  }
}

# ---------------------------------------------------------------------------
# Property 1 (RBAC on WITH Cognito) + Property 4 (four groups, default names):
# var.rbac.enabled = true and a Cognito user pool present (local.user_pool_id !=
# null) → module.rbac instantiated, "rbac" in the contract map; federation stays
# off. The RBAC submodule's resolved group_names map carries exactly the four
# canonical roles — the plan-time-provable portion of Property 4.
# ---------------------------------------------------------------------------
run "rbac_enabled_with_cognito_present" {
  command = plan

  variables {
    api = { enabled = false }

    user_identity = {
      user_pool_arn          = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_TESTPOOL"
      user_pool_client_id    = "testclientid"
      identity_pool_id       = "us-east-1:11111111-1111-1111-1111-111111111111"
      authenticated_role_arn = "arn:aws:iam::123456789012:role/test-authenticated-role"
    }

    rbac = { enabled = true }
  }

  # Cognito present ⇒ the RBAC-requires-Cognito check holds (no expect_failures).
  assert {
    condition     = local.user_pool_id != null
    error_message = "A Cognito user pool must be derived from var.user_identity for the RBAC-on case."
  }
  assert {
    condition     = local.feature_enable.rbac == true
    error_message = "var.rbac.enabled = true must forward to feature_enable.rbac."
  }
  assert {
    condition     = length(module.rbac) == 1
    error_message = "RBAC submodule must be instantiated when var.rbac.enabled = true (Req 4.2)."
  }
  assert {
    condition     = contains(keys(local.enabled_feature_contracts), "rbac")
    error_message = "rbac contract must be present in enabled_feature_contracts when RBAC is enabled (Req 4.2)."
  }
  # Federation stays off — only RBAC was enabled.
  assert {
    condition     = length(module.idp_federation) == 0
    error_message = "Federation submodule must remain absent when only RBAC is enabled."
  }
  assert {
    condition     = !contains(keys(local.enabled_feature_contracts), "federation")
    error_message = "federation contract must be absent when only RBAC is enabled."
  }

  # Property 4 (plan-time portion): exactly the four Cognito groups, default
  # names. group_names is keyed by canonical role and sourced from the four
  # aws_cognito_user_group resources, so this proves exactly four groups exist.
  assert {
    condition     = length(keys(module.rbac[0].group_names)) == 4
    error_message = "RBAC must create exactly four Cognito groups (Admin/Author/Reviewer/Viewer)."
  }
  assert {
    condition = (
      contains(keys(module.rbac[0].group_names), "Admin") &&
      contains(keys(module.rbac[0].group_names), "Author") &&
      contains(keys(module.rbac[0].group_names), "Reviewer") &&
      contains(keys(module.rbac[0].group_names), "Viewer")
    )
    error_message = "RBAC group set must be exactly {Admin, Author, Reviewer, Viewer}."
  }
  assert {
    condition = (
      module.rbac[0].group_names["Admin"] == "Admin" &&
      module.rbac[0].group_names["Author"] == "Author" &&
      module.rbac[0].group_names["Reviewer"] == "Reviewer" &&
      module.rbac[0].group_names["Viewer"] == "Viewer"
    )
    error_message = "RBAC group names must default to Admin/Author/Reviewer/Viewer."
  }
}

# ---------------------------------------------------------------------------
# Property 4 (override names): a group_names override renames the four groups
# but still creates exactly four — the default-on behavior of the four roles is
# unchanged (Req 1.5), only the names differ.
# ---------------------------------------------------------------------------
run "rbac_group_name_overrides_still_four_groups" {
  command = plan

  variables {
    api = { enabled = false }

    user_identity = {
      user_pool_arn          = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_TESTPOOL"
      user_pool_client_id    = "testclientid"
      identity_pool_id       = "us-east-1:11111111-1111-1111-1111-111111111111"
      authenticated_role_arn = "arn:aws:iam::123456789012:role/test-authenticated-role"
    }

    rbac = {
      enabled = true
      group_names = {
        admin    = "Administrators"
        author   = "Authors"
        reviewer = "Reviewers"
        viewer   = "Viewers"
      }
    }
  }

  assert {
    condition     = length(keys(module.rbac[0].group_names)) == 4
    error_message = "RBAC must still create exactly four Cognito groups when names are overridden."
  }
  assert {
    condition = (
      module.rbac[0].group_names["Admin"] == "Administrators" &&
      module.rbac[0].group_names["Author"] == "Authors" &&
      module.rbac[0].group_names["Reviewer"] == "Reviewers" &&
      module.rbac[0].group_names["Viewer"] == "Viewers"
    )
    error_message = "Overridden RBAC group names must be reflected on the four groups (Req 1.5)."
  }
}

# ---------------------------------------------------------------------------
# Property 1 (federation on WITH Cognito): var.idp_federation.enabled = true →
# module.idp_federation instantiated, "federation" in the contract map. RBAC
# stays off here, demonstrating the two plugins toggle independently (Req 6.2,
# 5.6). Federation always emits its contract; here it is composed because the
# feature is enabled.
# ---------------------------------------------------------------------------
run "federation_enabled_with_cognito_present" {
  command = plan

  variables {
    api = { enabled = false }

    user_identity = {
      user_pool_arn          = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_TESTPOOL"
      user_pool_client_id    = "testclientid"
      identity_pool_id       = "us-east-1:11111111-1111-1111-1111-111111111111"
      authenticated_role_arn = "arn:aws:iam::123456789012:role/test-authenticated-role"
    }

    idp_federation = {
      enabled           = true
      provider_type     = "SAML"
      provider_name     = "ExternalIdP"
      saml_metadata_url = "https://idp.example.com/metadata.xml"
    }
  }

  assert {
    condition     = local.feature_enable.federation == true
    error_message = "var.idp_federation.enabled = true must forward to feature_enable.federation."
  }
  assert {
    condition     = length(module.idp_federation) == 1
    error_message = "Federation submodule must be instantiated when var.idp_federation.enabled = true (Req 6.2)."
  }
  assert {
    condition     = contains(keys(local.enabled_feature_contracts), "federation")
    error_message = "federation contract must be present in enabled_feature_contracts when federation is enabled."
  }
  # RBAC stays off — only federation was enabled.
  assert {
    condition     = length(module.rbac) == 0
    error_message = "RBAC submodule must remain absent when only federation is enabled."
  }
  assert {
    condition     = !contains(keys(local.enabled_feature_contracts), "rbac")
    error_message = "rbac contract must be absent when only federation is enabled."
  }
}

# ---------------------------------------------------------------------------
# Property 7 (RBAC requires Cognito): var.rbac.enabled = true with NO Cognito
# (no var.user_identity; api + web_ui off ⇒ module.user_identity count = 0 ⇒
# local.user_pool_id == null). The root `check "rbac_requires_cognito"` must
# report a failure during plan — asserted via expect_failures (the first-class,
# faithful `terraform test` mechanism for a check{} firing at plan). (Req 4.4)
#
# Why module.rbac is replaced with override_module here:
#   With RBAC enabled, module.rbac is count-gated to one instance — and with no
#   Cognito user pool, var.user_pool_id is null, so the submodule's
#   aws_cognito_user_group resources raise *hard* resource errors ("user_pool_id
#   is required") during plan. Those hard errors would abort the run before
#   expect_failures can isolate the check, masking the very guard under test.
#   In a real deployment the operator sees BOTH the friendly check failure and
#   those module errors; this guard exists to surface the misconfiguration at
#   plan with an actionable message. Overriding module.rbac with mocked outputs
#   suppresses only the submodule-internal resource noise, leaving the ROOT
#   `check "rbac_requires_cognito"` to evaluate against the real
#   local.user_pool_id (null) and real var.rbac.enabled (true) and fire — which
#   is exactly what this property asserts. The override supplies the two outputs
#   the root consumes (`contract` into enabled_feature_contracts; `group_names`
#   referenced by the federation wiring path).
# ---------------------------------------------------------------------------
run "rbac_without_cognito_fails_at_plan" {
  command = plan

  override_module {
    target = module.rbac
    outputs = {
      contract = {
        enabled          = true
        resolvers        = {}
        iam_statements   = []
        environment      = {}
        schema_additions = null
      }
      group_names = {
        Admin    = "Admin"
        Author   = "Author"
        Reviewer = "Reviewer"
        Viewer   = "Viewer"
      }
    }
  }

  variables {
    api           = { enabled = false }
    user_identity = null

    rbac = { enabled = true }
  }

  # Sanity: the check predicate's two operands are exactly the misconfiguration
  # (RBAC on, no Cognito pool), so the check assertion's condition is false and
  # the guard fires.
  assert {
    condition     = local.feature_enable.rbac == true && local.user_pool_id == null
    error_message = "Property 7 scenario must be RBAC-enabled with no Cognito user pool (local.user_pool_id == null)."
  }

  expect_failures = [
    check.rbac_requires_cognito,
  ]
}
