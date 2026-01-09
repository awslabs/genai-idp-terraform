# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Agent Analytics Module
 *
 * This module creates the infrastructure for the Agent Analytics feature, which enables
 * natural language querying of processed document data. The Agent Analytics module
 * converts natural language questions to SQL queries, executes them against Athena,
 * and generates interactive visualizations.
 *
 * ## Features
 * - Natural language to SQL query conversion
 * - Interactive visualization generation
 * - Bedrock-powered analytics agent
 * - DynamoDB-based job tracking with TTL
 * - AppSync integration for real-time status updates
 */

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Generate unique suffix for resource names
  suffix = random_string.suffix.result

  # Extract bucket names from ARNs
  athena_results_bucket_name = element(split(":", var.athena_results_bucket_arn), 5)
  reporting_bucket_name      = element(split(":", var.reporting_bucket_arn), 5)

  # Module build directory for Lambda archives
  module_build_dir = "${path.module}/.terraform-build"

  # Helper function to generate model permissions for bedrock_model_id
  # This follows the same pattern as processing-environment-api
  bedrock_model_permissions = {
    # Parse model information
    is_arn               = startswith(var.bedrock_model_id, "arn:")
    is_inference_profile = !startswith(var.bedrock_model_id, "arn:") && (startswith(var.bedrock_model_id, "us.") || startswith(var.bedrock_model_id, "eu.") || startswith(var.bedrock_model_id, "apac."))
    base_model_id        = (startswith(var.bedrock_model_id, "us.") || startswith(var.bedrock_model_id, "eu.") || startswith(var.bedrock_model_id, "apac.")) ? substr(var.bedrock_model_id, 3, -1) : var.bedrock_model_id

    # Foundation model statement (always needed)
    # For inference profiles, we need permissions for the underlying foundation model (without prefix)
    foundation_statement = {
      effect = "Allow"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:GetFoundationModel"
      ]
      resources = [
        # For ARNs that are not inference profiles, use as-is
        # For inference profiles, create foundation model ARN with base model ID (no prefix)
        # For regular model IDs, create foundation model ARN as-is
        startswith(var.bedrock_model_id, "arn:") && !contains(split(":", var.bedrock_model_id), "inference-profile") ?
        var.bedrock_model_id :
        "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${(startswith(var.bedrock_model_id, "us.") || startswith(var.bedrock_model_id, "eu.") || startswith(var.bedrock_model_id, "apac.")) ? substr(var.bedrock_model_id, 3, -1) : var.bedrock_model_id}"
      ]
    }

    # Inference profile statement (only for inference profiles)
    inference_profile_statement = (!startswith(var.bedrock_model_id, "arn:") && (startswith(var.bedrock_model_id, "us.") || startswith(var.bedrock_model_id, "eu.") || startswith(var.bedrock_model_id, "apac."))) ? {
      effect = "Allow"
      actions = [
        "bedrock:GetInferenceProfile",
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      resources = [
        "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}"
      ]
    } : null
  }
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# =============================================================================
# Dedicated IDP Common Layer for Agent Analytics
# =============================================================================

# Create a dedicated lightweight idp_common_layer for agent analytics
# This includes only the necessary extras: core, agents, and appsync
# This avoids the 262MB layer limit issue by not including heavy dependencies like OCR, image processing, etc.
module "agent_analytics_idp_layer" {
  source = "../../idp-common-layer"

  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn
  layer_prefix             = "agent-analytics-${local.suffix}"

  # Only include necessary extras for agent analytics
  idp_common_extras = ["core", "appsync"]

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  # Force rebuild if needed
  force_rebuild = false
}

# =============================================================================
# Agent-Specific Dependencies Layer
# =============================================================================

# Create a minimal layer with only agent-specific dependencies
# This is separate from idp_common to keep the layer size manageable
locals {
  agent_requirements = {
    agents = join("\n", [
      "strands-agents>=1.0.0",
      "strands-agents-tools>=0.2.2",
      "bedrock-agentcore>=0.1.1",
      "regex>=2024.0.0,<2026.0.0"
    ])
  }
}

module "agent_dependencies_layer" {
  source = "../../lambda-layer-codebuild"

  name_prefix              = "agent-deps-${local.suffix}"
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn

  requirements_files = local.agent_requirements

  # Calculate hash of requirements to trigger rebuilds
  requirements_hash = md5(local.agent_requirements.agents)

  # Don't force rebuild unless requirements change
  force_rebuild = false

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode
}


# =============================================================================
# DynamoDB Table for Agent Job Tracking
# =============================================================================

resource "aws_dynamodb_table" "agent_jobs" {
  name         = "${var.name_prefix}-agent-jobs-${local.suffix}"
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
    attribute_name = "expiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
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
# Agent Request Handler Lambda Function
# =============================================================================

# Generate unique build ID for request handler
resource "random_id" "request_handler_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("agent-request-handler")
  }
}

# Source code archive for request handler
data "archive_file" "agent_request_handler_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/agent_request_handler"
  output_path = "${local.module_build_dir}/agent-request-handler.zip_${random_id.request_handler_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Agent Request Handler Lambda function
