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
  hash_key     = "userId"
  range_key    = "sessionId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "sessionId"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
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

# DynamoDB Table: chat messages (PK/SK schema matching CloudFormation ChatMessagesTable)
resource "aws_dynamodb_table" "agent_chat_messages" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name         = "${local.api_name}-agent-chat-messages"
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

  ttl {
    attribute_name = "ExpiresAfter"
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

# DynamoDB Table: conversation memory (PK/SK schema matching CloudFormation IdHelperChatMemoryTable)
resource "aws_dynamodb_table" "agent_chat_memory" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name         = "${local.api_name}-agent-chat-memory"
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

  ttl {
    attribute_name = "ExpiresAfter"
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
        Resource = compact([
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_messages[0].arn,
          "${aws_dynamodb_table.agent_chat_messages[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_memory[0].arn,
          "${aws_dynamodb_table.agent_chat_memory[0].arn}/index/*",
          local.tracking_table_arn,
          local.tracking_table_arn != null ? "${local.tracking_table_arn}/index/*" : null,
          local.configuration_table_arn,
          local.configuration_table_arn != null ? "${local.configuration_table_arn}/index/*" : null,
        ])
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:GetInferenceProfile"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:InvokeAgentRuntime"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:GetExecutionHistory",
          "states:ListExecutions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["appsync:GraphQL"]
        Resource = "${aws_appsync_graphql_api.api.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = compact([local.encryption_key_arn])
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

# Build agent_chat_processor with bundled deps (strands-agents, bedrock-agentcore)
# Matches CloudFormation/SAM approach: pip install directly into the deployment package
# This avoids Lambda layer size limits (250MB unzipped) since strands+bedrock-agentcore alone exceed it
#
# IMPORTANT: archive_file is a data source (runs at plan time), so we cannot use it here.
# Instead, the null_resource builds AND zips the package, then we reference the zip directly.
# The source_code_hash is computed from a sha256 file written by the build script.
locals {
  agent_chat_processor_src        = "${path.module}/../../sources/src/lambda/agent_chat_processor"
  agent_chat_processor_build_dir  = "${path.module}/../../.terraform/tmp/agent_chat_processor_build"
  agent_chat_processor_idp_common = "${path.module}/../../sources/lib/idp_common_pkg"
  agent_chat_processor_zip        = "${path.module}/../../.terraform/archives/agent_chat_processor.zip"
  agent_chat_processor_hash_file  = "${path.module}/../../.terraform/archives/agent_chat_processor.zip.sha256"
}

resource "null_resource" "build_agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  triggers = {
    # Rebuild when source or idp_common changes
    src_hash = sha256(join("", [
      for f in fileset(local.agent_chat_processor_src, "**/*.py") :
      filesha256("${local.agent_chat_processor_src}/${f}")
    ]))
    idp_hash = sha256(join("", [
      for f in fileset("${local.agent_chat_processor_idp_common}/idp_common/agents", "**/*.py") :
      filesha256("${local.agent_chat_processor_idp_common}/idp_common/agents/${f}")
    ]))
    pyproject_hash = filesha256("${local.agent_chat_processor_idp_common}/pyproject.toml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      BUILD_DIR="${local.agent_chat_processor_build_dir}"
      SRC_DIR="${local.agent_chat_processor_src}"
      IDP_PKG="${local.agent_chat_processor_idp_common}"
      ZIP_OUT="${local.agent_chat_processor_zip}"
      HASH_OUT="${local.agent_chat_processor_hash_file}"

      # Clean and recreate build dir
      rm -rf "$BUILD_DIR"
      mkdir -p "$BUILD_DIR"
      mkdir -p "$(dirname "$ZIP_OUT")"

      # Copy Lambda source
      cp -r "$SRC_DIR"/. "$BUILD_DIR/"

      # Resolve absolute paths for Docker volume mounts
      ABS_BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
      ABS_IDP_PKG="$(cd "$IDP_PKG" && pwd)"
      ABS_ZIP_DIR="$(cd "$(dirname "$ZIP_OUT")" && pwd)"
      ZIP_BASENAME="$(basename "$ZIP_OUT")"
      ABS_ZIP_OUT="$ABS_ZIP_DIR/$ZIP_BASENAME"

      # Build inside a Linux x86_64 container to produce Lambda-compatible binaries
      # --platform linux/amd64 is required on Apple Silicon (arm64) hosts to produce x86_64 .so files
      # --entrypoint bash overrides the Lambda base image's custom entrypoint
      docker run --rm \
        --platform linux/amd64 \
        --entrypoint bash \
        -v "$ABS_BUILD_DIR:/build" \
        -v "$ABS_IDP_PKG:/idp_pkg:ro" \
        -v "$ABS_ZIP_DIR:/output" \
        public.ecr.aws/lambda/python:3.12 \
        -c "
          set -e
          # Install pip deps from requirements.txt, skipping the ./lib reference
          sed 's|^\./lib.*||g' /build/requirements.txt > /tmp/requirements_clean.txt
          pip3 install -r /tmp/requirements_clean.txt -t /build --quiet --no-cache-dir 2>/dev/null || true

          # Copy idp_pkg to a writable temp dir (pip needs to write egg-info during build)
          cp -rL /idp_pkg /tmp/idp_pkg_build

          # Install idp_common[agents] with all transitive deps (strands-agents, bedrock-agentcore)
          pip3 install '/tmp/idp_pkg_build[agents]' -t /build --quiet --no-cache-dir --upgrade

          # Copy idp_common source directly
          mkdir -p /build/idp_common
          cp -rL /tmp/idp_pkg_build/idp_common/. /build/idp_common/

          # Clean up build artifacts (keep dist-info for opentelemetry entry points)
          find /build -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true
          find /build -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
          find /build -type f -name '__editable__*' -delete 2>/dev/null || true
          find /build -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true

          # Create zip from inside the build dir (use python zipfile since zip may not be in the image)
          cd /build && python3 -c \"
import zipfile, os, sys
zf = zipfile.ZipFile('/output/$ZIP_BASENAME', 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.'):
    for file in files:
        if not file.endswith('.pyc'):
            filepath = os.path.join(root, file)
            zf.write(filepath)
zf.close()
print('Zip created: /output/$ZIP_BASENAME')
\"
          echo 'Docker build complete'
        "

      # Write sha256 hash file
      shasum -a 256 "$ABS_ZIP_OUT" | awk '{print $1}' > "$HASH_OUT"

      echo "Build complete: $ABS_ZIP_OUT ($(du -sh "$ABS_ZIP_OUT" | cut -f1))"
    EOT
  }
}

# Read the hash file written by the build — this forces Terraform to re-read it after apply
# The null_resource triggers ensure this file is always fresh when source changes
data "local_file" "agent_chat_processor_hash" {
  count    = var.enable_agent_companion_chat ? 1 : 0
  filename = local.agent_chat_processor_hash_file

  depends_on = [null_resource.build_agent_chat_processor]
}

resource "aws_lambda_function" "agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  function_name    = "${local.api_name}-agent-chat-processor"
  role             = aws_iam_role.agent_chat_processor[0].arn
  filename         = local.agent_chat_processor_zip
  source_code_hash = base64encode(data.local_file.agent_chat_processor_hash[0].content)
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 600
  memory_size      = 1024

  # No layers - all deps bundled into the zip (matches CloudFormation/SAM approach)
  # strands-agents + bedrock-agentcore exceed Lambda's 250MB limit when combined with any layer
  layers = []

  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      STRANDS_LOG_LEVEL            = var.log_level
      CHAT_SESSIONS_TABLE          = aws_dynamodb_table.agent_chat_sessions[0].name
      CHAT_MESSAGES_TABLE          = aws_dynamodb_table.agent_chat_messages[0].name
      ID_HELPER_CHAT_MEMORY_TABLE  = aws_dynamodb_table.agent_chat_memory[0].name
      MEMORY_METHOD                = "dynamodb"
      STREAMING_ENABLED            = "true"
      BEDROCK_REGION               = data.aws_region.current.id
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name != null ? local.configuration_table_name : ""
      TRACKING_TABLE_NAME          = local.tracking_table_name != null ? local.tracking_table_name : ""
      LOOKUP_FUNCTION_NAME         = var.lookup_function_name != null ? var.lookup_function_name : ""
      INPUT_BUCKET                 = local.input_bucket_name
      OUTPUT_BUCKET                = local.output_bucket_name
      APPSYNC_API_URL              = aws_appsync_graphql_api.api.uris["GRAPHQL"]
      MAX_CONVERSATION_TURNS       = "20"
      MAX_MESSAGE_SIZE_KB          = "8.5"
      DATA_RETENTION_DAYS          = tostring(var.data_retention_in_days)
      AWS_STACK_NAME               = local.api_name
      CLOUDWATCH_LOG_GROUP_PREFIX  = "/aws/lambda/${local.api_name}"
      ATHENA_DATABASE              = var.agent_analytics.reporting_database_name != null ? var.agent_analytics.reporting_database_name : ""
      ATHENA_OUTPUT_LOCATION       = var.agent_analytics.reporting_bucket_arn != null ? "s3://${element(split(":", var.agent_analytics.reporting_bucket_arn), length(split(":", var.agent_analytics.reporting_bucket_arn)) - 1)}/athena-results/" : ""
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
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_messages[0].arn,
          "${aws_dynamodb_table.agent_chat_messages[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = compact([local.encryption_key_arn])
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
      LOG_LEVEL                    = var.log_level
      AGENT_CHAT_PROCESSOR_FUNCTION = aws_lambda_function.agent_chat_processor[0].function_name
      AGENT_CHAT_PROCESSOR_ARN     = aws_lambda_function.agent_chat_processor[0].arn
      CHAT_MESSAGES_TABLE          = aws_dynamodb_table.agent_chat_messages[0].name
      CHAT_SESSIONS_TABLE          = aws_dynamodb_table.agent_chat_sessions[0].name
      DATA_RETENTION_DAYS          = tostring(var.data_retention_in_days)
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
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_messages[0].arn,
          "${aws_dynamodb_table.agent_chat_messages[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = compact([local.encryption_key_arn])
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
      LOG_LEVEL            = var.log_level
      CHAT_MESSAGES_TABLE  = aws_dynamodb_table.agent_chat_messages[0].name
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
      CHAT_MESSAGES_TABLE = aws_dynamodb_table.agent_chat_messages[0].name
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
