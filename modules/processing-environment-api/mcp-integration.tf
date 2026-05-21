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
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

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

  # Permissions match upstream CloudFormation
  # (template.yaml AgentCoreGatewayManagerFunction):
  # `bedrock-agent` / `bedrock-agentcore` / `bedrock-agentcore-control`
  # are the service prefixes used by the AgentCore Gateway control
  # plane.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock-agent:*",
          "bedrock-agentcore:*",
          "bedrock-agentcore-control:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DeleteLogGroup",
          "logs:PutDeliverySource",
          "logs:DeleteDeliverySource",
          "logs:PutDeliveryDestination",
          "logs:DeleteDeliveryDestination",
          "logs:DescribeDeliveryDestinations",
          "logs:DescribeDeliverySources",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:GetRole",
          "cognito-idp:DescribeUserPool"
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
      },
      {
        # KMS for encrypted log group / s3 / etc.
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
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

  # AgentCore Gateway assumes this role to invoke target Lambdas. The
  # trust principal must be `bedrock-agentcore.amazonaws.com`. The
  # conditions narrow trust to this account / region — matches the
  # upstream CloudFormation template.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:bedrock-agentcore:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
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
  source_dir  = local.agentcore_gateway_manager_build_dir
  output_path = "${path.module}/../../.terraform/archives/agentcore_gateway_manager.zip"

  depends_on = [null_resource.build_agentcore_gateway_manager]
}

# Build agentcore_gateway_manager Lambda zip with pip-installed
# dependencies (cfnresponse, bedrock_agentcore_starter_toolkit,
# ruamel-yaml). Both are pure-Python (`py3-none-any.whl`), so we don't
# need Docker — just pip install -t into a build directory and zip
# that. Matches what upstream SAM does on `sam build`.
locals {
  agentcore_gateway_manager_src       = "${path.module}/../../sources/src/lambda/agentcore_gateway_manager"
  agentcore_gateway_manager_build_dir = "${path.module}/../../.terraform/tmp/agentcore_gateway_manager_build"
}

resource "null_resource" "build_agentcore_gateway_manager" {
  count = local.enable_mcp_effective ? 1 : 0

  triggers = {
    src_hash = sha256(join("", [
      for f in fileset(local.agentcore_gateway_manager_src, "**/*") :
      filesha256("${local.agentcore_gateway_manager_src}/${f}")
    ]))
    # Bump this string when the build pipeline below changes (e.g.
    # adding/removing pip flags). `null_resource.triggers` are the only
    # signal terraform has for "re-run the build".
    build_pipeline_version = "manylinux2014_x86_64"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      BUILD_DIR="${local.agentcore_gateway_manager_build_dir}"
      SRC_DIR="${local.agentcore_gateway_manager_src}"

      rm -rf "$BUILD_DIR"
      mkdir -p "$BUILD_DIR"

      # Copy source files
      cp -r "$SRC_DIR"/. "$BUILD_DIR/"

      # Install deps for the Lambda runtime (Linux x86_64), not the
      # build host. `bedrock_agentcore_starter_toolkit` pulls in
      # `pydantic`, whose transitive `pydantic_core` package ships
      # native (Rust-compiled) binaries. The `--platform` /
      # `--only-binary` / `--implementation` flags force pip to fetch
      # the manylinux x86_64 wheel that Lambda can load at runtime.
      # Switch `manylinux2014_x86_64` to `manylinux2014_aarch64` if the
      # function is rebuilt for arm64.
      pip3 install \
        --target "$BUILD_DIR" \
        --upgrade \
        --no-cache-dir \
        --quiet \
        --platform manylinux2014_x86_64 \
        --python-version 3.12 \
        --implementation cp \
        --only-binary=:all: \
        -r "$BUILD_DIR/requirements.txt"

      # Strip caches and egg-info bloat
      find "$BUILD_DIR" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
      find "$BUILD_DIR" -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true
      find "$BUILD_DIR" -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true
    EOT
  }
}

