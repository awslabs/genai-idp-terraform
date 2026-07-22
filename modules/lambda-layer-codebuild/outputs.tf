# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs are stable across both build modes. CodeBuild-specific outputs
# return null on the local-build path (documented behavior; no internal
# consumers depend on their non-null value).

output "layer_arns" {
  description = "Map of layer name to Lambda layer ARN."
  value       = { for k, v in aws_lambda_layer_version.layers : k => v.arn }
}

output "layer_versions" {
  description = "Map of layer name to Lambda layer version number."
  value       = { for k, v in aws_lambda_layer_version.layers : k => v.version }
}

output "layer_suffix" {
  description = "Random suffix used in resource names."
  value       = random_string.layer_suffix.result
}

output "s3_bucket" {
  description = "S3 bucket used for layer storage."
  value       = local.lambda_layers_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for layer storage."
  value       = local.lambda_layers_bucket_arn
}

output "bucket_created_by_module" {
  description = "Whether the S3 bucket was created by this module (always false -- bucket is always external)."
  value       = false
}

output "build_mode" {
  description = "Active build path: \"codebuild\" or \"local\"."
  value       = local.use_local_build ? "local" : "codebuild"
}

#
# CodeBuild-specific outputs -- null when lambda_local = true.
#
# These were originally observability outputs for the in-cloud build; on
# the local-build path the corresponding resources do not exist. Returning
# null is explicit and lets consumers use coalesce() / try() if they care.
#

output "codebuild_project_name" {
  description = "CodeBuild project name; null when lambda_local = true."
  value       = try(aws_codebuild_project.lambda_layers_build[0].name, null)
}

output "codebuild_trigger_lambda_function_name" {
  description = "CodeBuild trigger Lambda function name; null when lambda_local = true."
  value       = try(aws_lambda_function.codebuild_trigger[0].function_name, null)
}

output "build_result" {
  description = "Parsed CodeBuild invocation result; null when lambda_local = true."
  value       = local.build_result
}

output "build_success" {
  description = "Whether the CodeBuild invocation succeeded; null when lambda_local = true."
  value       = local.build_success
}
