# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "installed_features_table_name" {
  description = "Name of the InstalledFeatures registry table."
  value       = aws_dynamodb_table.installed_features.name
}

output "installed_features_table_arn" {
  description = "ARN of the InstalledFeatures registry table."
  value       = aws_dynamodb_table.installed_features.arn
}

output "function_arns" {
  description = "Map of feature-platform Lambda function name -> ARN."
  value       = { for k, f in aws_lambda_function.feature : k => f.arn }
}
