# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  value       = module.idp_common_layer.layer_arns["idp-common"]
}

output "layer_arns" {
  description = "Map of all layer ARNs (for compatibility)"
  value       = module.idp_common_layer.layer_arns
}

output "s3_bucket" {
  description = "S3 bucket information used for layer storage"
  value       = module.idp_common_layer.s3_bucket
}

output "codebuild_project" {
  description = "CodeBuild project information"
  value       = module.idp_common_layer.codebuild_project
}
