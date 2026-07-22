# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# idp-common Lambda layer build dispatcher.
#
# Two modes, selected by var.lambda_local:
#   - false (default): AWS CodeBuild builds the layer in-cloud using a
#     buildspec that pip-installs idp_common_pkg[extras]. Historical behavior.
#   - true: build inline on the deploy host via scripts/build-idp-layer.sh,
#     which runs the same install steps inside the AWS SAM build image.
#
# Mode-agnostic resources (random_string, random_id, aws_lambda_layer_version,
# aws_s3_object for the produced zip, source staging via local_file +
# terraform_data) live alongside the CodeBuild-gated set.

locals {
  use_local_build = var.lambda_local

  module_build_dir   = "${path.root}/.terraform/tmp/lambda-layer-codebuild-idp/${var.layer_prefix}"
  module_instance_id = substr(md5("${var.layer_prefix}-static"), 0, 8)

  lambda_layers_bucket_name = split(":::", var.lambda_layers_bucket_arn)[1]
  lambda_layers_bucket_arn  = var.lambda_layers_bucket_arn

  idp_common_files_hash = var.idp_common_source_path != "" ? md5(join("", [
    for f in fileset("${var.idp_common_source_path}/idp_common", "**/*.py") :
    filemd5("${var.idp_common_source_path}/idp_common/${f}")
  ])) : ""

  # Architecture-aware SAM image (local-build path only).
  sam_image_arch  = var.lambda_architecture == "arm64" ? "arm64" : "x86_64"
  sam_image       = "public.ecr.aws/sam/build-python3.12:latest-${local.sam_image_arch}"
  docker_platform = var.lambda_architecture == "arm64" ? "linux/arm64" : "linux/amd64"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Mode-agnostic random naming.
resource "random_string" "layer_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    module_instance_id = local.module_instance_id
    content_hash       = md5("lambda-layer-codebuild-idp")
  }
}

# Filter out empty requirements files.
locals {
  non_empty_requirements = {
    for k, v in var.requirements_files : k => v if length(v) > 0
  }
}

# ----------------------------------------------------------------------------
# Source staging (used by BOTH modes; CodeBuild zips it for upload, the
# local-build path reads it directly from disk)
# ----------------------------------------------------------------------------

resource "local_file" "requirements_files" {
  for_each = var.requirements_files

  content  = each.value
  filename = "${local.module_build_dir}/requirements/${each.key}/requirements.txt"
}

# Stage idp_common source. The CodeBuild path zips this and uploads it;
# the local-build path mounts it into the SAM container.
resource "terraform_data" "copy_idp_common_source" {
  count = var.idp_common_source_path != "" ? 1 : 0

  triggers_replace = [
    var.idp_common_source_path,
    random_id.build_id.hex,
    var.idp_common_source_path != "" ? filemd5("${var.idp_common_source_path}/pyproject.toml") : "",
    var.idp_common_source_path != "" ? filemd5("${var.idp_common_source_path}/setup.py") : "",
    local.idp_common_files_hash,
    filemd5("${path.module}/main.tf"),
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      DEST="${local.module_build_dir}/requirements/idp-common/idp_common_pkg"

      mkdir -p "$DEST"

      if [ ! -d "${var.idp_common_source_path}" ]; then
        echo "ERROR: idp_common_source_path not found: ${var.idp_common_source_path}" >&2
        exit 1
      fi

      rsync -a --delete \
        --exclude='__pycache__/' \
        --exclude='*.py[cod]' \
        --exclude='*$py.class' \
        --exclude='*.so' \
        --exclude='.pytest_cache/' \
        --exclude='.mypy_cache/' \
        --exclude='.ruff_cache/' \
        --exclude='.tox/' \
        --exclude='.venv/' \
        --exclude='venv/' \
        --exclude='env/' \
        --exclude='ENV/' \
        --exclude='build/' \
        --exclude='dist/' \
        --exclude='develop-eggs/' \
        --exclude='downloads/' \
        --exclude='eggs/' \
        --exclude='.eggs/' \
        --exclude='sdist/' \
        --exclude='wheels/' \
        --exclude='var/' \
        --exclude='parts/' \
        --exclude='*.egg-info/' \
        --exclude='*.egg' \
        --exclude='.installed.cfg' \
        --exclude='tests/' \
        --exclude='.coverage' \
        --exclude='coverage.xml' \
        --exclude='coverage/' \
        --exclude='coverage_html/' \
        --exclude='htmlcov/' \
        --exclude='nosetests.xml' \
        --exclude='test-results.xml' \
        --exclude='test-reports/' \
        --exclude='uv.lock' \
        --exclude='poetry.lock' \
        --exclude='.git/' \
        --exclude='.gitignore' \
        --exclude='.gitattributes' \
        --exclude='.idea/' \
        --exclude='.vscode/' \
        --exclude='*.swp' \
        --exclude='*.swo' \
        --exclude='.DS_Store' \
        --exclude='Thumbs.db' \
        --exclude='node_modules/' \
        --exclude='clean_build.sh' \
        --exclude='verify_stickler.py' \
        "${var.idp_common_source_path}/" "$DEST/"

      echo "Staged idp_common source at $DEST:"
      du -sh "$DEST" || true
    EOT
  }
}

