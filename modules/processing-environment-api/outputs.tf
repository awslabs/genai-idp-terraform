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
    publish_stepfunction_update = {
      name = aws_lambda_function.publish_stepfunction_update_resolver.function_name
      arn  = aws_lambda_function.publish_stepfunction_update_resolver.arn
    }
    # query_knowledge_base = var.knowledge_base != null ? {
    #   name = aws_lambda_function.query_knowledge_base_resolver[0].function_name
    #   arn  = aws_lambda_function.query_knowledge_base_resolver[0].arn
    # } : null
  }
}
