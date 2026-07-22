# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local Lambda container-image builder.
#
# Builds an OCI image from var.source_path using the kreuzwerker/docker
# provider and pushes it to var.ecr_repository_url. Used by
# modules/processors/bda-processor and modules/processors/sagemaker-udop-processor
# when lambda_local = true.
#
# The provider itself is configured by the caller (root config) -- this
# module just consumes the aliased `docker` provider passed in via
# `providers = { docker = docker.lambda_local }`.

locals {
  docker_platform = var.lambda_architecture == "arm64" ? "linux/arm64" : "linux/amd64"

  # Hash every file under source_path so any code/Dockerfile change
  # triggers a rebuild. fileset is recursive when given **.
  source_files = sort(fileset(var.source_path, "**"))
  source_hash = md5(join("", [
    for f in local.source_files : try(filemd5("${var.source_path}/${f}"), "")
  ]))

  image_name = "${var.ecr_repository_url}:${var.image_tag}"
}

# ECR authorization token consumed by the docker provider's registry_auth
# block at the caller. Exposed as a module-internal data source as well so
# we have the source-of-truth in one place; the caller may either reuse
# our token (via the provider config it already passed) or run its own
# data source.
data "aws_ecr_authorization_token" "auth" {}

# Build the image. Tag the image with both `:<tag>` (so the registry push
# uses that) and a `:<source_hash>` alias so the digest is stable across
# applies that don't change source.
resource "docker_image" "lambda" {
  name = local.image_name

  build {
    context    = var.source_path
    dockerfile = var.dockerfile_path
    platform   = local.docker_platform
    build_args = var.build_args

    # Force a fresh layer cache miss when source changes. The label is
    # also visible to the build, so it can be inspected post-build.
    label = {
      "wrapper.source_hash" = local.source_hash
    }
  }

  triggers = {
    source_hash = local.source_hash
    platform    = local.docker_platform
  }

  # Keep the local image around for caching across applies.
  keep_locally = true
}

# Push the image to ECR. `keep_remotely = true` means terraform destroy
# does NOT delete the pushed image -- ECR repositories often outlive their
# Terraform-managed images (image lifecycle is governed by ECR's lifecycle
# policy, not by us).
resource "docker_registry_image" "lambda" {
  name = docker_image.lambda.name

  keep_remotely = true

  triggers = {
    image_id = docker_image.lambda.image_id
  }
}
