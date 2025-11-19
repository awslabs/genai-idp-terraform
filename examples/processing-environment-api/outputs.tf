# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "api_id" {
  description = "The ID of the AppSync GraphQL API"
  value       = module.processing_environment_api.api_id
}

output "graphql_url" {
  description = "The URL endpoint for the GraphQL API"
  value       = module.processing_environment_api.graphql_url
}

output "api_key" {
  description = "The API key for the GraphQL API (if API key authentication is enabled)"
  value       = module.processing_environment_api.api_key
  sensitive   = true
}

output "tracking_table_name" {
  description = "The name of the tracking table"
  value       = element(split("/", module.tracking_table.table_arn), 1)
}

output "configuration_table_name" {
  description = "The name of the configuration table"
  value       = element(split("/", module.configuration_table.table_arn), 1)
}

output "concurrency_table_name" {
  description = "The name of the concurrency table"
  value       = element(split("/", module.concurrency_table.table_arn), 1)
}

output "input_bucket_name" {
  description = "The name of the input bucket"
  value       = aws_s3_bucket.input_bucket.bucket
}

output "output_bucket_name" {
  description = "The name of the output bucket"
  value       = aws_s3_bucket.output_bucket.bucket
}

output "evaluation_baseline_bucket_name" {
  description = "The name of the evaluation baseline bucket"
  value       = aws_s3_bucket.evaluation_baseline_bucket.bucket
}
