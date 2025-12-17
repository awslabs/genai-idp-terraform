# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Bucket outputs
output "input_bucket_name" {
  description = "Name of the S3 bucket where source documents to be processed are stored"
  value       = local.input_bucket_name
}

output "input_bucket_arn" {
  description = "ARN of the S3 bucket where source documents to be processed are stored"
  value       = var.input_bucket_arn
}

output "output_bucket_name" {
  description = "Name of the S3 bucket where processed documents and extraction results are stored"
  value       = local.output_bucket_name
}

output "output_bucket_arn" {
  description = "ARN of the S3 bucket where processed documents and extraction results are stored"
  value       = var.output_bucket_arn
}

output "working_bucket_name" {
  description = "Name of the S3 bucket used for working files during document processing"
  value       = local.working_bucket_name
}

output "working_bucket_arn" {
  description = "ARN of the S3 bucket used for working files during document processing"
  value       = var.working_bucket_arn
}

# Table outputs
output "configuration_table_name" {
  description = "Name of the DynamoDB table that stores configuration settings"
  value       = local.configuration_table.table_name
}

output "configuration_table_arn" {
  description = "ARN of the DynamoDB table that stores configuration settings"
  value       = local.configuration_table.table_arn
}

output "tracking_table_name" {
  description = "Name of the DynamoDB table that tracks document processing status and metadata"
  value       = local.tracking_table.table_name
}

output "tracking_table_arn" {
  description = "ARN of the DynamoDB table that tracks document processing status and metadata"
  value       = local.tracking_table.table_arn
}

output "concurrency_table_name" {
  description = "Name of the DynamoDB table that manages concurrency limits for document processing"
  value       = local.concurrency_table.table_name
}

output "concurrency_table_arn" {
  description = "ARN of the DynamoDB table that manages concurrency limits for document processing"
  value       = local.concurrency_table.table_arn
}

# Queue outputs
output "document_queue_url" {
  description = "URL of the SQS queue that holds documents waiting to be processed"
  value       = aws_sqs_queue.document_queue.url
}

output "document_queue_arn" {
  description = "ARN of the SQS queue that holds documents waiting to be processed"
  value       = aws_sqs_queue.document_queue.arn
}

# Lambda function outputs
output "queue_sender_function_name" {
  description = "Name of the Lambda function that sends documents to the processing queue"
  value       = aws_lambda_function.queue_sender.function_name
}

output "queue_sender_function_arn" {
  description = "ARN of the Lambda function that sends documents to the processing queue"
  value       = aws_lambda_function.queue_sender.arn
}

output "workflow_tracker_function_name" {
  description = "Name of the Lambda function that tracks workflow execution status"
  value       = aws_lambda_function.workflow_tracker.function_name
}

output "workflow_tracker_function_arn" {
  description = "ARN of the Lambda function that tracks workflow execution status"
  value       = aws_lambda_function.workflow_tracker.arn
}

output "lookup_function_name" {
  description = "Name of the Lambda function that looks up document information from the tracking table"
  value       = aws_lambda_function.lookup_function.function_name
}

output "lookup_function_arn" {
  description = "ARN of the Lambda function that looks up document information from the tracking table"
  value       = aws_lambda_function.lookup_function.arn
}

output "save_reporting_data_function_name" {
  description = "Name of the Lambda function that saves reporting data to the reporting bucket (when reporting is enabled)"
  value       = var.enable_reporting ? aws_lambda_function.save_reporting_data[0].function_name : null
}

output "save_reporting_data_function_arn" {
  description = "ARN of the Lambda function that saves reporting data to the reporting bucket (when reporting is enabled)"
  value       = var.enable_reporting ? aws_lambda_function.save_reporting_data[0].arn : null
}

# API outputs
output "api_id" {
  description = "ID of the GraphQL API that provides interfaces for querying document status and metadata (if provided)"
  value       = var.api != null ? var.api.api_id : null
}

output "api_arn" {
  description = "ARN of the GraphQL API that provides interfaces for querying document status and metadata (if provided)"
  value       = var.api != null ? var.api.api_arn : null
}

output "api_graphql_url" {
  description = "GraphQL URL of the API that provides interfaces for querying document status and metadata (if provided)"
  value       = var.api != null ? var.api.graphql_url : null
}

# VPC outputs
output "vpc_subnet_ids" {
  description = "List of subnet IDs for VPC configuration (if provided)"
  value       = length(var.subnet_ids) > 0 ? var.subnet_ids : null
}

output "vpc_security_group_ids" {
  description = "List of security group IDs for VPC configuration (if provided)"
  value       = length(var.security_group_ids) > 0 ? var.security_group_ids : null
}

# Encryption outputs
output "encryption_key_arn" {
  description = "ARN of the KMS key used for encrypting resources (if provided)"
  value       = var.encryption_key_arn
}

output "encryption_key_id" {
  description = "ID of the KMS key used for encrypting resources (if provided)"
  value       = var.encryption_key_arn != null ? element(split("/", var.encryption_key_arn), 1) : null
}

# Configuration outputs
output "metric_namespace" {
  description = "The namespace for CloudWatch metrics emitted by the document processing system"
  value       = var.metric_namespace
}

output "log_level" {
  description = "The log level for document processing components"
  value       = var.log_level
}

output "log_retention_days" {
  description = "The retention period for CloudWatch logs generated by document processing components"
  value       = var.log_retention_days
}
