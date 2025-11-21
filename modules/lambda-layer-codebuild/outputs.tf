# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "layer_arns" {
  description = "Map of function names to their Lambda layer ARNs"
  value       = { for k, v in aws_lambda_layer_version.layers : k => v.arn }
}

output "layer_versions" {
  description = "Version numbers of the created Lambda layers"
  value = {
    for k, v in aws_lambda_layer_version.layers : k => v.version
  }
}

output "layer_suffix" {
  description = "Random suffix used for the layer bucket and resources"
  value       = random_string.layer_suffix.result
}

output "s3_bucket" {
  description = "S3 bucket used for layer storage"
  value       = local.lambda_layers_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for layer storage"
  value       = local.lambda_layers_bucket_arn
}

output "bucket_created_by_module" {
  description = "Whether the S3 bucket was created by this module (always false since we always use external bucket)"
  value       = false
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project used for layer creation"
  value       = aws_codebuild_project.lambda_layers_build.name
}

output "codebuild_trigger_lambda_function_name" {
  description = "Name of the Lambda function used to trigger CodeBuild"
  value       = aws_lambda_function.codebuild_trigger.function_name
}

output "build_result" {
  description = "Result of the CodeBuild execution"
  value       = local.build_result
}

output "build_success" {
  description = "Whether the build completed successfully"
  value       = local.build_success
}