resource "aws_lambda_function" "agent_request_handler" {
  function_name = "${var.name_prefix}-agent-request-${local.suffix}"

  filename         = data.archive_file.agent_request_handler_code.output_path
  source_code_hash = data.archive_file.agent_request_handler_code.output_base64sha256

  layers = [module.agent_analytics_idp_layer.layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256
  role        = aws_iam_role.agent_request_handler_role.arn
  description = "Handles agent query requests and creates job records"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      AGENT_TABLE              = aws_dynamodb_table.agent_jobs.name
      AGENT_PROCESSOR_FUNCTION = aws_lambda_function.agent_processor.function_name
      DATA_RETENTION_DAYS      = var.data_retention_days
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

  tags = var.tags

  depends_on = [aws_lambda_function.agent_processor]
}

# CloudWatch Log Group for request handler
resource "aws_cloudwatch_log_group" "agent_request_handler_logs" {
  name              = "/aws/lambda/${aws_lambda_function.agent_request_handler.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# Agent Processor Lambda Function
# =============================================================================

# Generate unique build ID for processor
resource "random_id" "processor_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("agent-processor")
  }
}

# Source code archive for processor
data "archive_file" "agent_processor_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/agent_processor"
  output_path = "${local.module_build_dir}/agent-processor.zip_${random_id.processor_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Agent Processor Lambda function
resource "aws_lambda_function" "agent_processor" {
  function_name = "${var.name_prefix}-agent-processor-${local.suffix}"

  filename         = data.archive_file.agent_processor_code.output_path
  source_code_hash = data.archive_file.agent_processor_code.output_base64sha256

  layers = [
    module.agent_analytics_idp_layer.layer_arn,
    lookup(module.agent_dependencies_layer.layer_arns, "agents", null)
  ]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 900 # 15 minutes for complex queries
  memory_size = 1024
  role        = aws_iam_role.agent_processor_role.arn
  description = "Processes agent queries using Strands agents and Bedrock"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                        = var.log_level
      CONFIGURATION_TABLE_NAME         = var.configuration_table_name
      STRANDS_LOG_LEVEL                = var.log_level
      AGENT_TABLE                      = aws_dynamodb_table.agent_jobs.name
      APPSYNC_API_URL                  = var.appsync_api_url
      ATHENA_DATABASE                  = var.reporting_database_name
      ATHENA_OUTPUT_LOCATION           = "s3://${local.reporting_bucket_name}/athena-results/"
      DOCUMENT_ANALYSIS_AGENT_MODEL_ID = var.bedrock_model_id
      AWS_STACK_NAME                   = "terraform-${var.name_prefix}"
      GUARDRAIL_ID_AND_VERSION         = ""
      METRIC_NAMESPACE                 = "GenAI/IDP/AgentAnalytics"
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

  tags = var.tags
}

# CloudWatch Log Group for processor
resource "aws_cloudwatch_log_group" "agent_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.agent_processor.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# List Available Agents Lambda Function
# =============================================================================

# Generate unique build ID for list agents
resource "random_id" "list_agents_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("list-available-agents")
  }
}

# Source code archive for list agents
data "archive_file" "list_available_agents_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/list_available_agents"
  output_path = "${local.module_build_dir}/list-available-agents.zip_${random_id.list_agents_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# List Available Agents Lambda function
resource "aws_lambda_function" "list_available_agents" {
  function_name = "${var.name_prefix}-list-agents-${local.suffix}"

  filename         = data.archive_file.list_available_agents_code.output_path
  source_code_hash = data.archive_file.list_available_agents_code.output_base64sha256

  layers = [
    module.agent_analytics_idp_layer.layer_arn,
    lookup(module.agent_dependencies_layer.layer_arns, "agents", null)
  ]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256
  role        = aws_iam_role.list_available_agents_role.arn
  description = "Lists all available agents from the agent factory"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL = var.log_level
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

  tags = var.tags
}

# CloudWatch Log Group for list agents
resource "aws_cloudwatch_log_group" "list_available_agents_logs" {
  name              = "/aws/lambda/${aws_lambda_function.list_available_agents.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}


# =============================================================================
# AppSync Lambda Permissions
# =============================================================================

# Permission for AppSync to invoke Agent Request Handler
resource "aws_lambda_permission" "appsync_agent_request_handler" {
  statement_id  = "AllowAppSyncInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agent_request_handler.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.current.partition}:appsync:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:apis/${var.appsync_api_id}/*"
}

# Permission for AppSync to invoke List Available Agents
resource "aws_lambda_permission" "appsync_list_available_agents" {
  statement_id  = "AllowAppSyncInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_available_agents.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.current.partition}:appsync:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:apis/${var.appsync_api_id}/*"
}

# =============================================================================
# Bedrock Agent Configuration
# =============================================================================
# The Agent Analytics feature uses the Strands framework with Amazon Bedrock
# foundation models. The agent configuration is managed through the idp_common
# agents module, which provides:
#
# 1. Analytics Agent - Converts natural language to SQL queries and generates
#    visualizations from document processing data
#
# 2. Tool Definitions:
#    - get_database_info: Retrieves Glue database schema information
#    - execute_athena_query: Runs SQL queries against Athena
#    - code_interpreter: Executes Python code in Bedrock AgentCore sandbox
#
# The agent is configured at runtime through environment variables and the
# idp_common.agents.analytics module. Key configuration:
#
# - BEDROCK_MODEL_ID: The foundation model to use (default: Claude 3.5 Sonnet)
# - ATHENA_DATABASE: The Glue database containing document processing tables
# - ATHENA_RESULTS_BUCKET: S3 bucket for query results
#
# Agent Factory Pattern:
# The agent factory (idp_common.agents.factory) provides a registry of available
# agents. New agents can be registered by implementing the agent interface and
# registering with the factory. This allows for extensibility without modifying
# the Lambda function code.

