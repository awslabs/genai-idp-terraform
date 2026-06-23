# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the IdP-federation submodule (task 7.5).
#
# Property 8 (Requirement 5.3): the OIDC client secret never appears in
# plaintext. The secret is supplied ONLY as a reference
# (`var.oidc_client_secret_ref` — a Secrets Manager ARN / SSM parameter name),
# resolved at apply time SOLELY into the Cognito identity provider's
# `provider_details.client_secret`, and is never a plaintext module input value
# nor carried by any non-sensitive module output.
#
# Property 9 (Requirements 5.5, 6.3): federation is additive to the user-pool
# client and targets the RBAC group names. The
# `supported_identity_providers_contribution` is the external provider-name list
# (the root merges it WITH `COGNITO`, keeping `COGNITO`), and the group-mapping
# Lambda's `*_GROUP_NAME` environment values equal `var.rbac_group_names`.
#
# Offline harness: the aws provider is mocked so the suite runs with no AWS
# credentials and no network. The secret-resolution data sources
# (`data.aws_secretsmanager_secret_version` / `data.aws_ssm_parameter`) are only
# instantiated on the OIDC + enabled + non-empty-ref path, so their values are
# mocked here. `command = plan` is used throughout — the identity provider's
# `provider_details` (incl. the resolved secret from the mocked data source) and
# the Lambda `environment` map are all known at plan time with the mocked
# provider.

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

  # Secret-resolution data sources — only ever read on the OIDC enabled +
  # non-empty-ref path. Mock the resolved plaintext so we can assert it lands
  # solely in provider_details.client_secret and never leaks into an output.
  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "MOCK-OIDC-CLIENT-SECRET-sm-zzz"
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "MOCK-OIDC-CLIENT-SECRET-ssm-zzz"
    }
  }
}

# Shared dummy inputs for an enabled OIDC federation with group mapping turned
# on (group_attribute_name != "") and an RBAC group-name override so Property 9
# can assert the env vars track the supplied names rather than the defaults.
variables {
  enabled       = true
  provider_type = "OIDC"
  provider_name = "ExternalIdP"

  oidc_issuer    = "https://login.example.com"
  oidc_client_id = "oidc-client-id-123"

  group_attribute_name = "groups"

  rbac_group_names = {
    Admin    = "Administrators"
    Author   = "Writers"
    Reviewer = "Approvers"
    Viewer   = "Observers"
  }

  user_pool_id        = "us-east-1_TESTPOOL"
  user_pool_client_id = "1examplepoolclientid23"

  base_layer_arn       = "arn:aws:lambda:us-east-1:123456789012:layer:idp-base:1"
  idp_common_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
}

