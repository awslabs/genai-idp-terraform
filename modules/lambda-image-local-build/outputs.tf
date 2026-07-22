# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

output "image_uri" {
  description = "Content-addressed image URI suitable for aws_lambda_function.image_uri. Pins by sha256 digest so Lambda runs the exact image we pushed, not whatever :latest happens to be in ECR at invoke time."
  value       = "${docker_registry_image.lambda.name}@${docker_registry_image.lambda.sha256_digest}"
}

output "image_tag_uri" {
  description = "Tag-based image URI (repository:tag). Useful for non-Lambda consumers that expect the tag form."
  value       = docker_registry_image.lambda.name
}

output "image_id" {
  description = "Local docker image ID (sha256 of the local image, NOT the registry digest)."
  value       = docker_image.lambda.image_id
}

output "image_digest" {
  description = "Registry-side sha256 digest of the pushed image."
  value       = docker_registry_image.lambda.sha256_digest
}

output "repository_url" {
  description = "ECR repository URL (echoed from input)."
  value       = var.ecr_repository_url
}

output "source_hash" {
  description = "md5 hash of all files under var.source_path. Drives rebuilds."
  value       = local.source_hash
}

output "build_mode" {
  description = "Always \"local\" for this module."
  value       = "local"
}
