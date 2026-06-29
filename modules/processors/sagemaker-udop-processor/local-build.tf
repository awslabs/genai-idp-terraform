# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local-build path for SageMaker UDOP processor container images
# (var.lambda_local = true).
#
# Same pattern as bda-processor/local-build.tf: mirror what the
# CodeBuild buildspec at sources/patterns/pattern-3/buildspec.yml does,
# but on the deploy host. Seven Lambda container images come out of one
# Dockerfile by varying the FUNCTION_PATH build arg, each tagged by
# function name in the same ECR repository.

locals {
  udop_pattern_dir = "${path.module}/../../../sources/patterns/pattern-3"

  # Mirrors the FUNCTION_* env exports in the upstream buildspec.
  udop_images = {
    "ocr-function"            = "patterns/pattern-3/src/ocr_function"
    "classification-function" = "patterns/pattern-3/src/classification_function"
    "extraction-function"     = "patterns/pattern-3/src/extraction_function"
    "assessment-function"     = "patterns/pattern-3/src/assessment_function"
    "processresults-function" = "patterns/pattern-3/src/processresults_function"
    "summarization-function"  = "patterns/pattern-3/src/summarization_function"
    "evaluation-function"     = "patterns/pattern-3/src/evaluation_function"
  }

  udop_docker_platform = var.lambda_architecture == "arm64" ? "linux/arm64" : "linux/amd64"

  udop_source_files = fileset(local.udop_pattern_dir, "**")
  udop_source_hash = md5(join("", [
    for f in local.udop_source_files :
    try(filemd5("${local.udop_pattern_dir}/${f}"), "")
  ]))
}

resource "null_resource" "ecr_login" {
  count = var.lambda_local ? 1 : 0

  triggers = {
    ecr_url  = aws_ecr_repository.udop_processor.repository_url
    apply_id = uuid()
  }

  lifecycle {
    ignore_changes = [triggers["apply_id"]]
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region "${data.aws_region.current.id}" | \
        docker login \
          --username AWS \
          --password-stdin "${aws_ecr_repository.udop_processor.repository_url}"
    EOT
  }
}

resource "null_resource" "build_push_image" {
  for_each = var.lambda_local ? local.udop_images : {}

  triggers = {
    image_tag     = each.key
    function_path = each.value
    ecr_url       = aws_ecr_repository.udop_processor.repository_url
    source_hash   = local.udop_source_hash
    architecture  = var.lambda_architecture
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../../../sources"

    command = <<-EOT
      set -euo pipefail
      ECR_URI="${aws_ecr_repository.udop_processor.repository_url}"
      TAG="${each.key}"
      FUNCTION_PATH="${each.value}"
      PLATFORM="${local.udop_docker_platform}"

      echo "Building $ECR_URI:$TAG (FUNCTION_PATH=$FUNCTION_PATH, platform=$PLATFORM)"

      docker buildx create --use --name idp-multiarch-builder \
        --driver docker-container 2>/dev/null \
        || docker buildx use idp-multiarch-builder

      docker buildx build \
        -f "patterns/pattern-3/Dockerfile.optimized" \
        --build-arg "FUNCTION_PATH=$FUNCTION_PATH" \
        -t "$ECR_URI:$TAG" \
        --platform "$PLATFORM" \
        --push \
        .

      echo "Pushed $ECR_URI:$TAG"
    EOT
  }

  depends_on = [
    null_resource.ecr_login,
    aws_ecr_repository.udop_processor,
  ]
}

resource "null_resource" "all_images_built" {
  count = var.lambda_local ? 1 : 0

  triggers = {
    source_hash = local.udop_source_hash
  }

  depends_on = [null_resource.build_push_image]
}

# Mode-agnostic aggregator. Downstream Lambdas depend on this regardless of
# whether CodeBuild or the local path produced the images.
resource "null_resource" "udop_images_ready" {
  triggers = {
    mode        = var.lambda_local ? "local" : "codebuild"
    source_hash = var.lambda_local ? local.udop_source_hash : ""
  }

  depends_on = [
    null_resource.trigger_udop_build,
    null_resource.all_images_built,
  ]
}
