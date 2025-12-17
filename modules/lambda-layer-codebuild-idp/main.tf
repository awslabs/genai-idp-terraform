# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Registry-compatible build directory approach
locals {
  # Use the calling module's .terraform/tmp directory for build artifacts
  # This ensures no files are created in the module directory
  module_build_dir = "${path.root}/.terraform/tmp/lambda-layer-codebuild-idp"
  # Unique identifier for this module instance (static to avoid unnecessary rebuilds)
  module_instance_id = substr(md5("${path.module}-static"), 0, 8)

  # Bucket configuration - always use external bucket since it's always provided
  # Extract bucket name from S3 ARN format: arn:aws:s3:::bucket-name
  lambda_layers_bucket_name = split(":::", var.lambda_layers_bucket_arn)[1]
  lambda_layers_bucket_arn  = var.lambda_layers_bucket_arn

  # Generate hash of all Python files in idp_common package for change detection
  idp_common_files_hash = var.idp_common_source_path != "" ? md5(join("", [
    for f in fileset("${var.idp_common_source_path}/idp_common", "**/*.py") :
    filemd5("${var.idp_common_source_path}/idp_common/${f}")
  ])) : ""
}

# Get current region and account info
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Generate a random string for the S3 bucket name
resource "random_string" "layer_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Generate unique build ID for this module instance
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    # Include module instance ID for uniqueness
    module_instance_id = local.module_instance_id
    # Trigger rebuild when content changes
    content_hash = md5("lambda-layer-codebuild-idp")
  }
}

# Create a directory structure for requirements files
resource "local_file" "requirements_files" {
  for_each = var.requirements_files

  content  = each.value
  filename = "${local.module_build_dir}/requirements/${each.key}/requirements.txt"
}

