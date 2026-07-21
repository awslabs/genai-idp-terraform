# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # External SAML/OIDC IdP Federation Feature Submodule
 *
 * Self-contained feature-plugin submodule that federates the Cognito user pool
 * with an external SAML or OIDC identity provider, mirroring the upstream
 * v0.5.6 `ExternalIdP*` surface (`sources/template.yaml`) and the CDK
 * federation construct. Emits the feature-plugin `contract` so the API module
 * composes it the same way as MCP/Chat (see outputs).
 *
 * What it provisions:
 *
 *   * The `aws_cognito_identity_provider` resource, selected by `provider_type`
 *     (SAML metadata vs OIDC issuer).
 *   * An OIDC client-secret resolver: `oidc_client_secret_ref` (Secrets Manager
 *     ARN / SSM parameter name) is resolved at apply time via a data source and
 *     fed into `local.oidc_client_secret`; the resolved plaintext flows ONLY
 *     into `provider_details.client_secret` and is never set as a module input
 *     value or non-sensitive output. The provider marks `secret_string` /
 *     `value` sensitive, so it does not leak into plan output.
 *   * A group-mapping Cognito trigger Lambda targeting the RBAC group names.
 *   * The additive user-pool-client update + the feature-plugin contract.
 *
 * Provider details mirror the upstream CFN `ExternalIdentityProvider`:
 *   * SAML uses `provider_details.MetadataURL` (or `MetadataFile`).
 *   * OIDC uses `client_id`, `client_secret`, `oidc_issuer`,
 *     `attributes_request_method = GET`, and `authorize_scopes`.
 */

locals {
  is_saml = var.provider_type == "SAML"
  is_oidc = var.provider_type == "OIDC"

  # ---------------------------------------------------------------------------
  # OIDC client-secret resolution.
  #
  # `var.oidc_client_secret_ref` is a *reference*, never the raw secret: either
  # a Secrets Manager secret ARN or an SSM parameter name. We resolve it at
  # apply time and assign the plaintext to `local.oidc_client_secret` below,
  # which is consumed ONLY by `provider_details.client_secret`. It is never set
  # as a module input value or surfaced as a non-sensitive output.
  #
  # Resolution is gated so the SAML / disabled / empty-ref paths resolve nothing
  # (and `local.oidc_client_secret` stays `""`):
  #   * enabled AND provider_type == OIDC AND ref is non-empty.
  # The reference is routed to Secrets Manager when it looks like a
  # secretsmanager ARN, otherwise treated as an SSM parameter name (with
  # decryption). The heuristic also tolerates partition variants (aws-us-gov,
  # aws-cn) via the `[\w-]*` segment.
  resolve_oidc_secret = var.enabled && local.is_oidc && var.oidc_client_secret_ref != ""

  ref_is_secretsmanager_arn = can(regex("^arn:aws[\\w-]*:secretsmanager:", var.oidc_client_secret_ref))

  use_secretsmanager = local.resolve_oidc_secret && local.ref_is_secretsmanager_arn
  use_ssm_parameter  = local.resolve_oidc_secret && !local.ref_is_secretsmanager_arn

  # Resolved plaintext, selected from whichever data source was activated.
  # `try(...)` keeps this `""` on every non-OIDC / disabled / empty-ref path,
  # where neither data source exists.
  oidc_client_secret = (
    local.use_secretsmanager ? try(data.aws_secretsmanager_secret_version.oidc_client_secret[0].secret_string, "") :
    local.use_ssm_parameter ? try(data.aws_ssm_parameter.oidc_client_secret[0].value, "") :
    ""
  )

  # ---------------------------------------------------------------------------
  # Cognito provider_details, selected by provider_type.
  # ---------------------------------------------------------------------------
  saml_provider_details = (
    var.saml_metadata_url != "" ?
    { MetadataURL = var.saml_metadata_url } :
    { MetadataFile = var.saml_metadata_file }
  )

  oidc_provider_details = {
    client_id                 = var.oidc_client_id
    client_secret             = local.oidc_client_secret
    oidc_issuer               = var.oidc_issuer
    attributes_request_method = "GET"
    authorize_scopes          = var.oidc_authorize_scopes
  }

  provider_details = local.is_saml ? local.saml_provider_details : local.oidc_provider_details

  # ---------------------------------------------------------------------------
  # Attribute mapping. When the caller supplies an explicit map it wins;
  # otherwise apply the upstream defaults for the selected provider type (SAML
  # claim URIs vs OIDC claim names). The group claim is mapped into the
  # `custom:idp_groups` attribute only when `group_attribute_name` is set.
  # ---------------------------------------------------------------------------
  default_attribute_mapping = local.is_saml ? {
    email       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    given_name  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
    family_name = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
    } : {
    email       = "email"
    given_name  = "given_name"
    family_name = "family_name"
  }

  group_attribute_mapping = var.group_attribute_name != "" ? {
    "custom:idp_groups" = var.group_attribute_name
  } : {}

  attribute_mapping = merge(
    length(var.attribute_mapping) > 0 ? var.attribute_mapping : local.default_attribute_mapping,
    local.group_attribute_mapping,
  )
}

