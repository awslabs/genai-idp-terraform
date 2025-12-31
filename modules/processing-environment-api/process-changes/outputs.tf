# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Lambda Function Outputs
# =============================================================================

output "process_changes_resolver_function_name" {
  description = "Name of the Process Changes Resolver Lambda function"
  value       = aws_lambda_function.process_changes_resolver.function_name
}

output "process_changes_resolver_function_arn" {
  description = "ARN of the Process Changes Resolver Lambda function"
  value       = aws_lambda_function.process_changes_resolver.arn
}

output "process_changes_resolver_invoke_arn" {
  description = "Invoke ARN of the Process Changes Resolver Lambda function"
  value       = aws_lambda_function.process_changes_resolver.invoke_arn
}

# =============================================================================
# IAM Role Outputs
# =============================================================================

output "process_changes_resolver_role_arn" {
  description = "ARN of the Process Changes Resolver IAM role"
  value       = aws_iam_role.process_changes_resolver_role.arn
}

output "process_changes_resolver_role_name" {
  description = "Name of the Process Changes Resolver IAM role"
  value       = aws_iam_role.process_changes_resolver_role.name
}

# =============================================================================
# AppSync Resolver Outputs
# =============================================================================

output "process_changes_resolver_name" {
  description = "Name of the AppSync resolver for process changes"
  value       = "${aws_appsync_resolver.process_changes.type}.${aws_appsync_resolver.process_changes.field}"
}

output "process_changes_data_source_name" {
  description = "Name of the AppSync data source for process changes"
  value       = aws_appsync_datasource.process_changes_lambda.name
}