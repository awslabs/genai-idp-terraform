# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_arn" {
  description = "ARN of the Pattern-2 HITL Process Lambda function"
  value       = aws_lambda_function.pattern2_hitl_process.arn
}

output "function_name" {
  description = "Name of the Pattern-2 HITL Process Lambda function"
  value       = aws_lambda_function.pattern2_hitl_process.function_name
}

output "source_hash" {
  description = "Source code hash of the function"
  value       = data.archive_file.pattern2_hitl_process_code.output_base64sha256
}

output "role_arn" {
  description = "ARN of the IAM role for the function"
  value       = aws_iam_role.pattern2_hitl_process_role.arn
}
