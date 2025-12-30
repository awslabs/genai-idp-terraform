# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Lambda Function Outputs
# =============================================================================

output "chat_with_document_resolver_function_name" {
  description = "Name of the Chat with Document Resolver Lambda function"
  value       = aws_lambda_function.chat_with_document_resolver.function_name
}

output "chat_with_document_resolver_function_arn" {
  description = "ARN of the Chat with Document Resolver Lambda function"
  value       = aws_lambda_function.chat_with_document_resolver.arn
}

output "chat_with_document_resolver_invoke_arn" {
  description = "Invoke ARN of the Chat with Document Resolver Lambda function"
  value       = aws_lambda_function.chat_with_document_resolver.invoke_arn
}

# =============================================================================
# AppSync Outputs
# =============================================================================

output "chat_with_document_datasource_name" {
  description = "Name of the AppSync data source for chat with document"
  value       = aws_appsync_datasource.chat_with_document_lambda.name
}

output "chat_with_document_resolver_name" {
  description = "Name of the AppSync resolver for chat with document"
  value       = "${aws_appsync_resolver.chat_with_document.type}.${aws_appsync_resolver.chat_with_document.field}"
}