# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs for the RBAC feature-plugin submodule.
#
# Exposes the resolved group names (so the federation submodule can target them
# via `rbac_group_names`), the `Users` table / user-management Lambda handles,
# and the feature-plugin `contract` that `modules/processing-environment-api`
# composes.

output "enabled" {
  description = "Whether the RBAC feature is enabled (mirrors var.enabled)."
  value       = var.enabled
}

output "group_names" {
  description = <<-EOT
    The resolved RBAC Cognito group names keyed by canonical role
    (`Admin`/`Author`/`Reviewer`/`Viewer`), reflecting any overrides. Consumed by
    the IdP-federation submodule's group-mapping Lambda so federated users land
    in the correct RBAC roles.
  EOT
  value = {
    Admin    = aws_cognito_user_group.rbac["Admin"].name
    Author   = aws_cognito_user_group.rbac["Author"].name
    Reviewer = aws_cognito_user_group.rbac["Reviewer"].name
    Viewer   = aws_cognito_user_group.rbac["Viewer"].name
  }
}

output "users_table_name" {
  description = <<-EOT
    Name of the `Users` DynamoDB table. Consumed by the user-management Lambda
    (`USERS_TABLE_NAME`) and threaded onto the AppSync resolver Lambdas via the
    feature-plugin contract so the document-list and config-access resolvers can
    apply Reviewer filtering and `allowedConfigVersions` scoping.
  EOT
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = <<-EOT
    ARN of the `Users` DynamoDB table. Used to scope the user-management Lambda's
    least-privilege DynamoDB access to exactly this table and contributed to the
    AppSync Lambda role's read path via the feature-plugin contract.
  EOT
  value       = aws_dynamodb_table.users.arn
}

output "user_management_function_arn" {
  description = <<-EOT
    ARN of the user-management Lambda. Consumed by the API module's
    `feature-plugins.tf` (via the feature-plugin contract) to create the
    `aws_appsync_datasource` + the createUser/updateUser/deleteUser/listUsers/
    getMyProfile resolvers (mirrors CDK `enableInApi()`).
  EOT
  value       = aws_lambda_function.user_management.arn
}

output "user_management_function_name" {
  description = "Name of the user-management Lambda function."
  value       = aws_lambda_function.user_management.function_name
}

# ---------------------------------------------------------------------------
# Reviewer document filtering + `allowedConfigVersions` scoping wiring
# ---------------------------------------------------------------------------
# Pre-derived contract fragments the feature-plugin contract output merges in,
# so the document-list and configuration AppSync resolver Lambdas can read the
# Users table and apply Reviewer filtering / `allowedConfigVersions` scoping
# server-side. Exposing them as outputs lets the contract consume them without
# re-deriving the values.

output "reviewer_filtering_environment" {
  description = <<-EOT
    Environment-map fragment for the core/configuration AppSync resolver Lambdas
    so they resolve the `Users` table at runtime. Carries `USERS_TABLE_NAME` —
    the exact env key the shipped document-list and configuration resolvers read
    (`sources/nested/api-resolvers/src/lambda/{list_documents_gsi_resolver,
    list_documents_range_resolver,configuration_resolver}/index.py`) to apply
    Reviewer document filtering and `allowedConfigVersions` scoping server-side.
    Merged into the feature-plugin contract's `environment`.
  EOT
  value       = local.reviewer_filtering_environment
}

output "reviewer_filtering_iam_statements" {
  description = <<-EOT
    IAM statement fragments granting the AppSync resolver Lambda role the
    least-privilege read path to the `Users` table required for Reviewer
    filtering and `allowedConfigVersions` scoping: `dynamodb:GetItem`/`Query` on
    the table and its `EmailIndex` GSI (the resolvers query by email via
    `IndexName="EmailIndex"`), plus `kms:Decrypt`/`DescribeKey` scoped to the
    encryption key when the table is encrypted. Merged into the feature-plugin
    contract's `iam_statements`.
  EOT
  value       = local.reviewer_filtering_iam_statements
}

