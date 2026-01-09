# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "api_id" {
  description = "The ID of the AppSync GraphQL API"
  value       = aws_appsync_graphql_api.api.id
}

output "api_name" {
  description = "The name of the AppSync GraphQL API"
  value       = aws_appsync_graphql_api.api.name
}

output "api_arn" {
  description = "The ARN of the AppSync GraphQL API"
  value       = aws_appsync_graphql_api.api.arn
}

output "graphql_url" {
  description = "The URL endpoint for the GraphQL API"
  value       = aws_appsync_graphql_api.api.uris["GRAPHQL"]
}

output "realtime_url" {
  description = "The URL endpoint for the Realtime API"
  value       = aws_appsync_graphql_api.api.uris["REALTIME"]
}

output "api_key" {
  description = "The API key for the GraphQL API (if API key authentication is enabled)"
  value       = var.authorization_config == null || try(var.authorization_config.default_authorization.authorization_type, "API_KEY") == "API_KEY" ? aws_appsync_api_key.api_key[0].key : null
  sensitive   = true
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

output "discovery_bucket_name" {
  description = "Name of the discovery S3 bucket (if discovery is enabled)"
  value       = var.discovery.enabled ? module.discovery[0].discovery_bucket_name : null
}

output "discovery_bucket_arn" {
  description = "ARN of the discovery S3 bucket (if discovery is enabled)"
  value       = var.discovery.enabled ? module.discovery[0].discovery_bucket_arn : null
}

output "chat_with_document_function_name" {
  description = "Name of the Chat with Document Lambda function (if chat is enabled)"
  value       = var.chat_with_document.enabled ? module.chat_with_document[0].chat_with_document_resolver_function_name : null
}

output "chat_with_document_function_arn" {
  description = "ARN of the Chat with Document Lambda function (if chat is enabled)"
  value       = var.chat_with_document.enabled ? module.chat_with_document[0].chat_with_document_resolver_function_arn : null
}
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