# ----------------------------------------------------------------------------
# CodeBuild path (lambda_local = false)
# ----------------------------------------------------------------------------

data "archive_file" "requirements_source" {
  type        = "zip"
  source_dir  = "${local.module_build_dir}/requirements"
  output_path = "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip"

  depends_on = [
    local_file.requirements_files,
    terraform_data.copy_idp_common_source
  ]
}

resource "aws_s3_object" "requirements_source" {
  count = local.use_local_build ? 0 : 1

  bucket = local.lambda_layers_bucket_name
  key    = "source/${var.layer_prefix}/requirements_source.zip"
  source = data.archive_file.requirements_source.output_path

  etag = md5(jsonencode({
    for k, v in var.requirements_files : k => v
  }))
}

resource "aws_iam_role" "codebuild_role" {
  count = local.use_local_build ? 0 : 1

  name = "${var.layer_prefix}-cb-role-${random_string.layer_suffix.result}"

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
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}:*"
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

  name              = "/aws/codebuild/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${var.layer_prefix}-codebuild-logs"
  })
}

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
      echo "Testing IAM role propagation for IDP CodeBuild..."
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

  name          = "${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  description   = "Build Lambda layers for ${var.layer_prefix}"
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
    override_artifact_name = false
  }

  environment {
    # Architecture-aware: arm64 uses the aarch64 standard image and ARM_CONTAINER.
    type         = var.lambda_architecture == "arm64" ? "ARM_CONTAINER" : "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_LARGE"
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

    environment_variable {
      name  = "IDP_COMMON_EXTRAS"
      value = join(",", var.idp_common_extras)
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
      - echo Creating Lambda layers with idp_common package...
      - mkdir -p /tmp/layers
      - ls -la
  build:
    commands:
      - echo "Building layers from requirements files with idp_common package"
      - |
        set -e
        echo "Installing system dependencies..."
        yum install -y gcc gcc-c++ python3-devel zlib-devel libjpeg-devel libpng-devel

        RUNTIME_PROVIDED_PACKAGES="boto3 botocore s3transfer awscli urllib3 jmespath python_dateutil dateutil"

        for req_file in $(find . -name "requirements.txt"); do
          LAYER_NAME=$(basename $(dirname $req_file))
          echo "=========================================="
          echo "Building layer for $LAYER_NAME"

          mkdir -p /tmp/$LAYER_NAME/python

          if [ "$LAYER_NAME" = "idp-common" ]; then
            echo "Building idp-common layer with Python package..."

            if [ -d "$(dirname $req_file)/idp_common_pkg" ]; then
              rm -rf /tmp/builddir
              mkdir -p /tmp/builddir
              rsync -rLv $(dirname $req_file)/ /tmp/builddir/

              cd /tmp/builddir

              if [ -s "requirements.txt" ]; then
                pip install -r requirements.txt -t /tmp/$LAYER_NAME/python --no-cache-dir
              fi

              if [ -n "$IDP_COMMON_EXTRAS" ] && [ "$IDP_COMMON_EXTRAS" != "" ]; then
                pip install -e ./idp_common_pkg[$IDP_COMMON_EXTRAS] -t /tmp/$LAYER_NAME/python --no-cache-dir
              else
                pip install -e ./idp_common_pkg -t /tmp/$LAYER_NAME/python --no-cache-dir
              fi

              mkdir -p /tmp/$LAYER_NAME/python/idp_common
              rsync -rLv ./idp_common_pkg/idp_common/ /tmp/$LAYER_NAME/python/idp_common/

              rm -rf /tmp/builddir
            else
              echo "ERROR: idp_common_pkg directory not found!"
              exit 1
            fi

          else
            if [ -s "$req_file" ]; then
              pip install -r $req_file -t /tmp/$LAYER_NAME/python --no-cache-dir
            else
              touch /tmp/$LAYER_NAME/python/__init__.py
            fi
          fi

          # Shared post-install cleanup.
          for pkg in $RUNTIME_PROVIDED_PACKAGES; do
            rm -rf "/tmp/$LAYER_NAME/python/$pkg" 2>/dev/null || true
            find "/tmp/$LAYER_NAME/python" -maxdepth 1 -type d \
              \( -name "$${pkg}-*" -o -name "$${pkg//-/_}-*" \) \
              -exec rm -rf {} + 2>/dev/null || true
          done

          find "/tmp/$LAYER_NAME/python" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type d -name "*.egg-info"  -exec rm -rf {} + 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type d -name "build"       -exec rm -rf {} + 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type d -name "tests"       -exec rm -rf {} + 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type f -name "__editable__*" -exec rm -rf {} + 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type f -name "*.pyc"       -delete 2>/dev/null || true
          find "/tmp/$LAYER_NAME/python" -type f -name "*.pyo"       -delete 2>/dev/null || true

          cd /tmp/$LAYER_NAME
          zip -r /tmp/layers/$LAYER_NAME.zip python/

          if [ -d "$CODEBUILD_SRC_DIR" ]; then
            cd $CODEBUILD_SRC_DIR
          fi
        done
      - ls -lh /tmp/layers/
  post_build:
    commands:
      - echo Lambda layers created successfully
artifacts:
  files:
    - '**/*'
  base-directory: /tmp/layers
  discard-paths: no
EOF
  }
}

