# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lambda layer build dispatcher.
#
# This module has two modes, selected by var.lambda_local:
#
#   - false (default): provision an AWS CodeBuild project + trigger Lambda
#     that builds layers in-cloud (the historical behavior).
#   - true: delegate to modules/lambda-layer-local-build, which builds the
#     same layers on the deploy host using a container runtime.
#
# The downstream aws_lambda_layer_version resource lives here in BOTH
# modes; it reads s3_bucket/s3_key from whichever path is active. Output
# contracts (layer_arns, s3_bucket, layer_suffix, build_mode) are stable
# across modes.

locals {
  # Dispatcher switch. Computed once; referenced everywhere.
  use_local_build = var.lambda_local

  # Use the calling module's .terraform/tmp directory for build artifacts.
  module_build_dir = "${path.root}/.terraform/tmp/lambda-layer-codebuild"

  # Unique identifier for this module instance (static to avoid unnecessary rebuilds).
  module_instance_id = substr(md5("${path.module}-${var.name_prefix}"), 0, 8)

  # Bucket configuration -- always external (provided by assets-bucket).
  lambda_layers_bucket_name = split(":::", var.lambda_layers_bucket_arn)[1]
  lambda_layers_bucket_arn  = var.lambda_layers_bucket_arn
}

# Get current region and account info.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Suffix used in all resource names. Same value across modes so flipping
# lambda_local does NOT force-rename the layers themselves.
resource "random_string" "layer_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Build ID drives rebuild triggers and zip naming. Kept on both paths
# because aws_lambda_layer_version's source_code_hash references hashes
# derived from it; reusing the same resource in both modes keeps state
# stable.
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    module_instance_id = local.module_instance_id
    requirements_hash  = md5(jsonencode(var.requirements_files))
    name_prefix        = var.name_prefix
  }
}

# Filter out empty requirements files (consumers may pass empty strings
# when the upstream file doesn't exist; the layer-version for-each must
# skip those).
locals {
  non_empty_requirements = {
    for k, v in var.requirements_files : k => v if length(v) > 0
  }
}

# ----------------------------------------------------------------------------
# CodeBuild path (lambda_local = false)
# ----------------------------------------------------------------------------
#
# Every resource below gates on `local.use_local_build ? 0 : 1`. The
# data "archive_file" is intentionally unconditional -- data sources only
# create local files and have no AWS-side effect. Their consumers
# (aws_s3_object, aws_codebuild_project) are gated, so the archive simply
# goes unused in local mode.

# Stage requirements.txt files for CodeBuild's S3-sourced buildspec.
resource "local_file" "requirements_files" {
  for_each = local.use_local_build ? {} : var.requirements_files

  content  = each.value
  filename = "${local.module_build_dir}/requirements/${each.key}/requirements.txt"
}

# When in local-build mode, no requirements files are staged (the local-
# build module handles its own staging). But the unconditional
# data "archive_file" below will fail if the directory is missing or empty.
# This placeholder file ensures the directory always has at least one file
# regardless of mode. It's harmless: the resulting zip is never uploaded
# in local mode (aws_s3_object.requirements_source has count = 0).
resource "local_file" "requirements_dir_placeholder" {
  content  = "# Placeholder — ensures archive_file has a non-empty source_dir in local-build mode.\n"
  filename = "${local.module_build_dir}/requirements/.placeholder"
}

# Create archive of requirements -- consumed only by aws_s3_object below
# on the CodeBuild path.
data "archive_file" "requirements_source" {
  type        = "zip"
  source_dir  = "${local.module_build_dir}/requirements"
  output_path = "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip"

  depends_on = [local_file.requirements_files, local_file.requirements_dir_placeholder]
}

# Upload the zip to S3 as the CodeBuild project's source.
resource "aws_s3_object" "requirements_source" {
  count = local.use_local_build ? 0 : 1

  bucket = local.lambda_layers_bucket_name
  key    = "source/${var.name_prefix}-requirements_source.zip"
  source = data.archive_file.requirements_source.output_path

  etag = md5(jsonencode({
    for k, v in var.requirements_files : k => v
  }))
}

resource "aws_iam_role" "codebuild_role" {
  count = local.use_local_build ? 0 : 1

  name = "${var.name_prefix}-codebuild-role-${random_string.layer_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  count = local.use_local_build ? 0 : 1

  name = "CodeBuildPolicy"
  role = aws_iam_role.codebuild_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          local.lambda_layers_bucket_arn,
          "${local.lambda_layers_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  count = local.use_local_build ? 0 : 1

  name              = "/aws/codebuild/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  retention_in_days = 14

  tags = {
    Name = "${var.name_prefix}-codebuild-logs"
  }
}

