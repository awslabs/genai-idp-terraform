# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_arn" {
  description = "ARN of the Pattern-2 HITL Status Update Lambda function"
  value       = aws_lambda_function.pattern2_hitl_status_update.arn
}

output "function_name" {
  description = "Name of the Pattern-2 HITL Status Update Lambda function"
  value       = aws_lambda_function.pattern2_hitl_status_update.function_name
}

output "source_hash" {
  description = "Source code hash of the function"
  value       = data.archive_file.pattern2_hitl_status_update_code.output_base64sha256
}

output "role_arn" {
  description = "ARN of the IAM role for the function"
  value       = aws_iam_role.pattern2_hitl_status_update_role.arn
}
