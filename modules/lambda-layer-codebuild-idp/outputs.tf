# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs are stable across both build modes. CodeBuild-specific outputs
# return null on the local-build path.

output "layer_arns" {
  description = "ARNs of the created Lambda layers."
  value = {
    for k, v in aws_lambda_layer_version.layers : k => v.arn
  }
}

output "layer_versions" {
  description = "Version numbers of the created Lambda layers."
  value = {
    for k, v in aws_lambda_layer_version.layers : k => v.version
  }
}

output "layer_arn" {
  description = "ARN of the main idp-common layer (backwards-compat alias)."
  value       = try(aws_lambda_layer_version.layers["idp-common"].arn, null)
}

output "layer_version" {
  description = "Version of the main idp-common layer (backwards-compat alias)."
  value       = try(aws_lambda_layer_version.layers["idp-common"].version, null)
}

output "function_layer_arns" {
  description = "Function-specific layer ARNs (one per entry in function_layer_config)."
  value = {
    for function_name, extras in var.function_layer_config :
    function_name => try(aws_lambda_layer_version.layers[function_name].arn, aws_lambda_layer_version.layers["idp-common"].arn)
  }
}

output "s3_bucket" {
  description = "S3 bucket used for layer storage."
  value = {
    bucket_name       = local.lambda_layers_bucket_name
    bucket_arn        = local.lambda_layers_bucket_arn
    created_by_module = false
  }
}

output "build_mode" {
  description = "Active build path: \"codebuild\" or \"local\"."
  value       = local.use_local_build ? "local" : "codebuild"
}

#
# CodeBuild-specific outputs -- null on the local-build path.
#

output "codebuild_project" {
  description = "CodeBuild project metadata; null when lambda_local = true."
  value = local.use_local_build ? null : {
    name = try(aws_codebuild_project.lambda_layers_build[0].name, null)
    arn  = try(aws_codebuild_project.lambda_layers_build[0].arn, null)
  }
}

output "build_trigger_lambda" {
  description = "CodeBuild trigger Lambda metadata; null when lambda_local = true."
  value = local.use_local_build ? null : {
    function_name = try(aws_lambda_function.codebuild_trigger[0].function_name, null)
    function_arn  = try(aws_lambda_function.codebuild_trigger[0].arn, null)
  }
}

output "build_result" {
  description = "CodeBuild invocation result; null when lambda_local = true."
  value = local.use_local_build ? null : {
    success = local.build_success
    details = local.build_result != null ? jsondecode(local.build_result.body) : null
  }
}

output "layer_configuration_summary" {
  description = "Summary of layer configuration for documentation and debugging."
  value = {
    total_layers_created = length(aws_lambda_layer_version.layers)
    layer_names          = keys(aws_lambda_layer_version.layers)
    idp_common_extras    = var.idp_common_extras
    function_specific_layers = length(var.function_layer_config) > 0 ? {
      for function_name, extras in var.function_layer_config :
      function_name => {
        extras    = extras
        layer_arn = try(aws_lambda_layer_version.layers[function_name].arn, aws_lambda_layer_version.layers["idp-common"].arn)
      }
    } : null
    requirements_files = keys(var.requirements_files)
  }
}
