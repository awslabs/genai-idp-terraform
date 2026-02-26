# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Agent Companion Chat sub-feature (v0.4.0+)
# Conditional on var.enable_agent_companion_chat

# =============================================================================
# DynamoDB Table: agent_chat_sessions
# =============================================================================

resource "aws_dynamodb_table" "agent_chat_sessions" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name         = "${local.api_name}-agent-chat-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sessionId"

  attribute {
    name = "sessionId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  dynamic "server_side_encryption" {
    for_each = local.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = local.encryption_key_arn
    }
  }

  tags = var.tags
}

# =============================================================================
# IAM Role: agent_chat_processor
# =============================================================================

resource "aws_iam_role" "agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "${local.api_name}-agent-chat-processor"

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

resource "aws_iam_role_policy" "agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "agent-chat-processor-policy"
  role = aws_iam_role.agent_chat_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "agent_chat_processor_xray" {
  count      = var.enable_agent_companion_chat ? 1 : 0
  role       = aws_iam_role.agent_chat_processor[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: agent_chat_processor
# =============================================================================

resource "aws_cloudwatch_log_group" "agent_chat_processor" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-agent-chat-processor"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "agent_chat_processor" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/agent_chat_processor"
  output_path = "${path.module}/../../.terraform/archives/agent_chat_processor.zip"
}

resource "aws_lambda_function" "agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  function_name    = "${local.api_name}-agent-chat-processor"
  role             = aws_iam_role.agent_chat_processor[0].arn
  filename         = data.archive_file.agent_chat_processor[0].output_path
  source_code_hash = data.archive_file.agent_chat_processor[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512

  layers = compact([var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
      INPUT_BUCKET        = local.input_bucket_name
      OUTPUT_BUCKET       = local.output_bucket_name
      APPSYNC_API_URL     = "https://${aws_appsync_graphql_api.api.uris["GRAPHQL"]}"
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.agent_chat_processor]
  tags       = var.tags
}

# =============================================================================
# IAM Role: agent_chat_resolver (AppSync → Lambda)
# =============================================================================

resource "aws_iam_role" "agent_chat_resolver" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "${local.api_name}-agent-chat-resolver"

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

resource "aws_iam_role_policy" "agent_chat_resolver" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "agent-chat-resolver-policy"
  role = aws_iam_role.agent_chat_resolver[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.agent_chat_processor[0].arn
      }
    ]
  })
}

# =============================================================================
# Lambda: agent_chat_resolver
# =============================================================================

resource "aws_cloudwatch_log_group" "agent_chat_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-agent-chat-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "agent_chat_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/agent_chat_resolver"
  output_path = "${path.module}/../../.terraform/archives/agent_chat_resolver.zip"
}

resource "aws_lambda_function" "agent_chat_resolver" {
  count = var.enable_agent_companion_chat ? 1 : 0

  function_name    = "${local.api_name}-agent-chat-resolver"
  role             = aws_iam_role.agent_chat_resolver[0].arn
  filename         = data.archive_file.agent_chat_resolver[0].output_path
  source_code_hash = data.archive_file.agent_chat_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30

  layers = compact([var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      AGENT_CHAT_PROCESSOR_ARN = aws_lambda_function.agent_chat_processor[0].arn
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.agent_chat_resolver]
  tags       = var.tags
}

# =============================================================================
# Session management resolver Lambdas (shared IAM role)
# =============================================================================

resource "aws_iam_role" "chat_session_resolvers" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "${local.api_name}-chat-session-resolvers"

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

resource "aws_iam_role_policy" "chat_session_resolvers" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "chat-session-resolvers-policy"
  role = aws_iam_role.chat_session_resolvers[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*"
        ]
      }
    ]
  })
}

# create_chat_session_resolver
resource "aws_cloudwatch_log_group" "create_chat_session_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-create-chat-session-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "create_chat_session_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/create_chat_session_resolver"
  output_path = "${path.module}/../../.terraform/archives/create_chat_session_resolver.zip"
}

