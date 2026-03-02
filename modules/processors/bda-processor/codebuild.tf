# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# CodeBuild project for building and pushing Pattern-1 (BDA) Docker images to ECR.
# This mirrors the pattern used by the bedrock-llm-processor module.

# =============================================================================
# IAM Role and Policy for CodeBuild
# =============================================================================

resource "aws_iam_role" "codebuild_role" {
  name = "${var.name}-codebuild-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "codebuild_policy" {
  #checkov:skip=CKV_AWS_355:ecr:GetAuthorizationToken is an account-level API that does not support resource-level permissions
  #checkov:skip=CKV_AWS_290:CloudWatch Logs requires wildcard resource as log groups and streams are created dynamically by CodeBuild
  name        = "${var.name}-codebuild-policy-${random_string.suffix.result}"
  description = "Policy for BDA processor CodeBuild Docker image build"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ecr:GetAuthorizationToken is account-level — cannot be scoped to a specific repo
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings"
        ]
        Resource = aws_ecr_repository.bda_processor.arn
      },
      {
        # CloudWatch Logs — log group/stream names are determined at runtime by CodeBuild
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name}-bda-processor-build-${random_string.suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name}-bda-processor-build-${random_string.suffix.result}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.encryption_key_arn != null ? [var.encryption_key_arn] : ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/nonexistent"]
      },
      {
        # S3 access to pull the source zip and write build artifacts
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${local.lambda_layers_bucket_name}",
          "arn:${data.aws_partition.current.partition}:s3:::${local.lambda_layers_bucket_name}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# =============================================================================
# Source archive: zip sources/ and upload to S3 so CodeBuild has a workspace
# =============================================================================

locals {
  lambda_layers_bucket_name = element(split(":", var.lambda_layers_bucket_arn), 5)
}

data "archive_file" "pattern1_sources" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources"
  output_path = "${path.module}/../../../.terraform/archives/pattern1_sources.zip"
}

resource "aws_s3_object" "pattern1_sources" {
  bucket = local.lambda_layers_bucket_name
  key    = "codebuild-sources/pattern-1/sources.zip"
  source = data.archive_file.pattern1_sources.output_path
  etag   = data.archive_file.pattern1_sources.output_md5
}

# =============================================================================
# CodeBuild Project
# =============================================================================

resource "aws_codebuild_project" "bda_processor_build" {
  #checkov:skip=CKV_AWS_316:privileged_mode is required for Docker-in-Docker builds to push images to ECR
  name          = "${var.name}-bda-processor-build-${random_string.suffix.result}"
  description   = "Builds Pattern-1 (BDA) Lambda Docker images and pushes them to ECR"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 60

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true # Required for Docker builds

    environment_variable {
      name  = "ECR_URI"
      value = aws_ecr_repository.bda_processor.repository_url
    }

    environment_variable {
      name  = "AWS_REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "IMAGE_VERSION"
      value = "latest"
    }
  }

  source {
    type      = "S3"
    location  = "${local.lambda_layers_bucket_name}/codebuild-sources/pattern-1/sources.zip"
    buildspec = file("${path.module}/../../../sources/patterns/pattern-1/buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.name}-bda-processor-build-${random_string.suffix.result}"
      status     = "ENABLED"
    }
  }

  tags = var.tags

  depends_on = [aws_s3_object.pattern1_sources]
}

# =============================================================================
# Trigger: run the CodeBuild build once at apply time
# =============================================================================
# This null_resource triggers the CodeBuild project immediately after it is
# created (or whenever the ECR repository URL changes), so that Docker images
# are available before any Lambda functions that reference them are created.

resource "null_resource" "trigger_bda_build" {
  triggers = {
    codebuild_project_name = aws_codebuild_project.bda_processor_build.name
    ecr_repository_url     = aws_ecr_repository.bda_processor.repository_url
    sources_hash           = data.archive_file.pattern1_sources.output_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting BDA processor Docker image build..."
      BUILD_ID=$(aws codebuild start-build \
        --project-name "${aws_codebuild_project.bda_processor_build.name}" \
        --region "${data.aws_region.current.name}" \
        --query 'build.id' \
        --output text)
      echo "Build started: $BUILD_ID"

      echo "Waiting for build to complete..."
      BUILD_STATUS="IN_PROGRESS"
      while [ "$BUILD_STATUS" = "IN_PROGRESS" ]; do
        sleep 30
        BUILD_STATUS=$(aws codebuild batch-get-builds \
          --ids "$BUILD_ID" \
          --region "${data.aws_region.current.name}" \
          --query 'builds[0].buildStatus' \
          --output text)
        echo "Build status: $BUILD_STATUS"
      done

      if [ "$BUILD_STATUS" != "SUCCEEDED" ]; then
        echo "ERROR: CodeBuild project failed with status: $BUILD_STATUS"
        exit 1
      fi

      echo "Verifying ECR image availability..."
      aws ecr describe-images \
        --repository-name "${aws_ecr_repository.bda_processor.name}" \
        --image-ids imageTag=bda-invoke-function \
        --region "${data.aws_region.current.name}" \
        --query 'imageDetails[0].imageTags' \
        --output text
      echo "ECR images verified successfully."
    EOT
  }

  depends_on = [
    aws_codebuild_project.bda_processor_build,
    aws_iam_role_policy_attachment.codebuild_policy_attachment,
    aws_ecr_repository.bda_processor,
    aws_s3_object.pattern1_sources
  ]
}
