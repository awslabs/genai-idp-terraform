# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Chat token-streaming endpoint (v0.6.4) — upstream ChatStreamProcessorFunction
# + Lambda Function URL (AWS::Lambda::Url).
#
# A FastAPI/uvicorn app fronted by the AWS Lambda Web Adapter (LWA) streams
# chat tokens over a Function URL (RESPONSE_STREAM). The browser POSTs
# SigV4-signed requests directly to the Function URL; the authenticated Cognito
# Identity Pool role is granted lambda:InvokeFunction(+Url) at the root
# (mirrors upstream CognitoAuthorizedRole ChatStreamInvoke).
#
# Co-located with the agent-companion chat tables (agent-companion-chat.tf): the
# streaming app imports BOTH vendored processor modules, so it needs both the
# base and agents layers plus the thin web stack (fastapi/uvicorn) which ships
# as a co-built deps layer. Gated on chat being enabled by either sub-feature.

locals {
  # Enabled when EITHER chat sub-feature is on. Chat-with-document may be on
  # while agent-companion-chat is off, so every reference to the agent chat
  # tables below is conditional on var.enable_agent_companion_chat.
  chat_stream_enabled = var.enable_agent_companion_chat || try(var.chat_with_document.enabled, false)

  # Source package + build staging (mirrors agent_chat_processor's build dirs).
  chat_stream_src       = "${path.module}/../../sources/src/lambda/chat_stream_processor"
  chat_stream_build_dir = "${path.module}/../../.terraform/tmp/chat_stream_processor_build"
  chat_stream_zip       = "${path.module}/../../.terraform/archives/chat_stream_processor.zip"

  # Deterministic input hash over the first-party files the package carries
  # (deps come from the layer, not the zip). Drives the build trigger, the
  # aws_s3_object etag, and the function's source_code_hash so plan converges
  # before the zip exists on disk.
  chat_stream_package_hash = sha256(join("", [
    filesha256("${local.chat_stream_src}/app.py"),
    filesha256("${local.chat_stream_src}/sse.py"),
    filesha256("${local.chat_stream_src}/run.sh"),
    filesha256("${local.chat_stream_src}/vendored/chat_with_document_processor.py"),
    filesha256("${local.chat_stream_src}/vendored/agent_chat_processor.py"),
  ]))

  # Bucket for the package zip (same assets bucket used for Lambda layers).
  # Bucket name from the ARN, matching lambda-layer-codebuild/local-build.
  chat_stream_bucket_name = var.lambda_layers_bucket_arn != null ? split(":::", var.lambda_layers_bucket_arn)[1] : ""
  chat_stream_s3_key      = "chat-stream-package/chat_stream_${random_string.suffix.result}.zip"

  # LWA layer: use the supplied ARN or construct the upstream default.
  chat_stream_lwa_layer_arn = var.lambda_web_adapter_layer_arn != "" ? var.lambda_web_adapter_layer_arn : "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:753240598075:layer:LambdaAdapterLayerX86:25"

  # ConfigurationBucket (reuse the configuration_resolver expression) + its ARN.
  chat_stream_config_bucket_name = local.configuration_table_name != null ? "${local.api_name}-config" : ""

  # Reporting bucket name from the ARN when agent analytics reporting is wired.
  chat_stream_reporting_bucket_name = var.agent_analytics.reporting_bucket_arn != null ? element(split(":", var.agent_analytics.reporting_bucket_arn), length(split(":", var.agent_analytics.reporting_bucket_arn)) - 1) : ""

  # Agent chat table names/arns — only exist under enable_agent_companion_chat.
  chat_stream_messages_table_name = var.enable_agent_companion_chat ? aws_dynamodb_table.agent_chat_messages[0].name : ""
  chat_stream_sessions_table_name = var.enable_agent_companion_chat ? aws_dynamodb_table.agent_chat_sessions[0].name : ""
  chat_stream_memory_table_name   = var.enable_agent_companion_chat ? aws_dynamodb_table.agent_chat_memory[0].name : ""

  chat_stream_chat_table_arns = var.enable_agent_companion_chat ? [
    aws_dynamodb_table.agent_chat_sessions[0].arn,
    aws_dynamodb_table.agent_chat_messages[0].arn,
    aws_dynamodb_table.agent_chat_memory[0].arn,
  ] : []
}

