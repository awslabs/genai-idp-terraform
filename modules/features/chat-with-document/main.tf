# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Chat-with-Document Feature Submodule
 *
 * Self-contained feature-plugin submodule that provisions the v0.5.11+
 * **async streaming** Chat-with-Document experience and emits a feature-plugin
 * `contract` for `modules/processing-environment-api` to compose (mirroring the
 * CDK accelerator's `api.enable(feature)` mechanism).
 *
 * Upstream replaced the legacy synchronous `chatWithDocument` Query with an
 * async model (verified against the v0.5.12 snapshot,
 * `sources/nested/appsync/src/api/schema.graphql` + `nested/appsync/template.yaml`):
 *
 *   * `sendChatDocumentMessage` (Mutation) — a lightweight resolver Lambda that
 *     records session ownership, async-invokes the processor on the first user
 *     message, and passes processor-originated publishes through for fan-out.
 *   * `onChatDocumentMessageUpdate` (Subscription) — a NONE-data-source fan-out
 *     resolver that streams status/delta/final/error events to the owning user.
 *   * `chat_with_document_processor` — the long-running Lambda that loads the
 *     document, calls Bedrock (`converse_stream`), and publishes streaming
 *     updates back to AppSync outside the 30s synchronous budget.
 *
 * This submodule creates the two Lambdas + the session-ownership table, then
 * emits the resolver/IAM/env contract (see outputs.tf). The API module owns the
 * AppSync data sources and attaches the composed resolvers.
 */

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result

  # Module build directory for Lambda archives.
  module_build_dir = "${path.module}/.terraform-build"

  # Upstream source paths (v0.5.12 snapshot). The processor lives under the main
  # template's src/lambda; the lightweight resolver lives under the nested
  # appsync template. Both are zipped read-only from sources/ (no edits).
  processor_src_dir = "${path.module}/../../../sources/src/lambda/chat_with_document_processor"
  resolver_src_dir  = "${path.module}/../../../sources/nested/appsync/src/lambda/send_chat_document_message_resolver"

  output_bucket_name = element(split(":", var.output_bucket_arn), 5)

  # ---------------------------------------------------------------------------
  # Effective chat config resolution
  # ---------------------------------------------------------------------------
  # The runtime processor Lambda performs the same resolution against the config
  # version it loads from DynamoDB; this local mirrors it at plan time so the
  # module surfaces (and tests can assert) the resolved values, and so the
  # default model id is computed deterministically.
  #
  #   effective chat config = top-level `chat:` block when present,
  #                           else fall back to `summarization.*`,
  #                           with model defaulting to the v0.5.12 default
  #                           `us.anthropic.claude-opus-4-7:1m` when unspecified.
  default_chat_model = "us.anthropic.claude-opus-4-7:1m"

  chat_cfg = try(var.config.chat, {}) == null ? {} : try(var.config.chat, {})
  summ_cfg = try(var.config.summarization, {}) == null ? {} : try(var.config.summarization, {})

  # `chat:` wins over `summarization.*`; missing model falls back to the default.
  effective_chat_config = {
    model = coalesce(
      try(local.chat_cfg.model, null),
      try(local.summ_cfg.model, null),
      local.default_chat_model,
    )
    system_prompt = try(
      coalesce(
        try(local.chat_cfg.system_prompt, null),
        try(local.summ_cfg.system_prompt, null),
      ),
      "",
    )
    temperature = coalesce(
      try(local.chat_cfg.temperature, null),
      try(local.summ_cfg.temperature, null),
      0.0,
    )
    max_tokens = coalesce(
      try(local.chat_cfg.max_tokens, null),
      try(local.summ_cfg.max_tokens, null),
      4096,
    )
    # True when the effective chat configuration was sourced from a top-level
    # `chat:` block rather than the `summarization.*` fallback.
    source = try(local.chat_cfg.model, null) != null || length(keys(local.chat_cfg)) > 0 ? "chat" : "summarization"
  }

  layers = compact([var.base_layer_arn, var.idp_common_layer_arn])
}

resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# =============================================================================
# Chat-with-Document session-ownership table
# =============================================================================
# Tracks session ownership so one user cannot subscribe to or continue another
# user's chat session. Short TTL keeps storage minimal (the UI discards history
# on leave). Mirrors upstream `ChatDocumentSessionsTable`.
resource "aws_dynamodb_table" "chat_document_sessions" {
  # checkov:skip=CKV_AWS_28:PITR intentionally disabled — ephemeral per-session ownership metadata with short TTL
  name         = "${var.name_prefix}-chat-document-sessions-${local.suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sessionId"

  attribute {
    name = "sessionId"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  dynamic "server_side_encryption" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = var.encryption_key_arn
    }
  }

  tags = var.tags
}

# =============================================================================
# Long-running Chat-with-Document processor Lambda
# =============================================================================
data "archive_file" "chat_processor" {
  type        = "zip"
  source_dir  = local.processor_src_dir
  output_path = "${local.module_build_dir}/chat-with-document-processor.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "chat_processor" {
  name = "${var.name_prefix}-cwd-processor-${local.suffix}"

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

resource "aws_iam_role_policy" "chat_processor" {
  name = "chat-with-document-processor-policy"
  role = aws_iam_role.chat_processor.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.processor_iam_statements
  })
}