# Copy idp_common source to build directory if provided
resource "terraform_data" "copy_idp_common_source" {
  count = var.idp_common_source_path != "" ? 1 : 0

  triggers_replace = [
    var.idp_common_source_path,
    random_id.build_id.hex,
    # Trigger on source changes - monitor key configuration files
    var.idp_common_source_path != "" ? filemd5("${var.idp_common_source_path}/pyproject.toml") : "",
    var.idp_common_source_path != "" ? filemd5("${var.idp_common_source_path}/setup.py") : "",
    # Monitor all Python files in the idp_common package directory
    local.idp_common_files_hash
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Create the idp-common requirements directory structure in build dir
      mkdir -p "${local.module_build_dir}/requirements/idp-common/idp_common_pkg"
      
      # Copy the idp_common source contents to build directory
      if [ -d "${var.idp_common_source_path}" ]; then
        cp -r "${var.idp_common_source_path}"/* "${local.module_build_dir}/requirements/idp-common/idp_common_pkg/"
        
        # Remove test files and cache to reduce size
        find "${local.module_build_dir}/requirements/idp-common/idp_common_pkg" -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
        find "${local.module_build_dir}/requirements/idp-common/idp_common_pkg" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        find "${local.module_build_dir}/requirements/idp-common/idp_common_pkg" -name "*.pyc" -delete 2>/dev/null || true
        find "${local.module_build_dir}/requirements/idp-common/idp_common_pkg" -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
      fi
    EOT
  }
}

# Create archive of requirements and source
data "archive_file" "requirements_source" {
  type        = "zip"
  source_dir  = "${local.module_build_dir}/requirements"
  output_path = "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip"

  depends_on = [
    local_file.requirements_files,
    terraform_data.copy_idp_common_source
  ]
}

# Note: S3 bucket is provided externally via lambda_layers_bucket_arn variable
# No bucket resources are created in this module

# Upload the zip file to S3
resource "aws_s3_object" "requirements_source" {
  bucket = local.lambda_layers_bucket_name
  key    = "source/requirements_source.zip"
  source = data.archive_file.requirements_source.output_path

  # Use a local variable for the etag to avoid the file not found error
  etag = md5(jsonencode({
    for k, v in var.requirements_files : k => v
  }))
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
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

# IAM inline policy for CodeBuild (attached directly to role)
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildPolicy"
  role = aws_iam_role.codebuild_role.id

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

# CloudWatch log group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name              = "/aws/codebuild/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${var.layer_prefix}-codebuild-logs"
  })
}

# CodeBuild project
# Wait for IAM role policy to propagate
# We reach propagation issue, where IAM role and policy were created, CodeBuild was able to use it within its execution.
# The execution was failing, as mentioned policies takes no effect yet.
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.codebuild_role,
    aws_iam_role_policy.codebuild_policy,
    aws_cloudwatch_log_group.codebuild_log_group
  ]

  create_duration = "30s"
}

# Test IAM permissions before proceeding
resource "null_resource" "test_iam_permissions" {
  depends_on = [time_sleep.wait_for_iam_propagation]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Testing IAM role propagation for IDP CodeBuild..."
      # Wait a bit more to ensure IAM is fully propagated
      sleep 10
      echo "IAM role should be ready: ${aws_iam_role.codebuild_role.arn}"
    EOT
  }

  triggers = {
    role_arn  = aws_iam_role.codebuild_role.arn
    policy_id = aws_iam_role_policy.codebuild_policy.id
  }
}

resource "aws_codebuild_project" "lambda_layers_build" {
  name          = "${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  description   = "Build Lambda layers for ${var.layer_prefix}"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild_role.arn

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
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_LARGE"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    # Privileged mode is not required - this build only performs Python pip installations,
    # system package installations via yum, rsync operations, and zip operations. No Docker operations are used.
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
      group_name = aws_cloudwatch_log_group.codebuild_log_group.name
    }
  }

  source {
    type      = "S3"
    location  = "${local.lambda_layers_bucket_name}/${aws_s3_object.requirements_source.key}"
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
        set -e  # Exit immediately if a command fails
        # Install common system dependencies
        echo "Installing system dependencies..."
        yum install -y gcc gcc-c++ python3-devel zlib-devel libjpeg-devel libpng-devel
        
        for req_file in $(find . -name "requirements.txt"); do
          LAYER_NAME=$(basename $(dirname $req_file))
          echo "=========================================="
          echo "Building layer for $LAYER_NAME"
          echo "Requirements file: $req_file"
          echo "Contents of requirements file:"
          cat $req_file
          
          # Create layer directory
          mkdir -p /tmp/$LAYER_NAME/python
          
          # Check if this is the idp-common layer
          if [ "$LAYER_NAME" = "idp-common" ]; then
            echo "Building idp-common layer with Python package..."
            
            # Check if idp_common_pkg directory exists
            if [ -d "$(dirname $req_file)/idp_common_pkg" ]; then
              echo "Found idp_common_pkg directory"
              
              # Create a temporary build directory
              mkdir -p /tmp/builddir
              rsync -rLv $(dirname $req_file)/ /tmp/builddir/
              
              cd /tmp/builddir
              
              # Install dependencies first
              if [ -s "requirements.txt" ]; then
                echo "Installing dependencies..."
                pip install -r requirements.txt -t /tmp/$LAYER_NAME/python --no-cache-dir
              fi
              
              # Install the idp_common package
              echo "Installing idp_common package..."
              if [ -n "$IDP_COMMON_EXTRAS" ] && [ "$IDP_COMMON_EXTRAS" != "" ]; then
                echo "Installing with extras: $IDP_COMMON_EXTRAS"
                pip install -e ./idp_common_pkg[$IDP_COMMON_EXTRAS] -t /tmp/$LAYER_NAME/python --no-cache-dir
              else
                echo "Installing without extras"
                pip install -e ./idp_common_pkg -t /tmp/$LAYER_NAME/python --no-cache-dir
              fi
              
              # Copy the idp_common source code directly to ensure it's available
              echo "Copying idp_common source code..."
              mkdir -p /tmp/$LAYER_NAME/python/idp_common
              rsync -rLv ./idp_common_pkg/idp_common/ /tmp/$LAYER_NAME/python/idp_common/
              
              # Clean up build artifacts but keep the package
              echo "Cleaning up build artifacts..."
              find /tmp/$LAYER_NAME/python -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
              find /tmp/$LAYER_NAME/python -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
              find /tmp/$LAYER_NAME/python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
              find /tmp/$LAYER_NAME/python -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
              find /tmp/$LAYER_NAME/python -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
              find /tmp/$LAYER_NAME/python -type f -name "__editable__*" -exec rm -rf {} + 2>/dev/null || true
              
              # Clean up temporary directory
              rm -rf /tmp/builddir
              
            else
              echo "ERROR: idp_common_pkg directory not found!"
              exit 1
            fi
            
          else
            # Normal installation for other layers
            echo "Building regular layer..."
            
            # Check if requirements file is empty
            if [ -s "$req_file" ]; then
              # File is not empty, install dependencies
              echo "Installing dependencies for $LAYER_NAME..."
              pip install -r $req_file -t /tmp/$LAYER_NAME/python --no-cache-dir
              
              # Check if installation was successful
              if [ $? -ne 0 ]; then
                echo "Failed to install dependencies for $LAYER_NAME"
                exit 1
              fi
            else
              # File is empty, create minimal layer
              echo "Requirements file is empty, creating minimal layer"
              touch /tmp/$LAYER_NAME/python/__init__.py
            fi
          fi
          
          # List installed packages
          echo "Installed packages for $LAYER_NAME:"
          ls -la /tmp/$LAYER_NAME/python/
          
          # Check if idp_common is available for idp-common layer
          if [ "$LAYER_NAME" = "idp-common" ]; then
            echo "Checking idp_common availability:"
            if [ -d "/tmp/$LAYER_NAME/python/idp_common" ]; then
              echo "✓ idp_common directory found"
              ls -la /tmp/$LAYER_NAME/python/idp_common/
            else
              echo "✗ idp_common directory NOT found"
              exit 1
            fi
          fi
          
          # Create zip file
          echo "Creating zip file for $LAYER_NAME..."
          cd /tmp/$LAYER_NAME
          zip -r /tmp/layers/$LAYER_NAME.zip python/
          
          # Check if zip was successful
          if [ $? -ne 0 ]; then
            echo "Failed to create zip file for $LAYER_NAME"
            exit 1
          fi
          
          # Check zip file size
          echo "Zip file size for $LAYER_NAME:"
          ls -lh /tmp/layers/$LAYER_NAME.zip
          
          # Return to original directory - use CODEBUILD_SRC_DIR or fallback
          if [ -d "$CODEBUILD_SRC_DIR" ]; then
            cd $CODEBUILD_SRC_DIR
          else
            # Just continue without changing directory if the path doesn't exist
            echo "Source directory not found, continuing..."
          fi
          echo "=========================================="
        done
      - echo "All layers built successfully"
      - echo "Contents of /tmp/layers/:"
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

# Clean up temporary files after successful build
resource "null_resource" "cleanup_after_build" {
  depends_on = [
    aws_lambda_invocation.trigger_codebuild,
    aws_s3_object.requirements_source
  ]

  triggers = {
    build_id = aws_lambda_invocation.trigger_codebuild.id
  }

  provisioner "local-exec" {
    command = <<EOF
      echo "Cleaning up temporary files after build..."
      # Clean up the temporary zip file
      rm -f "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip" 2>/dev/null || true
      echo "Cleanup completed"
    EOF
  }
}

# Filter out empty requirements files
locals {
  non_empty_requirements = {
    for k, v in var.requirements_files : k => v if length(v) > 0
  }
}

# Create Lambda layers only for non-empty requirements
resource "aws_lambda_layer_version" "layers" {
  for_each = local.non_empty_requirements

  layer_name = "${var.layer_prefix}-${each.key}"
  s3_bucket  = local.lambda_layers_bucket_name
  s3_key     = "layers/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}/${each.key}.zip"

  compatible_runtimes = ["python3.12"]

  # Force layer recreation when requirements change
  source_code_hash = md5("${each.value}-${join(",", var.idp_common_extras)}-${local.idp_common_files_hash}")

  depends_on = [aws_lambda_invocation.trigger_codebuild]
}

# Optional: Cleanup old build artifacts
resource "null_resource" "cleanup_build_artifacts" {
  depends_on = [
    # This will be triggered after successful deployments
    random_id.build_id
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Cleaning up old build artifacts..."
      # Remove build files older than 1 day but keep the directory
      find "${local.module_build_dir}" -name "*.zip" -mtime +1 -delete 2>/dev/null || true
      echo "Build artifact cleanup completed"
    EOT
  }

  triggers = {
    # Run cleanup when build ID changes
    build_id = random_id.build_id.hex
  }
}
# Optional: Cleanup all temporary files when the module is destroyed
resource "null_resource" "cleanup_on_destroy" {
  depends_on = [
    aws_lambda_layer_version.layers
  ]

  # This will run when the module is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Cleaning up all temporary files..."
      rm -rf "${path.root}/.terraform/tmp/lambda-layer-codebuild-idp" 2>/dev/null || true
      echo "All temporary files cleanup completed"
    EOT
  }

  triggers = {
    # Run cleanup when build ID changes
    build_id = random_id.build_id.hex
  }
}
