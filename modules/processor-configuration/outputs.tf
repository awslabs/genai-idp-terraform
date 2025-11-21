# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "lambda_function_arn" {
  description = "ARN of the configuration seeder Lambda function"
  value       = aws_lambda_function.configuration_seeder.arn
}

output "lambda_function_name" {
  description = "Name of the configuration seeder Lambda function"
  value       = aws_lambda_function.configuration_seeder.function_name
}

output "default_seeded" {
  description = "Result of seeding the Default configuration"
  value       = jsondecode(aws_lambda_invocation.seed_default.result)
}

output "schema_seeded" {
  description = "Result of seeding the Schema"
  value       = jsondecode(aws_lambda_invocation.seed_schema.result)
}
