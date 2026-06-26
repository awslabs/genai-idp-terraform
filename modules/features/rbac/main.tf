# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # RBAC Feature Submodule (CDK `UserManagement` analog)
 *
 * Self-contained feature-plugin submodule that delivers role-based access
 * control for the GenAI IDP API and emits the feature-plugin `contract` for
 * `modules/processing-environment-api` to compose (mirroring the CDK
 * accelerator's `api.enable(userManagement)` mechanism).
 *
 * Mirrors the CDK `UserManagement` construct
 * (`reference/genai-idp-cdk/.../processing-environment-api/user-management/`,
 * verified against `cdklabs/genai-idp@main`): the four Cognito user-pool groups
 * (`Admin`/`Author`/`Reviewer`/`Viewer`) the shipped
 * `@aws_auth(cognito_groups: [...])` directives resolve against, the `Users`
 * DynamoDB table (CDK `UsersTable`), the user-management Lambda (CDK
 * `UserManagementFunction`), server-side Reviewer document filtering +
 * `allowedConfigVersions` scoping wiring, and the feature-plugin contract output.
 *
 * The `@aws_auth` directives already ship in the read-only v0.5.12 snapshot
 * (`sources/nested/appsync/src/api/schema.graphql`), so RBAC's job is to make
 * them enforceable by guaranteeing the four groups exist — not to inject SDL.
 */

locals {
  # Resolved RBAC group names: canonical defaults with per-role override support.
  # Keyed by canonical role so the four groups always exist regardless of
  # overrides, and `for_each` keeps stable resource addresses.
  group_names = {
    Admin    = var.group_names.admin
    Author   = var.group_names.author
    Reviewer = var.group_names.reviewer
    Viewer   = var.group_names.viewer
  }

  # Human-readable descriptions per role (mirrors the upstream role model).
  group_descriptions = {
    Admin    = "Full access including user management and configuration-version deletion."
    Author   = "Read and write access to documents, configuration, tests, and discovery."
    Reviewer = "HITL review operations with server-side-filtered document access."
    Viewer   = "Read-only access."
  }
}

# =============================================================================
# RBAC Cognito user-pool groups
# =============================================================================
# Ensure the four RBAC groups exist on the supplied user pool so the shipped
# `@aws_auth(cognito_groups: [...])` directives resolve to real groups and
# AppSync can enforce them server-side. Names default to the canonical four and
# accept overrides without changing the default-on behavior of the roles.
resource "aws_cognito_user_group" "rbac" {
  for_each = local.group_names

  user_pool_id = var.user_pool_id
  name         = each.value
  description  = local.group_descriptions[each.key]
}

# =============================================================================
# Users DynamoDB table (CDK `UsersTable` analog)
# =============================================================================
# Stores user records (user id, email, persona, status, timestamps,
# `allowedConfigVersions`). Single-table design mirroring the CDK `UsersTable`
# (`FixedKeyTableProps`) and the deployed upstream `UsersTable`
# (`sources/template.yaml`):
#
#   * PK / SK string keys (USER#{userId} for both on user records).
#   * `EmailIndex` GSI on `email` (projection ALL) for email-based lookups —
#     required by the v0.5.12 resolvers that enforce `allowedConfigVersions`
#     scoping (`sources/nested/appsync/src/lambda/{configuration_resolver,
#     list_documents_*_resolver}/index.py` all query `IndexName="EmailIndex"`)
#     and by the user-management Lambda (`sources/src/lambda/user_management/`).
#
# Only PK/SK and the GSI partition key are declared as attributes; the
# remaining fields (persona, status, timestamps, `allowedConfigVersions`) are
# schemaless DynamoDB item attributes written by the user-management Lambda.
#
# `PAY_PER_REQUEST` billing, PITR enabled, and KMS server-side encryption keep
# this table consistent with the other IDP DynamoDB tables (tracking,
# configuration, discovery).
resource "aws_dynamodb_table" "users" {
  name         = "${var.name_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption consistent with the other IDP DynamoDB tables
  # (tracking/configuration/concurrency): always enabled, using the project KMS
  # key when supplied (var.encryption_key_arn) and the AWS-owned key otherwise
  # (kms_key_arn = null).
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.encryption_key_arn
  }

  tags = var.tags
}

# =============================================================================
# User-management Lambda (CDK `UserManagementFunction`)
# =============================================================================
# Services the createUser / updateUser / deleteUser / listUsers / getMyProfile
# AppSync operations (verified against `sources/src/lambda/user_management/
# index.py`, handler `index.handler`). The function reads `USERS_TABLE_NAME`,
# `USER_POOL_ID`, `ADMIN_GROUP`/`AUTHOR_GROUP`/`REVIEWER_GROUP`/`VIEWER_GROUP`,
# `ALLOWED_SIGNUP_EMAIL_DOMAINS`, and `LOG_LEVEL` from its environment.
#
# Least-privilege execution role: DynamoDB CRUD on exactly the Users table
# (+ its indexes), the KMS key when encryption is enabled, and ONLY the Cognito
# admin actions the Lambda actually calls for group-membership management — all
# scoped to the supplied user-pool ARN and no broader.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  user_management_function_name = "${var.name_prefix}-user-management"

  # Scope Cognito admin actions to exactly the supplied user pool. When the ARN
  # is not provided, construct it from the pool id so the policy is always
  # scoped to this pool and never broader.
  user_pool_arn = var.user_pool_arn != null ? var.user_pool_arn : "arn:${data.aws_partition.current.partition}:cognito-idp:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:userpool/${var.user_pool_id}"
}

# -----------------------------------------------------------------------------
# Execution role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "user_management" {
  name = "${var.name_prefix}-user-management"

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

