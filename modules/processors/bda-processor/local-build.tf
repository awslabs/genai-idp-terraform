# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local-build path for BDA processor container images (var.lambda_local = true).
#
# This mirrors what the CodeBuild buildspec
# (sources/patterns/pattern-1/buildspec.yml) does, but on the deploy host:
# build five Lambda container images (bda-invoke, bda-completion,
# processresults, summarization, evaluation -- plus the hitl-* variants
# the upstream buildspec also produces) from a single Dockerfile by
# varying the FUNCTION_PATH build arg, then push each to ECR under its
# function-named tag.
#
# We use null_resource + local-exec instead of kreuzwerker/docker's
# resource model because the multi-image-per-repo pattern with different
# build args per image does not fit cleanly with docker_image's single-
# tag-per-resource design. Shell parity with the buildspec is easier to
# audit.

locals {
  bda_pattern_dir = "${path.module}/../../../sources/patterns/pattern-1"

  # Function-path map. Mirrors the FUNCTION_* env exports in
  # sources/patterns/pattern-1/buildspec.yml. Each entry maps the ECR
  # image tag to the build context's FUNCTION_PATH build-arg.
  bda_images = {
    "bda-invoke-function"         = "patterns/pattern-1/src/bda_invoke_function"
    "bda-completion-function"     = "patterns/pattern-1/src/bda_completion_function"
    "processresults-function"     = "patterns/pattern-1/src/processresults_function"
    "summarization-function"      = "patterns/pattern-1/src/summarization_function"
    "evaluation-function"         = "patterns/pattern-1/src/evaluation_function"
    "hitl-wait-function"          = "patterns/pattern-1/src/hitl_wait_function"
    "hitl-status-update-function" = "patterns/pattern-1/src/hitl_status_update_function"
    "hitl-process-function"       = "patterns/pattern-1/src/hitl_process_function"
  }

  # Lambda docker platform.
  bda_docker_platform = var.lambda_architecture == "arm64" ? "linux/arm64" : "linux/amd64"

  # Hash all source files under sources/patterns/pattern-1/ so the build
  # re-runs only when actually-relevant source changes.
  bda_source_files = fileset(local.bda_pattern_dir, "**")
  bda_source_hash = md5(join("", [
    for f in local.bda_source_files :
    try(filemd5("${local.bda_pattern_dir}/${f}"), "")
  ]))
}

# Authenticate the host's docker CLI to ECR before each build.
# Inlined into each build_push_image provisioner would be ideal, but
# we keep a single login resource that ALWAYS re-runs (no ignore_changes)
# so ECR tokens are refreshed on every apply. The triggers include a
# timestamp to guarantee re-execution.
resource "null_resource" "ecr_login" {
  count = var.lambda_local ? 1 : 0

  triggers = {
    ecr_url  = aws_ecr_repository.bda_processor.repository_url
    always   = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region "${data.aws_region.current.id}" | \
        docker login \
          --username AWS \
          --password-stdin "${aws_ecr_repository.bda_processor.repository_url}"
    EOT
  }
}

# Build + push each function image. `triggers.source_hash` ensures
# rebuilds happen only when source actually changes.
resource "null_resource" "build_push_image" {
  for_each = var.lambda_local ? local.bda_images : {}

  triggers = {
    image_tag     = each.key
    function_path = each.value
    ecr_url       = aws_ecr_repository.bda_processor.repository_url
    source_hash   = local.bda_source_hash
    architecture  = var.lambda_architecture
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../../../sources"

    command = <<-EOT
      set -euo pipefail
      ECR_URI="${aws_ecr_repository.bda_processor.repository_url}"
      TAG="${each.key}"
      FUNCTION_PATH="${each.value}"
      PLATFORM="${local.bda_docker_platform}"

      echo "Building $ECR_URI:$TAG (FUNCTION_PATH=$FUNCTION_PATH, platform=$PLATFORM)"

      docker buildx create --use --name idp-multiarch-builder \
        --driver docker-container 2>/dev/null \
        || docker buildx use idp-multiarch-builder

      docker buildx build \
        -f "patterns/pattern-1/Dockerfile.optimized" \
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
    aws_ecr_repository.bda_processor,
  ]
}

# Block downstream aws_lambda_function resources until all images are
# present in ECR. This aggregator gives us a single dependency target
# (mirrors null_resource.trigger_bda_build's role in the CodeBuild path).
resource "null_resource" "all_images_built" {
  count = var.lambda_local ? 1 : 0

  triggers = {
    source_hash = local.bda_source_hash
  }

  depends_on = [null_resource.build_push_image]
}


# =============================================================================
# Mode-agnostic image-build aggregator
# =============================================================================
#
# This always-1 null_resource serves as the single dependency target for
# all aws_lambda_function resources that consume the BDA processor's
# images. Internally it depends on whichever path produced the images:
# the CodeBuild trigger (when lambda_local = false) or the local build
# aggregator (when lambda_local = true). Downstream Lambdas reference
# `null_resource.bda_images_ready` regardless of mode, so no per-Lambda
# conditional wiring is needed.

resource "null_resource" "bda_images_ready" {
  triggers = {
    mode        = var.lambda_local ? "local" : "codebuild"
    source_hash = var.lambda_local ? local.bda_source_hash : ""
  }

  depends_on = [
    null_resource.trigger_bda_build,
    null_resource.all_images_built,
  ]
}
