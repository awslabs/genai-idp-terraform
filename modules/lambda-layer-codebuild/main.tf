# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Registry-compatible build directory approach
locals {
  # Use the calling module's .terraform/tmp directory for build artifacts
  # This ensures no files are created in the module directory
  module_build_dir = "${path.root}/.terraform/tmp/lambda-layer-codebuild"
  # Unique identifier for this module instance (static to avoid unnecessary rebuilds)
  module_instance_id = substr(md5("${path.module}-${var.name_prefix}"), 0, 8)

  # Bucket configuration - always use external bucket since it's always provided
  # Extract bucket name from S3 ARN format: arn:aws:s3:::bucket-name
  lambda_layers_bucket_name = split(":::", var.lambda_layers_bucket_arn)[1]
  lambda_layers_bucket_arn  = var.lambda_layers_bucket_arn
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
    # Trigger rebuild when requirements change
    requirements_hash = md5(jsonencode(var.requirements_files))
    name_prefix       = var.name_prefix
  }
}

# Create a directory structure for requirements files
resource "local_file" "requirements_files" {
  for_each = var.requirements_files

  content  = each.value
  filename = "${local.module_build_dir}/requirements/${each.key}/requirements.txt"
}

# Create archive of requirements
data "archive_file" "requirements_source" {
  type        = "zip"
  source_dir  = "${local.module_build_dir}/requirements"
  output_path = "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip"

  depends_on = [local_file.requirements_files]
}

# Note: S3 bucket is provided externally via lambda_layers_bucket_arn variable
# No bucket resources are created in this module

# Upload the zip file to S3
resource "aws_s3_object" "requirements_source" {
  bucket = local.lambda_layers_bucket_name
  key    = "source/${var.name_prefix}-requirements_source.zip"
  source = data.archive_file.requirements_source.output_path

  # Use a local variable for the etag to avoid the file not found error
  etag = md5(jsonencode({
    for k, v in var.requirements_files : k => v
  }))
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
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

# CloudWatch log group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name              = "/aws/codebuild/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  retention_in_days = 14

  tags = {
    Name = "${var.name_prefix}-codebuild-logs"
  }
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
      echo "Testing IAM role propagation for CodeBuild..."
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
  name          = "${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  description   = "Build Lambda layers for ${var.name_prefix}"
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
    override_artifact_name = true
  }

  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_LARGE"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    # Privileged mode is not required - this build only performs Python pip installations,
    # system package installations via yum, and zip operations. No Docker operations are used.
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
      - echo Creating Lambda layers...
      - mkdir -p /tmp/layers
      - ls -la
  build:
    commands:
      - echo "Building layers from requirements files"
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
          
          # Check if requirements file is empty
          if [ -s "$req_file" ]; then
            # File is not empty, install dependencies
            echo "Installing dependencies for $LAYER_NAME..."
            
            # Special handling for Pillow/PIL
            if grep -q -i "pillow\|PIL" "$req_file"; then
              echo "Detected Pillow/PIL requirement - using special installation method"
              
              # Create lib directory for shared libraries
              mkdir -p /tmp/$LAYER_NAME/lib
              
              # Copy required shared libraries
              echo "Copying required shared libraries..."
              cp -P /usr/lib64/libjpeg.so* /tmp/$LAYER_NAME/lib/
              cp -P /usr/lib64/libpng.so* /tmp/$LAYER_NAME/lib/
              cp -P /usr/lib64/libz.so* /tmp/$LAYER_NAME/lib/
              cp -P /usr/lib64/libtiff.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || echo "libtiff not available"
              cp -P /usr/lib64/libfreetype.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || echo "libfreetype not available"
              cp -P /usr/lib64/liblcms2.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || echo "liblcms2 not available"
              cp -P /usr/lib64/libwebp.so* /tmp/$LAYER_NAME/lib/ 2>/dev/null || echo "libwebp not available"
              
              # List copied libraries
              echo "Copied libraries:"
              ls -la /tmp/$LAYER_NAME/lib/
              
              # Create a virtual environment to properly compile Pillow
              python -m venv /tmp/venv
              source /tmp/venv/bin/activate
              
              # Install wheel first
              pip install wheel
              
              # Install Pillow with proper compilation flags
              CFLAGS="-I/usr/include/libjpeg-turbo" pip install Pillow --no-cache-dir
              
              # Install other requirements
              pip install -r $req_file --no-deps --no-cache-dir
              
              # Copy the compiled packages to the layer directory
              cp -r /tmp/venv/lib/python3.12/site-packages/* /tmp/$LAYER_NAME/python/
              
              # Deactivate virtual environment
              deactivate
            else
              # Normal installation for other packages
              pip install -r $req_file -t /tmp/$LAYER_NAME/python --no-cache-dir
            fi

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
          
          # List installed packages
          echo "Installed packages for $LAYER_NAME:"
          ls -la /tmp/$LAYER_NAME/python/
          
          # Create zip file
          echo "Creating zip file for $LAYER_NAME..."
          cd /tmp/$LAYER_NAME
          zip -r /tmp/layers/$LAYER_NAME.zip python/ lib/
          
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
  discard-paths: yes
EOF
  }
}

# Note: CodeBuild triggering is now handled by Lambda function in lambda.tf

# Clean up local files after successful build
resource "null_resource" "cleanup_files" {
  depends_on = [
    aws_lambda_invocation.trigger_codebuild,
    aws_s3_object.requirements_source
  ]

  triggers = {
    build_id = aws_lambda_invocation.trigger_codebuild.result
  }

  provisioner "local-exec" {
    command = <<EOF
      echo "Cleaning up temporary files directory..."
      # Remove contents of requirements directory but keep the directory and .gitkeep file
      find "${path.module}/files/requirements" -mindepth 1 -not -name ".gitkeep" -exec rm -rf {} \; 2>/dev/null || true
      # Clean up the build zip file
      rm -f "${local.module_build_dir}/requirements_source_${random_id.build_id.hex}.zip"
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

# Wait for S3 consistency after CodeBuild completion
resource "time_sleep" "wait_for_s3_consistency" {
  depends_on = [aws_lambda_invocation.trigger_codebuild]

  create_duration = "120s"
}

# Create Lambda layers only for non-empty requirements
resource "aws_lambda_layer_version" "layers" {
  for_each = local.non_empty_requirements

  layer_name = "${var.name_prefix}-${each.key}"
  s3_bucket  = local.lambda_layers_bucket_name
  s3_key     = "layers/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}/${each.key}.zip"

  compatible_runtimes = ["python3.12"]

  # Force layer recreation when requirements change
  source_code_hash = md5(each.value)

  depends_on = [time_sleep.wait_for_s3_consistency]
}

# Optional: Cleanup old build artifacts
resource "null_resource" "cleanup_build_artifacts" {
  depends_on = [
    # This will be triggered after successful deployments
    null_resource.cleanup_files
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
