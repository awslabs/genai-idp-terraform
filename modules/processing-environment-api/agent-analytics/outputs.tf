# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# DynamoDB Outputs
# =============================================================================

output "agent_table_name" {
  description = "Name of the DynamoDB table for agent job tracking"
  value       = aws_dynamodb_table.agent_jobs.name
}

output "agent_table_arn" {
  description = "ARN of the DynamoDB table for agent job tracking"
  value       = aws_dynamodb_table.agent_jobs.arn
}

# =============================================================================
# Lambda Function Outputs - Request Handler
# =============================================================================

output "agent_request_handler_function_name" {
  description = "Name of the Agent Request Handler Lambda function"
  value       = aws_lambda_function.agent_request_handler.function_name
}

output "agent_request_handler_function_arn" {
  description = "ARN of the Agent Request Handler Lambda function"
  value       = aws_lambda_function.agent_request_handler.arn
}

output "agent_request_handler_invoke_arn" {
  description = "Invoke ARN of the Agent Request Handler Lambda function"
  value       = aws_lambda_function.agent_request_handler.invoke_arn
}

# =============================================================================
# Lambda Function Outputs - Agent Processor
# =============================================================================

output "agent_processor_function_name" {
  description = "Name of the Agent Processor Lambda function"
  value       = aws_lambda_function.agent_processor.function_name
}

output "agent_processor_function_arn" {
  description = "ARN of the Agent Processor Lambda function"
  value       = aws_lambda_function.agent_processor.arn
}

output "agent_processor_invoke_arn" {
  description = "Invoke ARN of the Agent Processor Lambda function"
  value       = aws_lambda_function.agent_processor.invoke_arn
}

# =============================================================================
# Lambda Function Outputs - List Available Agents
# =============================================================================

output "list_available_agents_function_name" {
  description = "Name of the List Available Agents Lambda function"
  value       = aws_lambda_function.list_available_agents.function_name
}

output "list_available_agents_function_arn" {
  description = "ARN of the List Available Agents Lambda function"
  value       = aws_lambda_function.list_available_agents.arn
}

output "list_available_agents_invoke_arn" {
  description = "Invoke ARN of the List Available Agents Lambda function"
  value       = aws_lambda_function.list_available_agents.invoke_arn
}

# =============================================================================
# IAM Role Outputs
# =============================================================================

output "agent_request_handler_role_arn" {
  description = "ARN of the IAM role for Agent Request Handler Lambda"
  value       = aws_iam_role.agent_request_handler_role.arn
}

output "agent_processor_role_arn" {
  description = "ARN of the IAM role for Agent Processor Lambda"
  value       = aws_iam_role.agent_processor_role.arn
}

output "list_available_agents_role_arn" {
  description = "ARN of the IAM role for List Available Agents Lambda"
  value       = aws_iam_role.list_available_agents_role.arn
}

# =============================================================================
# Configuration Outputs
# =============================================================================

output "bedrock_model_id" {
  description = "Bedrock model ID used for the analytics agent"
  value       = var.bedrock_model_id
}