# =============================================================================
# Deps layer (fastapi/uvicorn/boto3) — host/local build, honors build flags
# =============================================================================
# Instantiated via the shared lambda-layer-codebuild dispatcher so it honors
# lambda_local / lambda_architecture / container_runtime exactly like every
# other layer in the stack. idp_common (bedrock/appsync/config/agents) is NOT
# here — it ships in the base + agents layers attached to the function.
module "chat_stream_deps_layer" {
  count  = local.chat_stream_enabled ? 1 : 0
  source = "../lambda-layer-codebuild"

  name_prefix              = "chat-stream-${random_string.suffix.result}"
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn
  lambda_local             = var.lambda_local
  lambda_architecture      = var.lambda_architecture
  container_runtime        = var.container_runtime
  lambda_tracing_mode      = var.lambda_tracing_mode

  requirements_files = {
    chat_stream = file("${path.module}/../../sources/src/lambda/chat_stream_processor/requirements.txt")
  }
}

# =============================================================================
# Function package staging (mirror the Makefile's non-pip part) + S3 upload
# =============================================================================
resource "null_resource" "build_chat_stream_package" {
  count = local.chat_stream_enabled ? 1 : 0

  triggers = {
    package_hash = local.chat_stream_package_hash
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/build-chat-stream-package.sh"

    environment = {
      SRC_DIR   = local.chat_stream_src
      BUILD_DIR = local.chat_stream_build_dir
      ZIP_OUT   = local.chat_stream_zip
    }
  }
}

# Upload the staged zip to the assets bucket. Etag is tied to the input hash
# (not the zip bytes) so plan converges before the file is produced, matching
# modules/lambda-layer-local-build's aws_s3_object idiom.
resource "aws_s3_object" "chat_stream_package" {
  count = local.chat_stream_enabled ? 1 : 0

  bucket = local.chat_stream_bucket_name
  key    = local.chat_stream_s3_key
  source = local.chat_stream_zip
  etag   = local.chat_stream_package_hash

  depends_on = [null_resource.build_chat_stream_package]
}