resource "aws_lambda_function" "agentcore_gateway_manager" {
  count            = local.enable_mcp_effective ? 1 : 0
  function_name    = "${local.api_name}-agentcore-gateway-mgr"
  role             = aws_iam_role.agentcore_gateway_manager[0].arn
  filename         = data.archive_file.agentcore_gateway_manager[0].output_path
  source_code_hash = data.archive_file.agentcore_gateway_manager[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 512

  # `bedrock_agentcore_starter_toolkit` and its transitive deps
  # (boto3, pydantic, …) are bundled into the zip via
  # `null_resource.build_agentcore_gateway_manager`. We don't attach
  # the shared `idp_common` layer here because the combined size would
  # exceed Lambda's 250 MB function-code-plus-layer limit.

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
# Bedrock AgentCore Gateway via CloudFormation Custom Resource
# =============================================================================
# AgentCore Gateway is not yet a native CloudFormation resource type, so
# `AWS::Bedrock::AgentCoreGateway` is unrecognized in CloudFormation.
# Upstream CloudFormation (template.yaml) handles this via a CFN custom
# resource:
#   Type: Custom::AgentCoreGateway
#   Properties:
#     ServiceToken: !GetAtt AgentCoreGatewayManagerFunction.Arn
#     ...
# The custom resource invokes the `agentcore_gateway_manager` Lambda
# (provisioned above) which calls the `bedrock-agentcore-control` API
# directly to create/update/delete the gateway. We mirror that pattern
# here by wrapping a one-resource CloudFormation stack around
# `Custom::AgentCoreGateway`. Keeping the CFN-stack wrapper (rather than
# a `null_resource + local-exec`) preserves CFN's create/update/delete
# idempotency and matches the upstream Lambda's expected `cfnresponse`
# callback shape.

resource "aws_cloudformation_stack" "agentcore_gateway" {
  count = local.enable_mcp_effective ? 1 : 0
  name  = "${local.api_name}-agentcore-gateway"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Bedrock AgentCore Gateway for MCP Integration"
    Resources = {
      AgentCoreGateway = {
        Type = "Custom::AgentCoreGateway"
        Properties = {
          ServiceToken     = aws_lambda_function.agentcore_gateway_manager[0].arn
          StackName        = local.api_name
          Region           = data.aws_region.current.id
          LambdaArn        = aws_lambda_function.agentcore_analytics_processor[0].arn
          UserPoolId       = var.user_pool_id
          ClientId         = aws_cognito_user_pool_client.mcp_client[0].id
          ClientSecret     = aws_cognito_user_pool_client.mcp_client[0].client_secret
          ExecutionRoleArn = aws_iam_role.agentcore_gateway_execution[0].arn
          # Force replacement when the manager Lambda code changes so
          # the custom resource re-runs against the latest logic.
          SourceCodeHash = data.archive_file.agentcore_gateway_manager[0].output_base64sha256
        }
      }
    }
    Outputs = {
      GatewayId = {
        Value = { "Fn::GetAtt" = ["AgentCoreGateway", "GatewayId"] }
      }
      GatewayUrl = {
        Value = { "Fn::GetAtt" = ["AgentCoreGateway", "GatewayUrl"] }
      }
      GatewayArn = {
        Value = { "Fn::GetAtt" = ["AgentCoreGateway", "GatewayArn"] }
      }
    }
  })

  # Don't pass IAM caps — the inner template only declares a custom
  # resource, no IAM resources. The Lambda's role grants what it needs.
  tags = var.tags

  depends_on = [
    aws_lambda_function.agentcore_gateway_manager,
    aws_iam_role_policy.agentcore_gateway_manager,
    aws_iam_role.agentcore_gateway_execution,
  ]
}

# =============================================================================
# Cognito external app client for OAuth 2.0 (MCP client authentication)
# =============================================================================

resource "aws_cognito_user_pool_client" "mcp_client" {
  count        = local.enable_mcp_effective ? 1 : 0
  name         = "${local.api_name}-mcp-client"
  user_pool_id = var.user_pool_id

  generate_secret = true

  # Matches the upstream CloudFormation `ExternalAppClient`. Cognito
  # does not support `openid` with the `client_credentials` flow, so we
  # use the `code` flow with the standard scope set.
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  # Cognito requires at least one callback URL when `code` flow is
  # selected. AgentCore Gateway uses JWT validation, not the OAuth
  # redirect flow, so the URL value isn't actually consumed —
  # `var.mcp_callback_urls` is intended to be wired to the
  # CloudFront distribution domain by the caller (root main.tf).
  # When unset, we fall back to a Cognito-hosted UI placeholder so
  # apply still succeeds; the gateway will work either way.
  callback_urls = length(var.mcp_callback_urls) > 0 ? var.mcp_callback_urls : [
    "https://${var.user_pool_id}.auth.${data.aws_region.current.id}.amazoncognito.com/oauth2/idpresponse",
  ]
  logout_urls = length(var.mcp_callback_urls) > 0 ? var.mcp_callback_urls : [
    "https://${var.user_pool_id}.auth.${data.aws_region.current.id}.amazoncognito.com/oauth2/idpresponse",
  ]
}