# =============================================================================
# OIDC client-secret resolution
# =============================================================================
# Resolve the OIDC client secret from its reference at apply time. Exactly one
# of these data sources is activated when federation is an enabled OIDC provider
# with a non-empty ref; the SAML / disabled / empty-ref paths activate neither
# and `local.oidc_client_secret` stays "". The resolved plaintext flows ONLY
# into `local.oidc_client_secret` -> `provider_details.client_secret` and is
# never set as a module input value or emitted as a non-sensitive output.

# Secrets Manager: used when the ref looks like a secretsmanager secret ARN.
data "aws_secretsmanager_secret_version" "oidc_client_secret" {
  count = local.use_secretsmanager ? 1 : 0

  secret_id = var.oidc_client_secret_ref
}

# SSM Parameter Store: used when the ref is an SSM parameter name (anything that
# is not a secretsmanager ARN). `with_decryption` handles SecureString params.
data "aws_ssm_parameter" "oidc_client_secret" {
  count = local.use_ssm_parameter ? 1 : 0

  name            = var.oidc_client_secret_ref
  with_decryption = true
}

# =============================================================================
# External Cognito identity provider (SAML or OIDC)
# =============================================================================
# Mirrors upstream `ExternalIdentityProvider`
# (sources/template.yaml, AWS::Cognito::UserPoolIdentityProvider). Provisioned
# only when federation is enabled; otherwise the user pool keeps direct Cognito
# authentication.
resource "aws_cognito_identity_provider" "external" {
  count = var.enabled ? 1 : 0

  user_pool_id  = var.user_pool_id
  provider_name = var.provider_name
  provider_type = var.provider_type

  provider_details  = local.provider_details
  attribute_mapping = local.attribute_mapping
}

# =============================================================================
# Group-mapping Cognito trigger Lambda
# =============================================================================
# Mirrors upstream `ExternalIdPGroupMappingFunction` (sources/template.yaml,
# AWS::Serverless::Function, Condition ShouldMapExternalIdPGroups) and the
# vendored source `sources/src/lambda/external_idp_group_mapping/index.py`.
#
# The Lambda is a Cognito **pre-token-generation** trigger: on sign-in it reads
# the `custom:idp_groups` attribute (populated from the external IdP group claim
# via `local.attribute_mapping`), maps those external groups to the
# four IDP RBAC Cognito groups, syncs the user's group membership via the
# Cognito admin APIs, and injects the resolved groups into the token through
# `claimsAndScopeOverrideDetails.groupOverrideDetails` — which requires the
# V2_0 pre-token-generation trigger version when the user pool wires it.
#
# Provisioned only when federation is enabled AND a group attribute/claim is
# configured (`var.group_attribute_name != ""`), matching the upstream
# `ShouldMapExternalIdPGroups = HasExternalIdP AND group attr != ""` condition.
# With no group claim there is nothing to map, so the trigger is omitted.
#
# Pool ownership: the Cognito user pool is created and owned outside this module
# (passed in via `var.user_pool_id`). The actual trigger attachment lives on the
# `aws_cognito_user_pool` `lambda_config.pre_token_generation_config` of the
# owning module/root, which AWS could not co-locate with the Function here even
# upstream (the standalone Cognito IAM policy comment in template.yaml documents
# the UserPool -> LambdaConfig -> Function -> Role -> UserPool circular
# dependency). This submodule therefore provisions the Lambda + its scoped IAM +
# the Cognito invoke permission, and exposes the function ARN/name as outputs so
# the pool owner wires it as the `PreTokenGeneration` (V2_0) trigger. The
# `aws_lambda_permission` below pre-authorizes the `cognito-idp` principal so the
# trigger works as soon as the pool is wired.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Group mapping is only meaningful when federation is enabled and an external
  # group attribute/claim is configured to populate `custom:idp_groups`.
  enable_group_mapping = var.enabled && var.group_attribute_name != ""

  group_mapping_function_name = "${var.provider_name}-idp-group-mapping"

  # Derived user-pool ARN, mirroring the upstream
  # `!Sub "arn:${AWS::Partition}:cognito-idp:${AWS::Region}:${AWS::AccountId}:userpool/${UserPool}"`.
  # Avoids adding a separate user_pool_arn input — the id is sufficient.
  user_pool_arn = "arn:${data.aws_partition.current.partition}:cognito-idp:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:userpool/${var.user_pool_id}"

  # The four env keys read by index.py. Each is the external IdP group name that
  # maps to the corresponding hardcoded Cognito role; these are wired from the
  # RBAC group names so federated users land in the same groups the RBAC
  # submodule provisions.
  group_mapping_env = {
    LOG_LEVEL           = var.log_level
    ADMIN_GROUP_NAME    = lookup(var.rbac_group_names, "Admin", "Admin")
    AUTHOR_GROUP_NAME   = lookup(var.rbac_group_names, "Author", "Author")
    REVIEWER_GROUP_NAME = lookup(var.rbac_group_names, "Reviewer", "Reviewer")
    VIEWER_GROUP_NAME   = lookup(var.rbac_group_names, "Viewer", "Viewer")
  }

  # ---------------------------------------------------------------------------
  # Additive user-pool-client supported-identity-providers contribution.
  #
  # The Cognito user-pool client is owned OUTSIDE this module (passed in via
  # `var.user_pool_client_id`). `aws_cognito_user_pool_client` is a full
  # resource, not a patch-by-id surface, so this module cannot additively edit
  # the externally-owned client's `supported_identity_providers` in place
  # without taking ownership of the whole resource (which would clobber every
  # other client setting). Instead we SURFACE the contribution: the provider
  # name to append (e.g. `["PingOne"]`) so the pool/client owner (root) merges
  # it into the client's `supported_identity_providers` while KEEPING `COGNITO`,
  # preserving direct-Cognito sign-in. When federation is disabled the
  # contribution is empty, so the owner appends nothing.
  supported_identity_providers_contribution = var.enabled ? [var.provider_name] : []
}

