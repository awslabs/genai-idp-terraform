# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local Lambda layer builder.
#
# Mirrors the public output surface of modules/lambda-layer-codebuild but
# builds the layer zips on the deploy host using a container runtime
# (Docker / Podman / Finch). Each entry in var.requirements_files becomes
# one layer zip uploaded to var.lambda_layers_bucket_arn. The wrapper
# (modules/lambda-layer-codebuild) creates the aws_lambda_layer_version
# pointing at the S3 object in both modes.
#
# Build pipeline per requirements entry:
#   1. local_file writes requirements.txt into a deterministic staging dir
#      under ${path.root}/.terraform/tmp/lambda-layer-local-build/<key>/.
#   2. null_resource runs scripts/build-lambda-layer.sh, which:
#        - runs the SAM build image with --platform linux/<arch>
#        - pip-installs requirements.txt into /tmp/layer/python
#        - zips the result to ${staging}/layer.zip
#      The script is idempotent and re-runs only when its triggers change.
#   3. archive_file (data source) is NOT used because the zip is produced
#      inside the container; instead aws_s3_object uploads ${staging}/layer.zip
#      directly using a content-hash etag for change detection.
#
# Note: a deliberate deviation from design.md Decision 2 -- this module
# does NOT use terraform-aws-modules/lambda. Justification (in spec docs):
# the dispatcher in lambda-layer-codebuild creates the layer version itself,
# so we only need build+upload here, and hand-rolled HCL matches the
# existing CodeBuild module's style (null_resource + archive_file +
# aws_s3_object) without adding a third-party module dependency.

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # Bucket name extracted from the ARN (matches lambda-layer-codebuild).
  lambda_layers_bucket_name = split(":::", var.lambda_layers_bucket_arn)[1]

  # Per-module staging area. Uses path.root so all consumers share one
  # .terraform/tmp tree (matches the CodeBuild module's convention).
  module_build_dir = "${path.root}/.terraform/tmp/lambda-layer-local-build/${var.name_prefix}"

  # Drop empty requirement entries -- consumers sometimes pass empty strings
  # when the upstream file doesn't exist (see processing-environment's
  # fileexists()-guarded entries).
  non_empty_requirements = {
    for k, v in var.requirements_files : k => v if length(trimspace(v)) > 0
  }

  # SAM build image. AWS publishes `:latest-x86_64` and `:latest-arm64`
  # variants on public.ecr.aws/sam/build-python3.12.
  sam_image_arch = var.lambda_architecture == "arm64" ? "arm64" : "x86_64"
  sam_image      = "public.ecr.aws/sam/build-python3.12:latest-${local.sam_image_arch}"

  # Docker --platform value (linux/amd64 vs linux/arm64). The lambda
  # architecture name does not match docker's platform string, so we map.
  docker_platform = var.lambda_architecture == "arm64" ? "linux/arm64" : "linux/amd64"

  # Deterministic input hash per layer -- drives null_resource trigger AND
  # aws_lambda_layer_version's source_code_hash in the wrapper.
  layer_hashes = {
    for k, v in local.non_empty_requirements : k => md5(v)
  }

  # Aggregate hash for global outputs (parity with CodeBuild's behavior).
  all_requirements_hash = var.requirements_hash != "" ? var.requirements_hash : md5(jsonencode(local.non_empty_requirements))
}

# Suffix for global object keys -- matches lambda-layer-codebuild's
# random_string.layer_suffix so consumers see a consistent shape.
resource "random_string" "layer_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Stage requirements.txt for each layer.
resource "local_file" "requirements" {
  for_each = local.non_empty_requirements

  filename = "${local.module_build_dir}/${each.key}/requirements.txt"
  content  = each.value
}

# Build each layer's zip in a container. The script is shared across all
# layer entries; it accepts the staging dir, SAM image, docker platform,
# and docker host as positional args.
resource "null_resource" "build_layer" {
  for_each = local.non_empty_requirements

  triggers = {
    # Rebuild when the requirements content changes or force_rebuild flips.
    requirements_hash = local.layer_hashes[each.key]
    architecture      = var.lambda_architecture
    sam_image         = local.sam_image
    force_rebuild     = var.force_rebuild ? timestamp() : "static"
    docker_host       = var.docker_host
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/build-layer.sh"

    environment = {
      LAYER_NAME      = each.key
      STAGING_DIR     = "${local.module_build_dir}/${each.key}"
      SAM_IMAGE       = local.sam_image
      DOCKER_PLATFORM = local.docker_platform
      DOCKER_HOST     = var.docker_host
    }
  }

  depends_on = [local_file.requirements]
}

# Upload each produced zip to the shared assets bucket. Content-hash etag
# (md5 of the requirements input) gives us deterministic change detection
# without reading the zip itself (Terraform can't hash a file that may not
# exist yet on first plan).
resource "aws_s3_object" "layer_zip" {
  for_each = local.non_empty_requirements

  bucket = local.lambda_layers_bucket_name
  key    = "layers/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}/${each.key}.zip"
  source = "${local.module_build_dir}/${each.key}/layer.zip"

  # Etag tied to the input hash, not the zip bytes, so plan converges even
  # when the file hasn't been produced yet on first run.
  etag = local.layer_hashes[each.key]

  depends_on = [null_resource.build_layer]
}
