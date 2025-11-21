# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_arn" {
  description = "ARN of the Create A2I Resources Lambda function"
  value       = aws_lambda_function.create_a2i_resources.arn
}

output "function_name" {
  description = "Name of the Create A2I Resources Lambda function"
  value       = aws_lambda_function.create_a2i_resources.function_name
}

output "source_hash" {
  description = "Source code hash of the function"
  value       = data.archive_file.create_a2i_resources_code.output_base64sha256
}