# Zip the vendored Lambda source (read-only sources/ snapshot). The test file is
# excluded so it does not ship in the deployment artifact.
data "archive_file" "group_mapping" {
  count       = local.enable_group_mapping ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/external_idp_group_mapping"
  output_path = "${path.module}/../../../.terraform/archives/external_idp_group_mapping.zip"
  excludes    = ["test_index.py"]
}

# CloudWatch log group for the group-mapping Lambda (KMS-encrypted when a key is
# supplied), mirroring upstream `ExternalIdPGroupMappingFunctionLogGroup`.
resource "aws_cloudwatch_log_group" "group_mapping" {
  count             = local.enable_group_mapping ? 1 : 0
  name              = "/aws/lambda/${local.group_mapping_function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

# Execution role for the group-mapping Lambda.
resource "aws_iam_role" "group_mapping" {
  count = local.enable_group_mapping ? 1 : 0
  name  = "${local.group_mapping_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# Lambda logging permissions scoped to this function's log group.
resource "aws_iam_role_policy" "group_mapping_logging" {
  count = local.enable_group_mapping ? 1 : 0
  name  = "logging"
  role  = aws_iam_role.group_mapping[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = [
        aws_cloudwatch_log_group.group_mapping[0].arn,
        "${aws_cloudwatch_log_group.group_mapping[0].arn}:*",
      ]
    }]
  })
}

# Cognito group-membership permissions, scoped to exactly the supplied user
# pool ARN (mirrors upstream `ExternalIdPGroupMappingCognitoPolicy`). The Lambda
# does not resolve any secret, so no secretsmanager/ssm grant is added here
# (the OIDC client secret is resolved by the apply-time data source).
resource "aws_iam_role_policy" "group_mapping_cognito" {
  count = local.enable_group_mapping ? 1 : 0
  name  = "cognito-group-access"
  role  = aws_iam_role.group_mapping[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminListGroupsForUser",
        "cognito-idp:AdminAddUserToGroup",
        "cognito-idp:AdminRemoveUserFromGroup",
      ]
      Resource = local.user_pool_arn
    }]
  })
}

# IAM eventual-consistency guard: the synchronous Lambda CreateFunction call
# validates the execution role, so wait for the role + inline policies to
# propagate before creating the function. 30s per project convention.
resource "time_sleep" "wait_for_iam_propagation" {
  count = local.enable_group_mapping ? 1 : 0

  depends_on = [
    aws_iam_role.group_mapping,
    aws_iam_role_policy.group_mapping_logging,
    aws_iam_role_policy.group_mapping_cognito,
  ]

  create_duration = "30s"
}

resource "aws_lambda_function" "group_mapping" {
  architectures = [var.lambda_architecture]
  count         = local.enable_group_mapping ? 1 : 0
  function_name = local.group_mapping_function_name
  role          = aws_iam_role.group_mapping[0].arn
  filename      = data.archive_file.group_mapping[0].output_path

  source_code_hash = data.archive_file.group_mapping[0].output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 128
  layers      = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = local.group_mapping_env
  }

  depends_on = [
    aws_cloudwatch_log_group.group_mapping,
    time_sleep.wait_for_iam_propagation,
  ]

  tags = var.tags
}

# Pre-authorize the Cognito service to invoke the trigger so it works as soon as
# the externally-owned user pool wires it as the PreTokenGeneration trigger.
# Scoped to this account and the specific user pool (mirrors upstream
# `ExternalIdPGroupMappingPermission`).
resource "aws_lambda_permission" "group_mapping_cognito" {
  count = local.enable_group_mapping ? 1 : 0

  statement_id   = "AllowCognitoInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.group_mapping[0].function_name
  principal      = "cognito-idp.${data.aws_partition.current.dns_suffix}"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = local.user_pool_arn
}