# IAM eventual-consistency guard before CodeBuild starts.
resource "time_sleep" "wait_for_iam_propagation" {
  count = local.use_local_build ? 0 : 1

  depends_on = [
    aws_iam_role.codebuild_role,
    aws_iam_role_policy.codebuild_policy,
    aws_cloudwatch_log_group.codebuild_log_group
  ]

  create_duration = "30s"
}

resource "null_resource" "test_iam_permissions" {
  count = local.use_local_build ? 0 : 1

  depends_on = [time_sleep.wait_for_iam_propagation]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Testing IAM role propagation for CodeBuild..."
      sleep 10
      echo "IAM role should be ready: ${aws_iam_role.codebuild_role[0].arn}"
    EOT
  }

  triggers = {
    role_arn  = aws_iam_role.codebuild_role[0].arn
    policy_id = aws_iam_role_policy.codebuild_policy[0].id
  }
}

resource "aws_codebuild_project" "lambda_layers_build" {
  count = local.use_local_build ? 0 : 1

  name          = "${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  description   = "Build Lambda layers for ${var.name_prefix}"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild_role[0].arn

  depends_on = [
    null_resource.test_iam_permissions,
    aws_iam_role.codebuild_role,
    aws_iam_role_policy.codebuild_policy,
    aws_cloudwatch_log_group.codebuild_log_group
  ]

  artifacts {
    type                   = "S3"
    location               = local.lambda_layers_bucket_name
    path                   = "layers"
    packaging              = "NONE"
    override_artifact_name = true
  }

  environment {
    # Architecture-aware CodeBuild image. Same SAM image family used by
    # the local-build path so artifacts are bit-equivalent across modes.
    type         = var.lambda_architecture == "arm64" ? "ARM_CONTAINER" : "LINUX_CONTAINER"
    compute_type = var.lambda_architecture == "arm64" ? "BUILD_GENERAL1_LARGE" : "BUILD_GENERAL1_LARGE"
    image = var.lambda_architecture == "arm64" ? (
      "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
      ) : (
      "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    )
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "LAMBDA_LAYERS_BUCKET"
      value = local.lambda_layers_bucket_name
      type  = "PLAINTEXT"
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.codebuild_log_group[0].name
    }
  }

  source {
    type      = "S3"
    location  = "${local.lambda_layers_bucket_name}/${aws_s3_object.requirements_source[0].key}"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.12
  pre_build:
    commands:
      - echo Creating Lambda layers...
      - mkdir -p /tmp/layers
      - ls -la
  build:
    commands:
      - echo "Building layers from requirements files"
      - |
        set -e
        echo "Installing system dependencies..."
        yum install -y gcc gcc-c++ python3-devel zlib-devel libjpeg-devel libpng-devel

        for req_file in $(find . -name "requirements.txt"); do
          LAYER_NAME=$(basename $(dirname $req_file))
          echo "=========================================="
          echo "Building layer: $LAYER_NAME"
          cat $req_file

          mkdir -p /tmp/$LAYER_NAME/python

          # Strip local path refs (./...), inline comments, and blank lines.
          CLEAN_REQ="/tmp/$${LAYER_NAME}_clean.txt"
          sed 's/#.*//' "$req_file" | grep -v '^\s*\.' | grep -v '^\s*$' > "$CLEAN_REQ" || true
          echo "Installable requirements:"
          cat "$CLEAN_REQ"

          if [ ! -s "$CLEAN_REQ" ]; then
            echo "No installable requirements, creating minimal layer"
            touch /tmp/$LAYER_NAME/python/__init__.py
          elif grep -q -i "pillow\|PIL" "$CLEAN_REQ"; then
            echo "Pillow detected - using special build method"
            mkdir -p /tmp/$LAYER_NAME/lib
            cp -P /usr/lib64/libjpeg.so* /tmp/$LAYER_NAME/lib/
            cp -P /usr/lib64/libpng.so* /tmp/$LAYER_NAME/lib/
            cp -P /usr/lib64/libz.so* /tmp/$LAYER_NAME/lib/
            cp -P /usr/lib64/libtiff.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || true
            cp -P /usr/lib64/libfreetype.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || true
            cp -P /usr/lib64/liblcms2.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || true
            cp -P /usr/lib64/libwebp.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || true
            python -m venv /tmp/venv
            source /tmp/venv/bin/activate
            pip install wheel
            CFLAGS="-I/usr/include/libjpeg-turbo" pip install Pillow --no-cache-dir
            pip install -r $CLEAN_REQ --no-deps --no-cache-dir
            cp -r /tmp/venv/lib/python3.12/site-packages/* /tmp/$LAYER_NAME/python/
            deactivate
          else
            pip install -r $CLEAN_REQ -t /tmp/$LAYER_NAME/python --no-cache-dir
          fi

          echo "Installed packages:"
          ls -la /tmp/$LAYER_NAME/python/

          echo "Creating zip for $LAYER_NAME..."
          cd /tmp/$LAYER_NAME
          zip -r /tmp/layers/$LAYER_NAME.zip python/ $([ -d lib ] && echo lib/)
          ls -lh /tmp/layers/$LAYER_NAME.zip

          cd $CODEBUILD_SRC_DIR 2>/dev/null || true
          echo "=========================================="
        done
      - echo "All layers built successfully"
      - ls -lh /tmp/layers/
  post_build:
    commands:
      - echo Lambda layers created successfully
artifacts:
  files:
    - '**/*'
  base-directory: /tmp/layers
  discard-paths: yes
EOF
  }
}

