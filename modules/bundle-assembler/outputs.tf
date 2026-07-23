# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "staging_bucket_name" {
  description = "Name of the staging bucket where loose bundle parts are uploaded"
  value       = aws_s3_bucket.staging.id
}

output "staging_bucket_arn" {
  description = "ARN of the staging bucket"
  value       = aws_s3_bucket.staging.arn
}

output "assembler_function_arn" {
  description = "ARN of the bundle assembler Lambda"
  value       = aws_lambda_function.assembler.arn
}

output "assembler_function_name" {
  description = "Name of the bundle assembler Lambda"
  value       = aws_lambda_function.assembler.function_name
}