resource "aws_lambda_function" "create_chat_session_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-create-chat-session-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.create_chat_session_resolver[0].output_path
  source_code_hash = data.archive_file.create_chat_session_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.create_chat_session_resolver]
  tags       = var.tags
}

# list_agent_chat_sessions_resolver
resource "aws_cloudwatch_log_group" "list_agent_chat_sessions_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-list-chat-sessions-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "list_agent_chat_sessions_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/list_agent_chat_sessions_resolver"
  output_path = "${path.module}/../../.terraform/archives/list_agent_chat_sessions_resolver.zip"
}

resource "aws_lambda_function" "list_agent_chat_sessions_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-list-chat-sessions-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.list_agent_chat_sessions_resolver[0].output_path
  source_code_hash = data.archive_file.list_agent_chat_sessions_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.list_agent_chat_sessions_resolver]
  tags       = var.tags
}

# get_agent_chat_messages_resolver
resource "aws_cloudwatch_log_group" "get_agent_chat_messages_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-get-chat-messages-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "get_agent_chat_messages_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/get_agent_chat_messages_resolver"
  output_path = "${path.module}/../../.terraform/archives/get_agent_chat_messages_resolver.zip"
}

resource "aws_lambda_function" "get_agent_chat_messages_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-get-chat-messages-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.get_agent_chat_messages_resolver[0].output_path
  source_code_hash = data.archive_file.get_agent_chat_messages_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.get_agent_chat_messages_resolver]
  tags       = var.tags
}

# delete_agent_chat_session_resolver
resource "aws_cloudwatch_log_group" "delete_agent_chat_session_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-delete-chat-session-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "delete_agent_chat_session_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/delete_agent_chat_session_resolver"
  output_path = "${path.module}/../../.terraform/archives/delete_agent_chat_session_resolver.zip"
}

resource "aws_lambda_function" "delete_agent_chat_session_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-delete-chat-session-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.delete_agent_chat_session_resolver[0].output_path
  source_code_hash = data.archive_file.delete_agent_chat_session_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.delete_agent_chat_session_resolver]
  tags       = var.tags
}

# =============================================================================
# AppSync Lambda data sources and resolvers for Agent Companion Chat
# =============================================================================

resource "aws_appsync_datasource" "agent_chat_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "AgentChatResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.agent_chat_resolver[0].arn
  }
}

resource "aws_appsync_datasource" "create_chat_session_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "CreateChatSessionResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.create_chat_session_resolver[0].arn
  }
}

resource "aws_appsync_datasource" "list_agent_chat_sessions_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "ListAgentChatSessionsResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.list_agent_chat_sessions_resolver[0].arn
  }
}

resource "aws_appsync_datasource" "get_agent_chat_messages_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "GetAgentChatMessagesResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.get_agent_chat_messages_resolver[0].arn
  }
}

resource "aws_appsync_datasource" "delete_agent_chat_session_resolver" {
  count            = var.enable_agent_companion_chat ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "DeleteAgentChatSessionResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.delete_agent_chat_session_resolver[0].arn
  }
}

resource "aws_appsync_resolver" "send_agent_chat_message" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "sendAgentChatMessage"
  data_source = aws_appsync_datasource.agent_chat_resolver[0].name
}

resource "aws_appsync_resolver" "list_agent_chat_sessions" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listChatSessions"
  data_source = aws_appsync_datasource.list_agent_chat_sessions_resolver[0].name
}

resource "aws_appsync_resolver" "get_agent_chat_messages" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getAgentChatMessages"
  data_source = aws_appsync_datasource.get_agent_chat_messages_resolver[0].name
}

resource "aws_appsync_resolver" "get_chat_messages" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getChatMessages"
  data_source = aws_appsync_datasource.get_agent_chat_messages_resolver[0].name
}

resource "aws_appsync_resolver" "delete_agent_chat_session" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteChatSession"
  data_source = aws_appsync_datasource.delete_agent_chat_session_resolver[0].name
}

resource "aws_appsync_resolver" "update_chat_session_title" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "updateChatSessionTitle"
  data_source = aws_appsync_datasource.create_chat_session_resolver[0].name
}