# ---------------------------------------------------------------------------
# Feature-plugin contract
# ---------------------------------------------------------------------------
# The contract shape — `{ enabled, resolvers, iam_statements, environment,
# schema_additions }` — that `modules/processing-environment-api` composes via
# its `enabled_feature_contracts` input, mirroring the CDK accelerator's
# `api.enable(userManagement)` / `enableInApi()` mechanism.
#
# Resolver descriptors match the shape the API module's `feature-plugins.tf`
# expects (`type` / `field` / `data_source`, with the request/response mapping
# templates defaulting to the module's standard Lambda Invoke/passthrough VTL —
# the same convention `chat-with-document` relies on). All five user-management
# operations are backed by a SINGLE AppSync Lambda data source: the shipped
# `sources/src/lambda/user_management/index.py` dispatches on
# `$context.info.fieldName` (`createUser`/`updateUser`/`deleteUser`/`listUsers`/
# `getMyProfile`), so one data source + the default passthrough template serve
# all of them.
#
# Unlike `chat-with-document` (which owns its data sources because they only
# need resolver names), the user-management data source must be created where
# the AppSync API id is available — inside the API module. The contract
# therefore NAMES the data source (`local.user_management_data_source_name`) and
# the submodule exposes the user-management Lambda ARN
# (`user_management_function_arn`) so `feature-plugins.tf` can create the
# `aws_appsync_datasource` and attach these resolvers (mirrors CDK
# `enableInApi()` calling `api.addLambdaDataSource(...)` then
# `createResolver(...)`).
#
# `schema_additions = null`: the `@aws_auth(cognito_groups: [...])` directives
# and the `User`/`UserList` types already ship in the read-only v0.5.12 schema
# (`sources/nested/api-resolvers/src/api/schema.graphql`), so no SDL injection is
# needed.
locals {
  # Deterministic AppSync data source name (alphanumeric + underscore only) the
  # API module creates from the user-management Lambda ARN and that every
  # user-management resolver references.
  user_management_data_source_name = replace("${var.name_prefix}_user_management", "-", "_")

  # The five user-management resolvers, all fronted by the single
  # user-management Lambda data source (the Lambda dispatches on fieldName).
  # Field types match the shipped schema: createUser/updateUser/deleteUser are
  # Mutations; listUsers/getMyProfile are Queries.
  user_management_resolvers = {
    createUser = {
      type        = "Mutation"
      field       = "createUser"
      data_source = local.user_management_data_source_name
    }
    deleteUser = {
      type        = "Mutation"
      field       = "deleteUser"
      data_source = local.user_management_data_source_name
    }
    updateUser = {
      type        = "Mutation"
      field       = "updateUser"
      data_source = local.user_management_data_source_name
    }
    listUsers = {
      type        = "Query"
      field       = "listUsers"
      data_source = local.user_management_data_source_name
    }
    getMyProfile = {
      type        = "Query"
      field       = "getMyProfile"
      data_source = local.user_management_data_source_name
    }
  }
}

output "user_management_data_source_name" {
  description = <<-EOT
    Deterministic AppSync Lambda data-source name the API module's
    `feature-plugins.tf` creates from `user_management_function_arn` and that
    every user-management resolver in the contract references. Exposed
    separately so the API module can name the `aws_appsync_datasource` it
    creates to match the contract's resolver `data_source` references.
  EOT
  value       = local.user_management_data_source_name
}

output "contract" {
  description = <<-EOT
    Feature-plugin contract consumed by `processing-environment-api` via its
    `enabled_feature_contracts` input, mirroring the CDK
    `api.enable(userManagement)` / `enableInApi()` mechanism.

    Carries the contract shape
    `{ enabled, resolvers, iam_statements, environment, schema_additions }`:

      * `resolvers` — the five user-management operations
        (createUser/deleteUser/updateUser Mutations + listUsers/getMyProfile
        Queries), each pointing at the single user-management Lambda data source
        (named `user_management_data_source_name`). The API module creates that
        data source from `user_management_function_arn` and attaches these
        resolvers with the default Lambda Invoke/passthrough templates.
      * `iam_statements` — the least-privilege `Users`-table read path
        (GetItem/Query on the table + `EmailIndex`, plus conditional KMS) merged
        onto the AppSync resolver Lambda role so the document-list and
        configuration resolvers can apply Reviewer filtering and
        `allowedConfigVersions` scoping server-side.
      * `environment` — `{ USERS_TABLE_NAME }` merged onto the core/config
        resolver Lambdas so they resolve the `Users` table at runtime.
      * `field_functions` — IDP v0.6.4 REST transport: the field -> Lambda ARN
        map the dispatcher routes on. Only the canonical `createUser` appears;
        the dispatcher's FIELD_ALIASES fold updateUser/deleteUser/listUsers/
        getMyProfile onto it.
      * `schema_additions = null` — the `@aws_auth` directives and `User` types
        already ship in the read-only v0.5.12 schema; no SDL injection needed.
  EOT
  value = {
    enabled          = var.enabled
    resolvers        = local.user_management_resolvers
    data_sources     = { (local.user_management_data_source_name) = aws_lambda_function.user_management.arn }
    field_functions  = { createUser = aws_lambda_function.user_management.arn }
    iam_statements   = local.reviewer_filtering_iam_statements
    environment      = local.reviewer_filtering_environment
    schema_additions = null
  }
}