# =============================================================================
# IAM role + policy (mirror upstream ChatStreamProcessorFunction policies)
# =============================================================================
resource "aws_iam_role" "chat_stream_processor" {
  count = local.chat_stream_enabled ? 1 : 0

  name = "${local.api_name}-chat-stream-processor"

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

resource "aws_iam_role_policy" "chat_stream_processor" {
  count = local.chat_stream_enabled ? 1 : 0

  name = "chat-stream-processor-policy"
  role = aws_iam_role.chat_stream_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
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
          # S3 read + write on the output bucket (mirrors upstream S3Read/Write).
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            local.output_bucket_arn,
            "${local.output_bucket_arn}/*"
          ]
        },
        {
          # bedrock model invocation (foundation + inference-profile +
          # application-inference-profile) for streaming responses.
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream",
            "bedrock:GetInferenceProfile"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
            "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
            "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:application-inference-profile/*"
          ]
        },
        {
          # OpenAI GPT-5.x models served via the bedrock-mantle endpoint.
          Effect = "Allow"
          Action = [
            "bedrock-mantle:CreateInference",
            "bedrock-mantle:GetProject",
            "bedrock-mantle:ListProjects",
            "bedrock-mantle:ListTagsForResources"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:InvokeAgentRuntime",
            "bedrock-agentcore:StartCodeInterpreterSession",
            "bedrock-agentcore:StopCodeInterpreterSession",
            "bedrock-agentcore:InvokeCodeInterpreter",
            "bedrock-agentcore:GetCodeInterpreterSession",
            "bedrock-agentcore:ListCodeInterpreterSessions"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "aws-marketplace:Subscribe",
            "aws-marketplace:Unsubscribe",
            "aws-marketplace:ViewSubscriptions"
          ]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = ["cloudwatch:PutMetricData"]
          Resource = "*"
        },
        {
          # feature-platform installed-features parameter + FeaturePlatformStack
          # tables, scoped to this stack's naming (mirrors upstream).
          Effect   = "Allow"
          Action   = ["ssm:GetParameter"]
          Resource = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/${local.api_name}/feature-platform/installed-features-table"
        },
        {
          Effect   = "Allow"
          Action   = ["dynamodb:Scan", "dynamodb:GetItem"]
          Resource = "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${local.api_name}-FeaturePlatformStack-*"
        },
        {
          # Full KMS set (mirrors upstream): the processor reads AND writes the
          # KMS-encrypted chat/config tables and output/reporting buckets.
          Effect   = "Allow"
          Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
          Resource = local.kms_policy_resource_arn
        },
        {
          # The agent-chat processor invokes the document Lookup function and
          # other in-stack helper Lambdas. Scoped to the Lookup function and the
          # API module's own function-name prefix (mirrors upstream ${Stack}*).
          Effect = "Allow"
          Action = ["lambda:InvokeFunction"]
          Resource = compact([
            "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${local.api_name}*",
            try(var.lookup_function_name, "") != "" ? "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${var.lookup_function_name}" : "",
          ])
        },
        {
          # Error Analyzer agent (in companion chat) reads CloudWatch logs.
          # Scoped to this API's Lambda + Step Functions vended log groups.
          Effect = "Allow"
          Action = ["logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:FilterLogEvents", "logs:GetLogEvents"]
          Resource = [
            "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.api_name}*",
            "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/*",
            "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/${local.api_name}*",
          ]
        },
        {
          # Error Analyzer agent reads Step Functions execution history. Scoped
          # to region/account (processor state-machine names are owned by the
          # processor modules and not known to this module); read-only.
          Effect   = "Allow"
          Action   = ["states:DescribeExecution", "states:GetExecutionHistory"]
          Resource = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:execution:*"
        },
        {
          # Error Analyzer agent reads X-Ray traces (read-only, resource-less).
          Effect   = "Allow"
          Action   = ["xray:GetTraceSummaries", "xray:BatchGetTraces", "xray:GetServiceGraph"]
          Resource = "*"
        },
        {
          # Feature-hook dispatch (idp:feature-id tag condition, mirrors upstream).
          Effect   = "Allow"
          Action   = ["sqs:SendMessage"]
          Resource = "arn:${data.aws_partition.current.partition}:sqs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"
          Condition = {
            StringLike = { "aws:ResourceTag/idp:feature-id" = "*" }
          }
        }
      ],
      # Configuration table CRUD (when a configuration table is wired).
      local.configuration_table_arn != null ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem"
          ]
          Resource = [
            local.configuration_table_arn,
            "${local.configuration_table_arn}/index/*"
          ]
        }
      ] : [],
      # Tracking table read (when a tracking table is wired).
      local.tracking_table_arn != null ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchGetItem"
          ]
          Resource = [
            local.tracking_table_arn,
            "${local.tracking_table_arn}/index/*"
          ]
        }
      ] : [],
      # Agent chat tables CRUD (only exist under enable_agent_companion_chat).
      length(local.chat_stream_chat_table_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem"
          ]
          Resource = concat(
            local.chat_stream_chat_table_arns,
            [for arn in local.chat_stream_chat_table_arns : "${arn}/index/*"]
          )
        }
      ] : [],
      # s3:GetObject on the configuration bucket's config_library (when present).
      local.chat_stream_config_bucket_name != "" ? [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject"]
          Resource = "arn:${data.aws_partition.current.partition}:s3:::${local.chat_stream_config_bucket_name}/config_library/*"
        }
      ] : [],
      # Reporting bucket S3 CRUD (when agent analytics reporting is wired).
      local.chat_stream_reporting_bucket_name != "" ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::${local.chat_stream_reporting_bucket_name}",
            "arn:${data.aws_partition.current.partition}:s3:::${local.chat_stream_reporting_bucket_name}/*"
          ]
        }
      ] : [],
      # ssm:GetParameter on the web-ui settings parameter (when the UI is on).
      var.settings_parameter_name != "" ? [
        {
          Effect   = "Allow"
          Action   = ["ssm:GetParameter"]
          Resource = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${var.settings_parameter_name}"
        }
      ] : [],
      # Analytics agent (in companion chat) queries the reporting tables via
      # Athena/Glue — only usable when reporting is wired (ATHENA_* env set).
      var.agent_analytics.reporting_database_name != null ? [
        {
          Effect = "Allow"
          Action = ["athena:StartQueryExecution", "athena:GetQueryExecution", "athena:GetQueryResults", "athena:StopQueryExecution"]
          Resource = [
            "arn:${data.aws_partition.current.partition}:athena:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:workgroup/primary",
            "arn:${data.aws_partition.current.partition}:athena:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:datacatalog/*",
          ]
        },
        {
          Effect = "Allow"
          Action = ["glue:GetTable", "glue:GetTables", "glue:GetDatabase", "glue:GetDatabases", "glue:GetPartitions"]
          Resource = [
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:catalog",
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:database/${var.agent_analytics.reporting_database_name}",
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.agent_analytics.reporting_database_name}/*",
          ]
        }
      ] : [],
      # RBAC scope enforcement — query UsersTable (+ its indexes) when RBAC is on.
      var.users_table_name != "" ? [
        {
          Effect = "Allow"
          Action = ["dynamodb:Query", "dynamodb:GetItem"]
          Resource = [
            "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}",
            "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}/index/*",
          ]
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "chat_stream_processor_xray" {
  count      = local.chat_stream_enabled ? 1 : 0
  role       = aws_iam_role.chat_stream_processor[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# IAM eventual-consistency guard (project convention — see terraform-conventions
# steering). Keeps behaviour consistent with the other Lambda-provisioning code
# in this module (dispatcher, etc.).
resource "time_sleep" "chat_stream_iam_propagation" {
  count           = local.chat_stream_enabled ? 1 : 0
  create_duration = "30s"

  triggers = {
    role_arn = aws_iam_role.chat_stream_processor[0].arn
    policy   = aws_iam_role_policy.chat_stream_processor[0].id
  }
}

# =============================================================================
# Lambda function + log group
# =============================================================================
resource "aws_cloudwatch_log_group" "chat_stream_processor" {
  count             = local.chat_stream_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-chat-stream-processor"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "chat_stream_processor" {
  count = local.chat_stream_enabled ? 1 : 0

  architectures    = [var.lambda_architecture]
  function_name    = "${local.api_name}-chat-stream-processor"
  role             = aws_iam_role.chat_stream_processor[0].arn
  s3_bucket        = aws_s3_object.chat_stream_package[0].bucket
  s3_key           = aws_s3_object.chat_stream_package[0].key
  source_code_hash = local.chat_stream_package_hash
  # LWA boots run.sh (uvicorn) via the /opt/bootstrap exec wrapper.
  handler     = "run.sh"
  runtime     = "python3.12"
  memory_size = 4096
  timeout     = 900
  description = "Chat token-streaming processor (FastAPI/uvicorn under LWA, RESPONSE_STREAM Function URL)"

  kms_key_arn = local.encryption_key_arn

  # Base (bedrock/appsync/config) + agents (strands) — the streaming app imports
  # both processor modules so it needs both layers. Deps layer supplies the thin
  # web stack (fastapi/uvicorn). LWA layer last.
  layers = compact([
    var.base_layer_arn,
    var.agents_layer_arn,
    module.chat_stream_deps_layer[0].layer_arns["chat_stream"],
    local.chat_stream_lwa_layer_arn
  ])

  environment {
    variables = {
      # LWA: run the app in response-streaming mode and wrap exec with LWA.
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/bootstrap"
      AWS_LWA_INVOKE_MODE     = "response_stream"
      PORT                    = "8080"
      LOG_LEVEL               = var.log_level

      # Shared / doc-chat processor env (mirrors ChatWithDocumentProcessor).
      OUTPUT_BUCKET            = local.output_bucket_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name != null ? local.configuration_table_name : ""
      CONFIGURATION_BUCKET     = local.chat_stream_config_bucket_name
      TRACKING_TABLE_NAME      = local.tracking_table_name != null ? local.tracking_table_name : ""
      USERS_TABLE_NAME         = var.users_table_name
      # No guardrail plumbed into the streaming endpoint (kept empty).
      GUARDRAIL_ID_AND_VERSION = ""

      # Agent-chat processor env (mirrors AgentChatProcessorFunction).
      LOOKUP_FUNCTION_NAME        = var.lookup_function_name != null ? var.lookup_function_name : ""
      STRANDS_LOG_LEVEL           = var.log_level
      BEDROCK_REGION              = data.aws_region.current.id
      CHAT_MESSAGES_TABLE         = local.chat_stream_messages_table_name
      CHAT_SESSIONS_TABLE         = local.chat_stream_sessions_table_name
      ID_HELPER_CHAT_MEMORY_TABLE = local.chat_stream_memory_table_name
      MEMORY_METHOD               = "dynamodb"
      MAIN_STACK_NAME             = local.api_name
      STREAMING_ENABLED           = "true"
      MAX_CONVERSATION_TURNS      = "20"
      MAX_MESSAGE_SIZE_KB         = "8.5"
      DATA_RETENTION_DAYS         = tostring(var.data_retention_in_days)
      ATHENA_DATABASE             = var.agent_analytics.reporting_database_name != null ? var.agent_analytics.reporting_database_name : ""
      ATHENA_OUTPUT_LOCATION      = local.chat_stream_reporting_bucket_name != "" ? "s3://${local.chat_stream_reporting_bucket_name}/athena-results/" : ""
      AWS_STACK_NAME              = local.api_name
      CLOUDWATCH_LOG_GROUP_PREFIX = "/aws/lambda/${local.api_name}"
      SETTINGS_PARAMETER_NAME     = var.settings_parameter_name
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.chat_stream_processor[0].name
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

  depends_on = [
    aws_cloudwatch_log_group.chat_stream_processor,
    time_sleep.chat_stream_iam_propagation,
  ]

  tags = var.tags
}

# =============================================================================
# Function URL (IAM-authed, response streaming) + invoke permission
# =============================================================================
resource "aws_lambda_function_url" "chat_stream" {
  count = local.chat_stream_enabled ? 1 : 0

  function_name      = aws_lambda_function.chat_stream_processor[0].function_name
  authorization_type = "AWS_IAM"
  invoke_mode        = "RESPONSE_STREAM"

  cors {
    allow_credentials = false
    allow_methods     = ["POST"]
    allow_headers     = ["content-type", "authorization", "x-amz-date", "x-amz-content-sha256", "x-amz-security-token"]
    allow_origins     = ["*"]
    max_age           = 600
  }
}

# Allow the authenticated Cognito Identity Pool role to invoke the Function URL
# (AuthType=AWS_IAM requires both the resource permission here and the
# lambda:InvokeFunction(+Url) grant on the caller's role — see the root
# chat_stream_invoke policy). Principal is the account: for AWS_IAM the actual
# gate is the caller's IAM identity policy; a role-ARN principal is not accepted.
resource "aws_lambda_permission" "chat_stream_url" {
  count = local.chat_stream_enabled ? 1 : 0

  statement_id           = "AllowCognitoInvokeChatStreamUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.chat_stream_processor[0].function_name
  principal              = data.aws_caller_identity.current.account_id
  function_url_auth_type = "AWS_IAM"
}