# Least-privilege inline policy.
resource "aws_iam_role_policy" "user_management" {
  name = "user-management-policy"
  role = aws_iam_role.user_management.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # Basic Lambda logging, scoped to this function's log group.
          Sid    = "Logging"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Resource = "${aws_cloudwatch_log_group.user_management.arn}:*"
        },
        {
          # DynamoDB CRUD on exactly the Users table and its indexes.
          Sid    = "UsersTableAccess"
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan",
          ]
          Resource = [
            aws_dynamodb_table.users.arn,
            "${aws_dynamodb_table.users.arn}/index/*",
          ]
        },
        {
          # Only the Cognito admin actions the Lambda calls for group-membership
          # management — scoped to the supplied user-pool ARN, and no broader.
          Sid    = "CognitoGroupMembership"
          Effect = "Allow"
          Action = [
            "cognito-idp:AdminAddUserToGroup",
            "cognito-idp:AdminRemoveUserFromGroup",
            "cognito-idp:AdminCreateUser",
            "cognito-idp:AdminDeleteUser",
            "cognito-idp:AdminGetUser",
            "cognito-idp:ListUsers",
            "cognito-idp:AdminListGroupsForUser",
          ]
          Resource = local.user_pool_arn
        },
      ],
      var.encryption_key_arn != null ? [
        {
          # KMS for the encrypted Users table and log group.
          Sid    = "EncryptionKeyAccess"
          Effect = "Allow"
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
          ]
          Resource = var.encryption_key_arn
        },
      ] : [],
    )
  })
}

# VPC/ENI permissions, attached only when the Lambda runs in a VPC.
resource "aws_iam_role_policy_attachment" "user_management_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.user_management.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# -----------------------------------------------------------------------------
# Log group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "user_management" {
  name              = "/aws/lambda/${local.user_management_function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# IAM eventual-consistency guard
# -----------------------------------------------------------------------------
# Lambda creation synchronously validates the execution role; without this the
# create can race the IAM role/policy propagation and fail with an
# InvalidParameterValueException on the role. 30s per project convention.
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.user_management,
    aws_iam_role_policy.user_management,
    aws_iam_role_policy_attachment.user_management_vpc,
    aws_cloudwatch_log_group.user_management,
  ]

  create_duration = "30s"
}

# -----------------------------------------------------------------------------
# Function
# -----------------------------------------------------------------------------

data "archive_file" "user_management" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/user_management"
  output_path = "${path.module}/../../../.terraform/archives/user_management.zip"
}

resource "aws_lambda_function" "user_management" {
  depends_on = [time_sleep.wait_for_iam_propagation]

  function_name    = local.user_management_function_name
  role             = aws_iam_role.user_management.arn
  filename         = data.archive_file.user_management.output_path
  source_code_hash = data.archive_file.user_management.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      USERS_TABLE_NAME             = aws_dynamodb_table.users.name
      USER_POOL_ID                 = var.user_pool_id
      ADMIN_GROUP                  = local.group_names.Admin
      AUTHOR_GROUP                 = local.group_names.Author
      REVIEWER_GROUP               = local.group_names.Reviewer
      VIEWER_GROUP                 = local.group_names.Viewer
      ALLOWED_SIGNUP_EMAIL_DOMAINS = var.allowed_signup_email_domains
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = var.tags
}

# =============================================================================
# Reviewer document filtering + `allowedConfigVersions` scoping wiring
# =============================================================================
# The filtering/scoping LOGIC ships in the read-only v0.5.12 snapshot — the
# document-list resolvers and the configuration resolver all consult the Users
# table server-side (verified against
# `sources/nested/appsync/src/lambda/{list_documents_gsi_resolver,
# list_documents_range_resolver,configuration_resolver}/index.py`):
#
#   * each reads `USERS_TABLE_NAME` from its environment
#     (`os.environ.get("USERS_TABLE_NAME", "")`),
#   * looks the caller up by email via `Query(IndexName="EmailIndex", ...)`,
#   * reads back `allowedConfigVersions` to scope config access, and the
#     document-list resolvers additionally apply Reviewer-only document
#     filtering against the tracking table.
#
# The profile query already exposes `allowedConfigVersions` via the shipped
# schema: `getMyProfile: User` returns the `User` type, which declares
# `allowedConfigVersions: [String]`
# (`sources/nested/appsync/src/api/schema.graphql`). No SDL injection needed.
#
# RBAC's Terraform job (this submodule) is therefore the WIRING: give those
# AppSync resolver Lambdas the env var and the least-privilege read path to the
# Users table so the server-side filtering can run. These two fragments are
# exposed as locals + outputs here and merged into the feature-plugin contract.

locals {
  # `environment` fragment merged onto the core/config resolver Lambdas so they
  # can resolve the Users table at runtime. This is the exact env key the
  # shipped resolvers read.
  reviewer_filtering_environment = {
    USERS_TABLE_NAME = aws_dynamodb_table.users.name
  }

  # `iam_statements` fragment granting the AppSync resolver Lambda role the
  # least-privilege read path the filtering/scoping needs: GetItem/Query on the
  # Users table and its EmailIndex GSI (the resolvers query by email via
  # `IndexName="EmailIndex"`). When the table is KMS-encrypted, the role also
  # needs Decrypt to read it — added only when an encryption key is configured,
  # scoped to exactly that key (least-privilege discipline).
  reviewer_filtering_iam_statements = concat(
    [
      {
        Sid    = "RbacUsersTableReadForFiltering"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          "${aws_dynamodb_table.users.arn}/index/EmailIndex",
        ]
      },
    ],
    var.encryption_key_arn != null ? [
      {
        Sid    = "RbacUsersTableReadKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = var.encryption_key_arn
      },
    ] : [],
  )
}
