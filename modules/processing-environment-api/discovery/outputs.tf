# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# S3 Bucket Outputs
# =============================================================================

output "discovery_bucket_name" {
  description = "Name of the discovery S3 bucket"
  value       = aws_s3_bucket.discovery_bucket.id
}

output "discovery_bucket_arn" {
  description = "ARN of the discovery S3 bucket"
  value       = aws_s3_bucket.discovery_bucket.arn
}

output "discovery_bucket_domain_name" {
  description = "Domain name of the discovery S3 bucket"
  value       = aws_s3_bucket.discovery_bucket.bucket_domain_name
}

# =============================================================================
# DynamoDB Outputs
# =============================================================================

output "discovery_tracking_table_name" {
  description = "Name of the DynamoDB table for discovery job tracking"
  value       = aws_dynamodb_table.discovery_tracking.name
}

output "discovery_tracking_table_arn" {
  description = "ARN of the DynamoDB table for discovery job tracking"
  value       = aws_dynamodb_table.discovery_tracking.arn
}

# =============================================================================
# SQS Outputs
# =============================================================================

output "discovery_queue_url" {
  description = "URL of the SQS queue for discovery job processing"
  value       = aws_sqs_queue.discovery_queue.url
}

output "discovery_queue_arn" {
  description = "ARN of the SQS queue for discovery job processing"
  value       = aws_sqs_queue.discovery_queue.arn
}

output "discovery_dlq_url" {
  description = "URL of the SQS dead letter queue for failed discovery jobs"
  value       = aws_sqs_queue.discovery_dlq.url
}

output "discovery_dlq_arn" {
  description = "ARN of the SQS dead letter queue for failed discovery jobs"
  value       = aws_sqs_queue.discovery_dlq.arn
}

# =============================================================================
# Lambda Function Outputs - Upload Resolver
# =============================================================================

output "discovery_upload_resolver_function_name" {
  description = "Name of the Discovery Upload Resolver Lambda function"
  value       = aws_lambda_function.discovery_upload_resolver.function_name
}

output "discovery_upload_resolver_function_arn" {
  description = "ARN of the Discovery Upload Resolver Lambda function"
  value       = aws_lambda_function.discovery_upload_resolver.arn
}

output "discovery_upload_resolver_invoke_arn" {
  description = "Invoke ARN of the Discovery Upload Resolver Lambda function"
  value       = aws_lambda_function.discovery_upload_resolver.invoke_arn
}

# =============================================================================
# Lambda Function Outputs - Processor
# =============================================================================

output "discovery_processor_function_name" {
  description = "Name of the Discovery Processor Lambda function"
  value       = aws_lambda_function.discovery_processor.function_name
}

output "discovery_processor_function_arn" {
  description = "ARN of the Discovery Processor Lambda function"
  value       = aws_lambda_function.discovery_processor.arn
}

output "discovery_processor_invoke_arn" {
  description = "Invoke ARN of the Discovery Processor Lambda function"
  value       = aws_lambda_function.discovery_processor.invoke_arn
}