# ----------------------------------------------------------------------------
# Local-build path (lambda_local = true)
# ----------------------------------------------------------------------------

module "local_build" {
  count  = local.use_local_build ? 1 : 0
  source = "../lambda-layer-local-build"

  name_prefix              = var.name_prefix
  requirements_files       = var.requirements_files
  requirements_hash        = var.requirements_hash
  force_rebuild            = var.force_rebuild
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn
  lambda_tracing_mode      = var.lambda_tracing_mode

  lambda_architecture = var.lambda_architecture
  container_runtime   = var.container_runtime
}

# ----------------------------------------------------------------------------
# Layer-version resources (mode-agnostic)
# ----------------------------------------------------------------------------
#
# The S3 bucket is identical across modes (assets-bucket). The S3 key
# differs by build path, but the produced layer name and ARN remain
# stable so downstream consumers don't see a rename.

locals {
  # Coalesce S3 keys: local-build produces them via module.local_build,
  # CodeBuild produces them via the buildspec (hard-coded path pattern).
  layer_s3_keys = local.use_local_build ? (
    length(module.local_build) > 0 ? module.local_build[0].layer_keys : {}
    ) : {
    for k, _ in local.non_empty_requirements :
    k => "layers/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}/${k}.zip"
  }
}

resource "aws_lambda_layer_version" "layers" {
  for_each = local.non_empty_requirements

  layer_name = "${var.name_prefix}-${each.key}"
  s3_bucket  = local.lambda_layers_bucket_name
  s3_key     = local.layer_s3_keys[each.key]

  compatible_runtimes      = ["python3.12"]
  compatible_architectures = [var.lambda_architecture]

  source_code_hash = md5(each.value)

  # Both paths must complete their upload before we can refer to the
  # layer-zip object in Lambda.
  depends_on = [
    time_sleep.wait_for_s3_consistency,
    module.local_build,
  ]
}

# Wait for S3 consistency after CodeBuild completion (CodeBuild path only).
resource "time_sleep" "wait_for_s3_consistency" {
  count = local.use_local_build ? 0 : 1

  depends_on = [aws_lambda_invocation.trigger_codebuild]

  create_duration = "120s"
}

# Clean up local staging files after the CodeBuild path finishes uploading.
# The local-build path does its own cleanup; no equivalent needed here.
resource "null_resource" "cleanup_files" {
  count = local.use_local_build ? 0 : 1

  depends_on = [
    aws_lambda_invocation.trigger_codebuild,
    aws_s3_object.requirements_source,
  ]

  triggers = {
    build_id = aws_lambda_invocation.trigger_codebuild[0].result
  }

  provisioner "local-exec" {
    command = <<EOF
      echo "Cleaning up temporary files directory..."
      find "${path.module}/files/requirements" -mindepth 1 -not -name ".gitkeep" -exec rm -rf {} \; 2>/dev/null || true
      rm -f "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip"
      echo "Cleanup completed"
    EOF
  }
}

resource "null_resource" "cleanup_build_artifacts" {
  count = local.use_local_build ? 0 : 1

  depends_on = [null_resource.cleanup_files]

  provisioner "local-exec" {
    command = <<EOT
      echo "Cleaning up old build artifacts..."
      find "${local.module_build_dir}" -name "*.zip" -mtime +1 -delete 2>/dev/null || true
      echo "Build artifact cleanup completed"
    EOT
  }

  triggers = {
    build_id = random_id.build_id.hex
  }
}