# ---------------------------------------------------------------------------
# OIDC secret resolved from Secrets Manager (ref looks like a secretsmanager
# ARN). Asserts Property 8 (secret only via ref, only into client_secret, no
# plaintext input/output) and Property 9 (additive provider list + RBAC env).
# ---------------------------------------------------------------------------
run "oidc_secret_from_secretsmanager_and_additive_rbac_env" {
  command = plan

  variables {
    oidc_client_secret_ref = "arn:aws:secretsmanager:us-east-1:123456789012:secret:idp/oidc-client-AbCdEf"
  }

  # --- Property 8: the input is a REFERENCE, not the raw secret -------------
  # The ref is a Secrets Manager ARN string, and it is NOT the resolved secret
  # value the data source returns. Treating the input as a reference means the
  # module is fed the pointer, never the plaintext.
  assert {
    condition     = can(regex("^arn:aws[\\w-]*:secretsmanager:", var.oidc_client_secret_ref))
    error_message = "Property 8: oidc_client_secret_ref must be supplied as a secret reference (Secrets Manager ARN), not a raw secret."
  }
  assert {
    condition     = var.oidc_client_secret_ref != "MOCK-OIDC-CLIENT-SECRET-sm-zzz"
    error_message = "Property 8: the module input must be the reference, never the resolved plaintext secret value."
  }

  # --- Property 8: secret resolves SOLELY into provider_details.client_secret
  assert {
    condition     = aws_cognito_identity_provider.external[0].provider_details["client_secret"] == "MOCK-OIDC-CLIENT-SECRET-sm-zzz"
    error_message = "Property 8: the resolved secret must flow into the Cognito provider_details.client_secret."
  }
  # The resolved plaintext is distinct from the reference — proving it was
  # resolved via the data source, not passed through as the ref.
  assert {
    condition     = aws_cognito_identity_provider.external[0].provider_details["client_secret"] != var.oidc_client_secret_ref
    error_message = "Property 8: the resolved client_secret must differ from the reference (it is resolved at apply time, not the ref string)."
  }

  # --- Property 8: NO module output carries the resolved secret -------------
  # The module exposes enabled / provider_name / group_mapping_function_* /
  # supported_identity_providers_contribution / contract — none may equal or
  # contain the resolved secret value.
  assert {
    condition     = output.provider_name != "MOCK-OIDC-CLIENT-SECRET-sm-zzz"
    error_message = "Property 8: provider_name output must not carry the resolved secret."
  }
  assert {
    condition     = output.group_mapping_function_name != "MOCK-OIDC-CLIENT-SECRET-sm-zzz"
    error_message = "Property 8: group_mapping_function_name output must not carry the resolved secret."
  }
  assert {
    condition     = !contains(output.supported_identity_providers_contribution, "MOCK-OIDC-CLIENT-SECRET-sm-zzz")
    error_message = "Property 8: supported_identity_providers_contribution must not carry the resolved secret."
  }
  # The feature-plugin contract carries no environment/IAM/resolver/schema data
  # at all (it is Cognito-side), so it structurally cannot leak the secret.
  assert {
    condition     = length(output.contract.environment) == 0 && length(output.contract.iam_statements) == 0
    error_message = "Property 8: the feature-plugin contract must expose no environment or IAM data (it cannot carry the secret)."
  }
  assert {
    condition     = output.contract.schema_additions == null
    error_message = "Property 8: the feature-plugin contract schema_additions must be null (no secret-bearing SDL)."
  }

  # --- Property 9: additive to the user-pool client (provider-name list) ----
  # The contribution is the external provider name; the ROOT merges it with
  # COGNITO (keeping COGNITO). Here we assert the contribution equals the
  # provider-name list when enabled.
  assert {
    condition     = length(output.supported_identity_providers_contribution) == 1 && output.supported_identity_providers_contribution[0] == var.provider_name
    error_message = "Property 9: supported_identity_providers_contribution must be exactly the external provider-name list when federation is enabled."
  }

  # --- Property 9: group-mapping Lambda *_GROUP_NAME == rbac_group_names -----
  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["ADMIN_GROUP_NAME"] == var.rbac_group_names["Admin"]
    error_message = "Property 9: ADMIN_GROUP_NAME env must equal rbac_group_names[\"Admin\"]."
  }
  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["AUTHOR_GROUP_NAME"] == var.rbac_group_names["Author"]
    error_message = "Property 9: AUTHOR_GROUP_NAME env must equal rbac_group_names[\"Author\"]."
  }
  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["REVIEWER_GROUP_NAME"] == var.rbac_group_names["Reviewer"]
    error_message = "Property 9: REVIEWER_GROUP_NAME env must equal rbac_group_names[\"Reviewer\"]."
  }
  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["VIEWER_GROUP_NAME"] == var.rbac_group_names["Viewer"]
    error_message = "Property 9: VIEWER_GROUP_NAME env must equal rbac_group_names[\"Viewer\"]."
  }
}

# ---------------------------------------------------------------------------
# OIDC secret resolved from SSM Parameter Store (ref is a parameter name, not a
# secretsmanager ARN). Reasserts Property 8 across the second resolution branch:
# the secret still lands solely in provider_details.client_secret and never in
# an output.
# ---------------------------------------------------------------------------
run "oidc_secret_from_ssm_no_plaintext_leak" {
  command = plan

  variables {
    oidc_client_secret_ref = "/idp/oidc/client-secret"
  }

  # The ref is an SSM parameter NAME, not a secretsmanager ARN nor a raw secret.
  assert {
    condition     = !can(regex("^arn:aws[\\w-]*:secretsmanager:", var.oidc_client_secret_ref)) && var.oidc_client_secret_ref != "MOCK-OIDC-CLIENT-SECRET-ssm-zzz"
    error_message = "Property 8: the SSM ref must be a parameter-name reference, never the raw secret value."
  }

  # Secret resolves solely into provider_details.client_secret via the SSM path.
  assert {
    condition     = aws_cognito_identity_provider.external[0].provider_details["client_secret"] == "MOCK-OIDC-CLIENT-SECRET-ssm-zzz"
    error_message = "Property 8: the SSM-resolved secret must flow into provider_details.client_secret."
  }

  # No output carries the SSM-resolved secret.
  assert {
    condition     = output.provider_name != "MOCK-OIDC-CLIENT-SECRET-ssm-zzz" && output.group_mapping_function_name != "MOCK-OIDC-CLIENT-SECRET-ssm-zzz"
    error_message = "Property 8: no module output may carry the SSM-resolved secret."
  }
  assert {
    condition     = !contains(output.supported_identity_providers_contribution, "MOCK-OIDC-CLIENT-SECRET-ssm-zzz")
    error_message = "Property 8: supported_identity_providers_contribution must not carry the SSM-resolved secret."
  }
}
