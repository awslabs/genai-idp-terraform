# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# MCP Integration sub-feature (v0.4.6+)
# Conditional on var.enable_mcp (defaults to false; disabled in GovCloud)
#
# Uses aws_cloudformation_stack fallback for Bedrock AgentCore Gateway
# per D-004 (native Terraform provider resource not yet available).

locals {
  # GovCloud guard: AgentCore not available in us-gov-* regions
  enable_mcp_effective = var.enable_mcp && !startswith(data.aws_region.current.id, "us-gov-")
}

# =============================================================================
# IAM Role: agentcore_analytics_processor
# =============================================================================

resource "aws_iam_role" "agentcore_analytics_processor" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "${local.api_name}-agentcore-analytics-proc"

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

resource "aws_iam_role_policy" "agentcore_analytics_processor" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "agentcore-analytics-processor-policy"
  role  = aws_iam_role.agentcore_analytics_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # Athena query execution
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListQueryExecutions"
        ]
        Resource = "*"
      },
      {
        # Glue catalog access for Athena
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        # S3 access for Athena results and reporting data
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          local.output_bucket_arn,
          "${local.output_bucket_arn}/*"
        ]
      },
      {
        # Bedrock invoke for natural language query processing
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "agentcore_analytics_processor_xray" {
  count      = local.enable_mcp_effective ? 1 : 0
  role       = aws_iam_role.agentcore_analytics_processor[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: agentcore_analytics_processor
# =============================================================================

resource "aws_cloudwatch_log_group" "agentcore_analytics_processor" {
  count             = local.enable_mcp_effective ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-agentcore-analytics-proc"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "agentcore_analytics_processor" {
  count       = local.enable_mcp_effective ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/agentcore_analytics_processor"
  output_path = "${path.module}/../../.terraform/archives/agentcore_analytics_processor.zip"
}

resource "aws_lambda_function" "agentcore_analytics_processor" {
  count            = local.enable_mcp_effective ? 1 : 0
  function_name    = "${local.api_name}-agentcore-analytics-proc"
  role             = aws_iam_role.agentcore_analytics_processor[0].arn
  filename         = data.archive_file.agentcore_analytics_processor[0].output_path
  source_code_hash = data.archive_file.agentcore_analytics_processor[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  layers           = compact([var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL     = var.log_level
      OUTPUT_BUCKET = local.output_bucket_name
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

  depends_on = [aws_cloudwatch_log_group.agentcore_analytics_processor]
  tags       = var.tags
}

# =============================================================================
# IAM Role: agentcore_gateway_manager
# =============================================================================

resource "aws_iam_role" "agentcore_gateway_manager" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "${local.api_name}-agentcore-gateway-mgr"

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

resource "aws_iam_role_policy" "agentcore_gateway_manager" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "agentcore-gateway-manager-policy"
  role  = aws_iam_role.agentcore_gateway_manager[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # Bedrock AgentCore Gateway management
        Effect = "Allow"
        Action = [
          "bedrock:CreateAgentCoreGateway",
          "bedrock:UpdateAgentCoreGateway",
          "bedrock:DeleteAgentCoreGateway",
          "bedrock:GetAgentCoreGateway",
          "bedrock:ListAgentCoreGateways",
          "bedrock:CreateAgentCoreGatewayTarget",
          "bedrock:UpdateAgentCoreGatewayTarget",
          "bedrock:DeleteAgentCoreGatewayTarget",
          "bedrock:GetAgentCoreGatewayTarget",
          "bedrock:ListAgentCoreGatewayTargets"
        ]
        Resource = "*"
      },
      {
        # IAM PassRole for AgentCore Gateway execution role
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.agentcore_gateway_execution[0].arn
      },
      {
        # Lambda invoke for analytics processor
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.agentcore_analytics_processor[0].arn
      }
    ]
  })
}

# =============================================================================
# IAM Role: agentcore_gateway_execution (used by AgentCore Gateway itself)
# =============================================================================

resource "aws_iam_role" "agentcore_gateway_execution" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "${local.api_name}-agentcore-gateway-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "agentcore_gateway_execution" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "agentcore-gateway-execution-policy"
  role  = aws_iam_role.agentcore_gateway_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.agentcore_analytics_processor[0].arn
    }]
  })
}

# =============================================================================
# Lambda: agentcore_gateway_manager
# =============================================================================

resource "aws_cloudwatch_log_group" "agentcore_gateway_manager" {
  count             = local.enable_mcp_effective ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-agentcore-gateway-mgr"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "agentcore_gateway_manager" {
  count       = local.enable_mcp_effective ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/agentcore_gateway_manager"
  output_path = "${path.module}/../../.terraform/archives/agentcore_gateway_manager.zip"
}

resource "aws_lambda_function" "agentcore_gateway_manager" {
  count            = local.enable_mcp_effective ? 1 : 0
  function_name    = "${local.api_name}-agentcore-gateway-mgr"
  role             = aws_iam_role.agentcore_gateway_manager[0].arn
  filename         = data.archive_file.agentcore_gateway_manager[0].output_path
  source_code_hash = data.archive_file.agentcore_gateway_manager[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 256
  layers           = compact([var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                        = var.log_level
      ANALYTICS_PROCESSOR_ARN          = aws_lambda_function.agentcore_analytics_processor[0].arn
      AGENTCORE_GATEWAY_EXECUTION_ROLE = aws_iam_role.agentcore_gateway_execution[0].arn
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

  depends_on = [aws_cloudwatch_log_group.agentcore_gateway_manager]
  tags       = var.tags
}

# =============================================================================
# Bedrock AgentCore Gateway via CloudFormation stack fallback (D-004)
# Native aws_bedrock_agent_core_gateway resource not yet in provider.
# =============================================================================

resource "aws_cloudformation_stack" "agentcore_gateway" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "${local.api_name}-agentcore-gateway"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Bedrock AgentCore Gateway for MCP Integration"
    Resources = {
      AgentCoreGateway = {
        Type = "AWS::Bedrock::AgentCoreGateway"
        Properties = {
          Name        = "${local.api_name}-mcp-gateway"
          Description = "MCP server gateway for IDP analytics"
          RoleArn     = aws_iam_role.agentcore_gateway_execution[0].arn
          Targets = [{
            Name        = "analytics-processor"
            Description = "IDP analytics processor Lambda"
            LambdaArn   = aws_lambda_function.agentcore_analytics_processor[0].arn
          }]
        }
      }
    }
    Outputs = {
      GatewayId = {
        Value = { Ref = "AgentCoreGateway" }
      }
      GatewayEndpoint = {
        Value = { "Fn::GetAtt" = ["AgentCoreGateway", "Endpoint"] }
      }
    }
  })

  capabilities = ["CAPABILITY_IAM"]

  tags = var.tags
}

# =============================================================================
# Cognito external app client for OAuth 2.0 (MCP client authentication)
# =============================================================================

resource "aws_cognito_user_pool_client" "mcp_client" {
  count        = local.enable_mcp_effective && var.user_pool_id != null ? 1 : 0
  name         = "${local.api_name}-mcp-client"
  user_pool_id = var.user_pool_id

  generate_secret                      = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["openid"]
  allowed_oauth_flows_user_pool_client = true

  # No callback URLs needed for client_credentials flow
  explicit_auth_flows = []
}