# ENI permissions for VPC-attached processor Lambda (only when vpc_subnet_ids set).
resource "aws_iam_role_policy" "chat_processor_vpc" {
  #checkov:skip=CKV_AWS_355:ENI ops require wildcard resource (ENIs created dynamically)
  #checkov:skip=CKV_AWS_290:ENI ops require wildcard resource (ENIs created dynamically)
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "chat-with-document-processor-vpc-policy"
  role  = aws_iam_role.chat_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "chat_processor" {
  name              = "/aws/lambda/${var.name_prefix}-cwd-processor-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "chat_processor" {
  architectures = [var.lambda_architecture]
  #checkov:skip=CKV_AWS_116:DLQ not required — invoked async by resolver; failures published to UI as assistant_error
  #checkov:skip=CKV_AWS_117:VPC access is optional (driven by var.vpc_subnet_ids)
  #checkov:skip=CKV_AWS_115:Reserved concurrency not required — scales on demand
  function_name = "${var.name_prefix}-cwd-processor-${local.suffix}"
  role          = aws_iam_role.chat_processor.arn

  filename         = data.archive_file.chat_processor.output_path
  source_code_hash = data.archive_file.chat_processor.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 900
  memory_size = var.processor_memory_size
  description = "Long-running Chat-with-Document processor (streams Bedrock tokens via AppSync)"

  layers      = local.layers
  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      OUTPUT_BUCKET            = local.output_bucket_name
      CONFIGURATION_TABLE_NAME = var.configuration_table_name
      TRACKING_TABLE_NAME      = var.tracking_table_name
      APPSYNC_API_URL          = var.appsync_graphql_url
      GUARDRAIL_ID_AND_VERSION = var.guardrail_id_and_version != null ? var.guardrail_id_and_version : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [aws_cloudwatch_log_group.chat_processor]
  tags       = var.tags
}

# =============================================================================
# Lightweight sendChatDocumentMessage resolver Lambda
# =============================================================================
data "archive_file" "chat_resolver" {
  type        = "zip"
  source_dir  = local.resolver_src_dir
  output_path = "${local.module_build_dir}/send-chat-document-message-resolver.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "chat_resolver" {
  name = "${var.name_prefix}-cwd-resolver-${local.suffix}"

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

resource "aws_iam_role_policy" "chat_resolver" {
  name = "send-chat-document-message-resolver-policy"
  role = aws_iam_role.chat_resolver.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.resolver_iam_statements
  })
}

# ENI permissions for VPC-attached resolver Lambda (only when vpc_subnet_ids set).
resource "aws_iam_role_policy" "chat_resolver_vpc" {
  #checkov:skip=CKV_AWS_355:ENI ops require wildcard resource (ENIs created dynamically)
  #checkov:skip=CKV_AWS_290:ENI ops require wildcard resource (ENIs created dynamically)
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "send-chat-document-message-resolver-vpc-policy"
  role  = aws_iam_role.chat_resolver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "chat_resolver" {
  name              = "/aws/lambda/${var.name_prefix}-cwd-resolver-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "chat_resolver" {
  architectures = [var.lambda_architecture]
  #checkov:skip=CKV_AWS_116:DLQ not required for AppSync resolver function
  #checkov:skip=CKV_AWS_117:VPC access is optional (driven by var.vpc_subnet_ids)
  #checkov:skip=CKV_AWS_115:Reserved concurrency not required — scales on demand
  function_name = "${var.name_prefix}-cwd-resolver-${local.suffix}"
  role          = aws_iam_role.chat_resolver.arn

  filename         = data.archive_file.chat_resolver.output_path
  source_code_hash = data.archive_file.chat_resolver.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256
  description = "Lightweight AppSync resolver for Chat-with-Document async mutation"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                            = var.log_level
      CHAT_DOCUMENT_SESSIONS_TABLE         = aws_dynamodb_table.chat_document_sessions.name
      CHAT_DOCUMENT_PROCESSOR_FUNCTION_ARN = aws_lambda_function.chat_processor.arn
      DATA_RETENTION_DAYS                  = tostring(var.data_retention_days)
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [aws_cloudwatch_log_group.chat_resolver]
  tags       = var.tags
}

# =============================================================================
# AppSync data sources (self-contained)
# =============================================================================
# This submodule owns its AppSync data sources so it stays fully self-contained.
# The contract references them by name; the API module's
# feature-plugin composition (`aws_appsync_resolver.feature`) attaches the
# `sendChatDocumentMessage` mutation to the Lambda data source and the
# `onChatDocumentMessageUpdate` subscription to the NONE data source.

# Dedicated AppSync service role that lets AppSync invoke the resolver Lambda.
resource "aws_iam_role" "appsync_service_role" {
  name = "${var.name_prefix}-cwd-appsync-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "appsync_service_role" {
  name = "invoke-chat-resolver"
  role = aws_iam_role.appsync_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.chat_resolver.arn
    }]
  })
}

# Lambda data source fronting the lightweight sendChatDocumentMessage resolver.
resource "aws_appsync_datasource" "send_chat_document_message" {
  api_id           = var.appsync_api_id
  name             = var.data_source_name
  description      = "Lambda data source for the Chat-with-Document async mutation"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_service_role.arn

  lambda_config {
    function_arn = aws_lambda_function.chat_resolver.arn
  }
}

# NONE (local) data source used by the subscription fan-out resolver. Named
# per-submodule to avoid collision with other API-wide NONE data sources.
resource "aws_appsync_datasource" "chat_document_none" {
  api_id = var.appsync_api_id
  name   = var.none_data_source_name
  type   = "NONE"
}
