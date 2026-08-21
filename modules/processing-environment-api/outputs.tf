# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "api_id" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.http_api.id
}

output "api_name" {
  description = "The name of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.http_api.name
}

output "api_arn" {
  description = "The execution ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.http_api.execution_arn
}

# Base URL of the REST transport (stage 'api'). Mirrors the upstream
# HttpApiEndpoint output. The web UI points VITE_API_BASE_URL here and POSTs to
# ${api_base_url}/op/<field>.
output "api_base_url" {
  description = "Base URL of the REST API transport (stage 'api')."
  value       = "https://${aws_api_gateway_rest_api.http_api.id}.execute-api.${data.aws_region.current.id}.${data.aws_partition.current.dns_suffix}/api"
}

# IAM role API Gateway assumes to read the web-app bucket when serving the SPA
# (serve_web_ui = true). The caller grants this principal s3:GetObject in the
# bucket policy. Null when Web UI hosting on this API is disabled.
output "web_ui_proxy_role_arn" {
  description = "ARN of the IAM role API Gateway uses to read the web-app bucket for the Web UI S3 proxy (null unless serve_web_ui is enabled)."
  value       = local.serve_web_ui ? aws_iam_role.web_ui_proxy[0].arn : null
}

output "http_api_dispatcher_function_arn" {
  description = "ARN of the HTTP API dispatcher Lambda function."
  value       = aws_lambda_function.http_api_dispatcher.arn
}

output "lambda_functions" {
  description = "Map of Lambda function names and ARNs"
  value = {
    get_file_contents = {
      name = aws_lambda_function.get_file_contents_resolver.function_name
      arn  = aws_lambda_function.get_file_contents_resolver.arn
    }
    delete_document = {
      name = aws_lambda_function.delete_document_resolver.function_name
      arn  = aws_lambda_function.delete_document_resolver.arn
    }
    # reprocess_document = {
    #   name = aws_lambda_function.reprocess_document_resolver.function_name
    #   arn  = aws_lambda_function.reprocess_document_resolver.arn
    # }
    upload_document = {
      name = aws_lambda_function.upload_resolver.function_name
      arn  = aws_lambda_function.upload_resolver.arn
    }
    # copy_to_baseline = var.evaluation_baseline_bucket != null ? {
    #   name = aws_lambda_function.copy_to_baseline_resolver[0].function_name
    #   arn  = aws_lambda_function.copy_to_baseline_resolver[0].arn
    # } : null
    configuration = {
      name = aws_lambda_function.configuration_resolver.function_name
      arn  = aws_lambda_function.configuration_resolver.arn
    }
    get_stepfunction_execution = {
      name = aws_lambda_function.get_stepfunction_execution_resolver.function_name
      arn  = aws_lambda_function.get_stepfunction_execution_resolver.arn
    }
    # query_knowledge_base = var.knowledge_base != null ? {
    #   name = aws_lambda_function.query_knowledge_base_resolver[0].function_name
    #   arn  = aws_lambda_function.query_knowledge_base_resolver[0].arn
    # } : null
  }
}

output "edit_sections_enabled" {
  description = "Whether the Edit Sections feature is enabled"
  value       = local.edit_sections_enabled
}

# Chat token-streaming endpoint (v0.6.4). Null when neither chat sub-feature is
# enabled. The Function URL is threaded to the web UI as VITE_STREAM_URL; the
# ARN is consumed at the root to grant the authenticated Cognito role invoke.
output "chat_stream_function_url" {
  description = "Function URL of the chat token-streaming processor (RESPONSE_STREAM). Null when chat streaming is disabled."
  value       = local.chat_stream_enabled ? aws_lambda_function_url.chat_stream[0].function_url : null
}

output "chat_stream_function_arn" {
  description = "ARN of the chat token-streaming processor Lambda. Null when chat streaming is disabled."
  value       = local.chat_stream_enabled ? aws_lambda_function.chat_stream_processor[0].arn : null
}

output "discovery_bucket_name" {
  description = "Name of the discovery S3 bucket (if discovery is enabled)"
  value       = var.discovery.enabled ? module.discovery[0].discovery_bucket_name : null
}

output "discovery_bucket_arn" {
  description = "ARN of the discovery S3 bucket (if discovery is enabled)"
  value       = var.discovery.enabled ? module.discovery[0].discovery_bucket_arn : null
}

# Chat with Document moved to the `chat-with-document` feature submodule
# (modules/features/chat-with-document) in v0.5.12-tf.0. The root reads chat
# Lambda outputs from `module.chat_with_document` directly; the API module no
# longer surfaces them (the legacy synchronous resolver was removed upstream).
# Agent Analytics outputs
output "agent_request_handler_function_arn" {
  description = "ARN of the Agent Request Handler Lambda function (if agent analytics is enabled)"
  value       = var.agent_analytics.enabled ? module.agent_analytics[0].agent_request_handler_function_arn : null
}

output "agent_processor_function_arn" {
  description = "ARN of the Agent Processor Lambda function (if agent analytics is enabled)"
  value       = var.agent_analytics.enabled ? module.agent_analytics[0].agent_processor_function_arn : null
}

output "list_available_agents_function_arn" {
  description = "ARN of the List Available Agents Lambda function (if agent analytics is enabled)"
  value       = var.agent_analytics.enabled ? module.agent_analytics[0].list_available_agents_function_arn : null
}

output "agent_table_arn" {
  description = "ARN of the Agent Analytics DynamoDB table (if agent analytics is enabled)"
  value       = var.agent_analytics.enabled ? module.agent_analytics[0].agent_table_arn : null
}

output "agent_table_name" {
  description = "Name of the Agent Analytics DynamoDB table (if agent analytics is enabled)"
  value       = var.agent_analytics.enabled ? module.agent_analytics[0].agent_table_name : null
}

# MCP Integration outputs
#
# MCP moved to the `mcp-integration` feature submodule (modules/features/
# mcp-integration) in v0.5.12-tf.0 per the feature-plugin model. The root reads
# MCP outputs (gateway endpoint, OAuth client, etc.) from
# `module.mcp_integration` directly; they are no longer surfaced by the API
# module.