# Clean up zip after CodeBuild finishes.
resource "null_resource" "cleanup_after_build" {
  count = local.use_local_build ? 0 : 1

  depends_on = [
    aws_lambda_invocation.trigger_codebuild,
    aws_s3_object.requirements_source
  ]

  triggers = {
    build_id = aws_lambda_invocation.trigger_codebuild[0].id
  }

  provisioner "local-exec" {
    command = <<EOF
      echo "Cleaning up temporary files after build..."
      rm -f "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip" 2>/dev/null || true
      echo "Cleanup completed"
    EOF
  }
}

# ----------------------------------------------------------------------------
# Local-build path (lambda_local = true)
# ----------------------------------------------------------------------------
#
# One null_resource.build_local per non-empty requirements entry. Each
# invokes scripts/build-idp-layer.sh inside the SAM container; the script
# writes layer.zip into the staging dir. We then aws_s3_object-upload
# each zip to a deterministic key matching the CodeBuild path's layout.

resource "null_resource" "build_local" {
  for_each = local.use_local_build ? local.non_empty_requirements : {}

  triggers = {
    requirements_hash = md5(each.value)
    architecture      = var.lambda_architecture
    extras            = join(",", var.idp_common_extras)
    idp_common_hash   = local.idp_common_files_hash
    sam_image         = local.sam_image
    force_rebuild     = var.force_rebuild ? timestamp() : "static"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/build-idp-layer.sh"

    environment = {
      LAYER_NAME        = each.key
      STAGING_DIR       = local.module_build_dir
      SAM_IMAGE         = local.sam_image
      DOCKER_PLATFORM   = local.docker_platform
      IDP_COMMON_EXTRAS = join(",", var.idp_common_extras)
    }
  }

  depends_on = [
    local_file.requirements_files,
    terraform_data.copy_idp_common_source,
  ]
}

resource "aws_s3_object" "layer_zip_local" {
  for_each = local.use_local_build ? local.non_empty_requirements : {}

  bucket = local.lambda_layers_bucket_name
  key    = "layers/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}/${each.key}.zip"
  source = "${local.module_build_dir}/requirements/${each.key}/layer.zip"

  etag = md5(each.value)

  depends_on = [null_resource.build_local]
}

# ----------------------------------------------------------------------------
# Layer-version resources (mode-agnostic)
# ----------------------------------------------------------------------------

resource "aws_lambda_layer_version" "layers" {
  for_each = local.non_empty_requirements

  layer_name = "${var.layer_prefix}-${each.key}"
  s3_bucket  = local.lambda_layers_bucket_name
  s3_key     = "layers/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}/${each.key}.zip"

  compatible_runtimes      = ["python3.12"]
  compatible_architectures = [var.lambda_architecture]

  # Hash mixes inputs that change the produced zip across modes:
  source_code_hash = md5("${each.value}-${join(",", var.idp_common_extras)}-${local.idp_common_files_hash}-${var.lambda_architecture}-${local.use_local_build ? "local" : md5(try(aws_codebuild_project.lambda_layers_build[0].source[0].buildspec, ""))}")

  depends_on = [
    aws_lambda_invocation.trigger_codebuild,
    aws_s3_object.layer_zip_local,
  ]
}

# Background cleanup of old build artifacts.
resource "null_resource" "cleanup_build_artifacts" {
  depends_on = [random_id.build_id]

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

resource "null_resource" "cleanup_on_destroy" {
  depends_on = [aws_lambda_layer_version.layers]

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Cleaning up all temporary files..."
      rm -rf "${path.root}/.terraform/tmp/lambda-layer-codebuild-idp" 2>/dev/null || true
      echo "All temporary files cleanup completed"
    EOT
  }

  triggers = {
    build_id = random_id.build_id.hex
  }
}
