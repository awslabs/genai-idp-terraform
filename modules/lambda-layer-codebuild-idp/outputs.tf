# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

output "layer_arns" {
  description = "ARNs of the created Lambda layers"
  value = {
    for k, v in aws_lambda_layer_version.layers : k => v.arn
  }
}

output "layer_versions" {
  description = "Version numbers of the created Lambda layers"
  value = {
    for k, v in aws_lambda_layer_version.layers : k => v.version
  }
}

output "layer_arn" {
  description = "ARN of the main idp-common layer (for backward compatibility)"
  value       = try(aws_lambda_layer_version.layers["idp-common"].arn, null)
}

output "layer_version" {
  description = "Version of the main idp-common layer (for backward compatibility)"
  value       = try(aws_lambda_layer_version.layers["idp-common"].version, null)
}

output "function_layer_arns" {
  description = <<-EOT
    Function-specific layer ARNs for optimized layer assignment.
    Use this to assign the most appropriate layer to each Lambda function.
    
    Example usage:
    layers = [module.idp_layers.function_layer_arns["ocr-function"]]
  EOT
  value = {
    for function_name, extras in var.function_layer_config :
    function_name => try(aws_lambda_layer_version.layers[function_name].arn, aws_lambda_layer_version.layers["idp-common"].arn)
  }
}

output "s3_bucket" {
  description = "S3 bucket used for layer storage"
  value = {
    bucket_name       = local.lambda_layers_bucket_name
    bucket_arn        = local.lambda_layers_bucket_arn
    created_by_module = false # Always false since we always use external bucket
  }
}

output "codebuild_project" {
  description = "CodeBuild project information"
  value = {
    name = aws_codebuild_project.lambda_layers_build.name
    arn  = aws_codebuild_project.lambda_layers_build.arn
  }
}

output "build_trigger_lambda" {
  description = "Lambda function used to trigger CodeBuild (replaces null_resource)"
  value = {
    function_name = aws_lambda_function.codebuild_trigger.function_name
    function_arn  = aws_lambda_function.codebuild_trigger.arn
  }
}

output "build_result" {
  description = "Result of the most recent build operation"
  value = {
    success = local.build_success
    details = jsondecode(local.build_result.body)
  }
}

output "layer_configuration_summary" {
  description = "Summary of layer configuration for documentation and debugging"
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
