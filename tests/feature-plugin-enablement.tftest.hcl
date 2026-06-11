# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the root feature-plugin enablement wiring
# (task 6.4 — features.tf `local.feature_enable` + the count-gated
# `module.mcp_integration` / `module.chat_with_document` + the
# `local.enabled_feature_contracts` composition map).
#
# Property 5 (Requirements 3.3, 3.4): an auxiliary feature's resources appear in
# the rendered configuration if and only if it is enabled via the plugin path or
# a forwarded `var.api.*` flag; otherwise the feature submodule contributes no
# resources (default-off). Asserted here against:
#   * module counts        — length(module.mcp_integration) / chat_with_document
#   * the composition map   — keys(local.enabled_feature_contracts)
#
# Forwarded flags exercised (confirmed against features.tf `feature_enable`):
#   * MCP  : var.api.enable_mcp                  -> module.mcp_integration
#   * chat : var.api.chat_with_document.enabled  -> module.chat_with_document
#
# `terraform test` run-block assertions can reference `local.*` and module
# instances directly (in addition to `output.*`), so the count/map assertions
# read the real plan state without needing dedicated test-only outputs.
#
# Offline harness:
#   * aws/awscc providers mocked; mock_data supplies real partition/region/
#     account so AWS ARN-partition validation passes. The root requires an
#     `aws.us-east-1` provider alias (web-ui) — supplied as a second aliased mock.
#   * random_string.suffix pinned at PLAN time (override_during = plan) so
#     resource names embedding the suffix are known at plan (see task 4.4 note).
#   * The chat feature reads AppSync ids from `module.processing_environment_api`
#     (requires api.enabled = true). That module has `data "archive_file"`
#     resources pointing at `sources/src/lambda/{abort_workflow_resolver,
#     sync_bda_idp_resolver}` whose real location in the v0.5.12 snapshot is
#     `sources/nested/appsync/src/lambda/...` — a PRE-EXISTING source-path issue
#     in `processing-environment-api` (OUT OF SCOPE for tasks 4.4/6.4, which own
#     only the root tests). To keep this a faithful ROOT-level feature-wiring
#     test (and avoid editing an out-of-scope module), the API module is replaced
#     with `override_module`, supplying only the three AppSync outputs the chat
#     submodule consumes. This isolates the assertion to the root feature-plugin
#     wiring (the subject of Property 5) rather than the API module internals.
#
# Validates: Requirements 3.4, Property 5

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

# Replace the API module with its AppSync outputs only (see header note): keeps
# the chat case a root-level feature-wiring assertion and sidesteps the
# pre-existing out-of-scope source-path issue in processing-environment-api.
override_module {
  target = module.processing_environment_api
  outputs = {
    api_id      = "testapiid"
    api_arn     = "arn:aws:appsync:us-east-1:123456789012:apis/testapiid"
    graphql_url = "https://testapiid.appsync-api.us-east-1.amazonaws.com/graphql"
  }
}

variables {
  region             = "us-east-1"
  input_bucket_arn   = "arn:aws:s3:::idp-test-input"
  output_bucket_arn  = "arn:aws:s3:::idp-test-output"
  working_bucket_arn = "arn:aws:s3:::idp-test-working"
  encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-1234-1234-1234-123456789012"

  web_ui = { enabled = false }

  # MCP requires a Cognito user pool; chat + api.enabled require the
  # authenticated-user IAM role. Supply a full external user identity.
  user_identity = {
    user_pool_arn          = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_TESTPOOL"
    user_pool_client_id    = "testclientid"
    identity_pool_id       = "us-east-1:11111111-1111-1111-1111-111111111111"
    authenticated_role_arn = "arn:aws:iam::123456789012:role/test-authenticated-role"
  }

  # Exactly one processor (validation gate). Config carries a `chat:` block so
  # the chat submodule's effective-config resolution succeeds when enabled.
  bedrock_llm_processor = {
    config = {
      classification = { model = "us.amazon.nova-lite-v1:0" }
      extraction     = { model = "us.amazon.nova-lite-v1:0" }
      chat = {
        model         = "us.anthropic.claude-opus-4-7:1m"
        system_prompt = "You are a helpful assistant."
        temperature   = 0.0
        max_tokens    = 4096
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Default-off: no forwarded flag set → no feature modules, empty contract map.
# ---------------------------------------------------------------------------
run "all_features_off_by_default" {
  command = plan

  variables {
    api = { enabled = false }
  }

  assert {
    condition     = length(module.mcp_integration) == 0
    error_message = "MCP submodule must NOT be instantiated when no flag enables it (default-off)."
  }
  assert {
    condition     = length(module.chat_with_document) == 0
    error_message = "Chat submodule must NOT be instantiated when no flag enables it (default-off)."
  }
  assert {
    condition     = length(keys(local.enabled_feature_contracts)) == 0
    error_message = "enabled_feature_contracts must be empty ({}) when no feature is enabled."
  }
}

# ---------------------------------------------------------------------------
# MCP on via forwarded var.api.enable_mcp → module instantiated + in contract map.
# (MCP is independent of the AppSync API; api.enabled stays false here.)
# ---------------------------------------------------------------------------
run "mcp_enabled_via_forwarded_flag" {
  command = plan

  variables {
    api = {
      enabled    = false
      enable_mcp = true
    }
  }

  assert {
    condition     = local.feature_enable.mcp == true
    error_message = "var.api.enable_mcp = true must forward to feature_enable.mcp."
  }
  assert {
    condition     = length(module.mcp_integration) == 1
    error_message = "MCP submodule must be instantiated when var.api.enable_mcp = true."
  }
  assert {
    condition     = contains(keys(local.enabled_feature_contracts), "mcp")
    error_message = "MCP contract must be present in enabled_feature_contracts when enabled."
  }
  # Chat stays off — only MCP was enabled.
  assert {
    condition     = length(module.chat_with_document) == 0
    error_message = "Chat submodule must remain absent when only MCP is enabled."
  }
  assert {
    condition     = !contains(keys(local.enabled_feature_contracts), "chat_with_document")
    error_message = "Chat contract must be absent when only MCP is enabled."
  }
}

# ---------------------------------------------------------------------------
# Chat on via forwarded var.api.chat_with_document.enabled → module instantiated.
# ---------------------------------------------------------------------------
run "chat_enabled_via_forwarded_flag" {
  command = plan

  variables {
    api = {
      enabled            = true
      chat_with_document = { enabled = true }
    }
  }

  assert {
    condition     = local.feature_enable.chat_with_document == true
    error_message = "var.api.chat_with_document.enabled = true must forward to feature_enable.chat_with_document."
  }
  assert {
    condition     = length(module.chat_with_document) == 1
    error_message = "Chat submodule must be instantiated when var.api.chat_with_document.enabled = true."
  }
  assert {
    condition     = contains(keys(local.enabled_feature_contracts), "chat_with_document")
    error_message = "Chat contract must be present in enabled_feature_contracts when enabled."
  }
  # MCP stays off — only chat was enabled.
  assert {
    condition     = length(module.mcp_integration) == 0
    error_message = "MCP submodule must remain absent when only chat is enabled."
  }
}
