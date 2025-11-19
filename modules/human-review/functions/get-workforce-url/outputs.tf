# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_arn" {
  description = "ARN of the Get Workforce URL Lambda function"
  value       = aws_lambda_function.get_workforce_url.arn
}

output "function_name" {
  description = "Name of the Get Workforce URL Lambda function"
  value       = aws_lambda_function.get_workforce_url.function_name
}

output "source_hash" {
  description = "Source code hash of the function"
  value       = data.archive_file.get_workforce_url_code.output_base64sha256
}
