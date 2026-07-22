# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Output surface mirrors modules/lambda-layer-codebuild so the dispatcher
# can coalesce values from either path without conditional output shapes.

output "layer_keys" {
  description = "Map of layer name to S3 object key produced by the local build."
  value       = { for k, v in aws_s3_object.layer_zip : k => v.key }
}

output "layer_etags" {
  description = "Map of layer name to S3 object etag (= input md5). Used as source_code_hash on the wrapper's aws_lambda_layer_version."
  value       = { for k, v in aws_s3_object.layer_zip : k => v.etag }
}

output "s3_bucket" {
  description = "S3 bucket name where layer zips are uploaded."
  value       = local.lambda_layers_bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN (echoed from input for parity)."
  value       = var.lambda_layers_bucket_arn
}

output "layer_suffix" {
  description = "Random suffix used in S3 keys."
  value       = random_string.layer_suffix.result
}

output "build_mode" {
  description = "Always \"local\" for this module."
  value       = "local"
}

output "all_requirements_hash" {
  description = "Aggregate hash of all input requirements files."
  value       = local.all_requirements_hash
}
