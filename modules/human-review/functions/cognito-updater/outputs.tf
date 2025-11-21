# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_arn" {
  description = "ARN of the Cognito updater Lambda function"
  value       = aws_lambda_function.cognito_updater.arn
}

output "function_name" {
  description = "Name of the Cognito updater Lambda function"
  value       = aws_lambda_function.cognito_updater.function_name
}

output "source_hash" {
  description = "Source code hash of the function"
  value       = data.archive_file.cognito_updater_code.output_base64sha256
}
