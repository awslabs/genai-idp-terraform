# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

/**
 * # SageMaker UDOP Model Training Module (Enhanced with Pure Terraform)
 *
 * This module creates and trains a SageMaker UDOP model using the RVL-CDIP dataset.
 * It uses Docker provider for building Lambda container images and the terraform-aws-modules/lambda
 * module for robust Lambda function deployment, with pure Terraform constructs for orchestration.
 */

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  name_prefix = var.name_prefix

  # S3 paths
  data_prefix  = "rvl-cdip"
  model_prefix = "sagemaker"

  # Training job configuration
  job_name_prefix = "rvl-cdip-classifier-2"
  max_epochs      = var.max_epochs
  base_model      = var.base_model

  # Common tags
  common_tags = merge(var.tags, {
    Module = "sagemaker-model-training"
  })
}

# S3 bucket for training data and model artifacts
resource "aws_s3_bucket" "data_bucket" {
  bucket        = "${local.name_prefix}-sagemaker-data"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECR repositories for Lambda container images
resource "aws_ecr_repository" "generate_demo_data" {
  name                 = "${local.name_prefix}-generate-demo-data"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = local.common_tags

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "sagemaker_train" {
  name                 = "${local.name_prefix}-sagemaker-train"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = local.common_tags

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Docker images
resource "docker_image" "generate_demo_data" {
  name = "${aws_ecr_repository.generate_demo_data.repository_url}:latest"

  build {
    context    = "${path.module}/../src/generate_demo_data"
    dockerfile = "Dockerfile"
    platform   = "linux/amd64"

    build_args = {
      PYTHON_VERSION = "3.11"
    }
  }

  triggers = {
    dir_sha1 = sha1(join("", [
      for f in fileset("${path.module}/../src/generate_demo_data", "**") :
      filesha1("${path.module}/../src/generate_demo_data/${f}")
    ]))
  }
}

resource "docker_image" "sagemaker_train" {
  name = "${aws_ecr_repository.sagemaker_train.repository_url}:latest"

  build {
    context    = "${path.module}/../src/sagemaker_train"
    dockerfile = "Dockerfile"
    platform   = "linux/amd64"

    build_args = {
      PYTHON_VERSION = "3.11"
    }
  }

  triggers = {
    dir_sha1 = sha1(join("", [
      for f in fileset("${path.module}/../src/sagemaker_train", "**") :
      filesha1("${path.module}/../src/sagemaker_train/${f}")
    ]))
  }
}

# ECR login and push images
resource "null_resource" "push_generate_demo_data" {
  triggers = {
    dir_sha1 = docker_image.generate_demo_data.triggers.dir_sha1
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.id} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com
      docker push ${docker_image.generate_demo_data.name}
    EOT
  }

  depends_on = [docker_image.generate_demo_data, aws_ecr_repository.generate_demo_data]
}

resource "null_resource" "push_sagemaker_train" {
  triggers = {
    dir_sha1 = docker_image.sagemaker_train.triggers.dir_sha1
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.id} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com
      docker push ${docker_image.sagemaker_train.name}
    EOT
  }

  depends_on = [docker_image.sagemaker_train, aws_ecr_repository.sagemaker_train]
}

# IAM role for SageMaker
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${local.name_prefix}-sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach AWS managed policy for SageMaker
resource "aws_iam_role_policy_attachment" "sagemaker_execution_role_policy" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Additional policy for SageMaker role
resource "aws_iam_role_policy" "sagemaker_execution_policy" {
  name = "${local.name_prefix}-sagemaker-execution-policy"
  role = aws_iam_role.sagemaker_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/TrainingJobs:log-stream:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
      }
    ]
  })
}

# Lambda function for generating demo data using terraform-aws-modules/lambda
module "generate_demo_data_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${local.name_prefix}-generate-demo-data"
  description   = "Downloads and processes RVL-CDIP dataset for UDOP training"

  # Container image configuration
  create_package = false
  package_type   = "Image"
  image_uri      = "${aws_ecr_repository.generate_demo_data.repository_url}:latest"

  # Function configuration
  timeout                = 900  # 15 minutes (Lambda maximum)
  memory_size            = 2048 # Match CDK implementation
  ephemeral_storage_size = 2048 # 2 GB ephemeral storage for dataset processing

  # Environment variables
  environment_variables = {
    DATA_BUCKET        = aws_s3_bucket.data_bucket.bucket
    DATA_BUCKET_PREFIX = local.data_prefix
    MAX_WORKERS        = "20"
  }

  # IAM configuration
  create_role = true
  role_name   = "${local.name_prefix}-generate-demo-data-role"

  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.data_bucket.arn,
        "${aws_s3_bucket.data_bucket.arn}/*"
      ]
    }
    textract_access = {
      effect = "Allow"
      actions = [
        "textract:DetectDocumentText"
      ]
      resources = ["*"]
    }
    kms_access = {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"]
    }
  }

  # CloudWatch Logs
  cloudwatch_logs_retention_in_days = 14

  # Dependencies - Wait for image to be pushed to ECR
  depends_on = [null_resource.push_generate_demo_data]

  tags = local.common_tags
}

# Lambda function for SageMaker training using terraform-aws-modules/lambda
module "sagemaker_train_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${local.name_prefix}-sagemaker-train"
  description   = "Creates and manages SageMaker training jobs for UDOP model"

  # Container image configuration
  create_package = false
  package_type   = "Image"
  image_uri      = "${aws_ecr_repository.sagemaker_train.repository_url}:latest"

  # Function configuration
  timeout     = 900 # 15 minutes
  memory_size = 2048

  # Environment variables
  environment_variables = {
    # AWS Lambda automatically provides AWS_REGION environment variable
  }

  # IAM configuration
  create_role = true
  role_name   = "${local.name_prefix}-sagemaker-train-role"

  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.data_bucket.arn,
        "${aws_s3_bucket.data_bucket.arn}/*"
      ]
    }
    sagemaker_access = {
      effect = "Allow"
      actions = [
        "sagemaker:CreateTrainingJob",
        "sagemaker:DescribeTrainingJob",
        "sagemaker:StopTrainingJob",
        "sagemaker:ListTrainingJobs"
      ]
      resources = ["*"]
    }
    iam_pass_role = {
      effect = "Allow"
      actions = [
        "iam:PassRole"
      ]
      resources = [aws_iam_role.sagemaker_execution_role.arn]
    }
    logs_access = {
      effect = "Allow"
      actions = [
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ]
      resources = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/TrainingJobs:log-stream:*"
      ]
    }
    kms_access = {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"]
    }
  }

  # CloudWatch Logs
  cloudwatch_logs_retention_in_days = 14

  # Dependencies - Wait for image to be pushed to ECR
  depends_on = [null_resource.push_sagemaker_train]

  tags = local.common_tags
}

# Lambda function for checking training completion using terraform-aws-modules/lambda
module "sagemaker_train_is_complete_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${local.name_prefix}-sagemaker-train-is-complete"
  description   = "Checks if SageMaker training job is complete"
  handler       = "index.lambda_handler"
  runtime       = "python3.11"

  # Source code
  source_path = "${path.module}/../src/sagemaker_train_is_complete/index.py"

  # Function configuration
  timeout     = 60
  memory_size = 256

  # IAM configuration
  create_role = true
  role_name   = "${local.name_prefix}-sagemaker-is-complete-role"

  attach_policy_statements = true
  policy_statements = {
    sagemaker_describe = {
      effect = "Allow"
      actions = [
        "sagemaker:DescribeTrainingJob"
      ]
      resources = ["*"]
    }
  }

  # CloudWatch Logs
  cloudwatch_logs_retention_in_days = 7

  tags = local.common_tags
}

# Random string for unique request ID
resource "random_string" "request_id" {
  length  = 10
  special = false
  upper   = false
}

# Step 1: Invoke the generate demo data Lambda function
resource "aws_lambda_invocation" "generate_demo_data" {
  function_name = module.generate_demo_data_lambda.lambda_function_name
  input = jsonencode({
    # Use a static trigger that only changes when we actually want to regenerate data
    trigger = "terraform-static-v1"
  })

  triggers = {
    # Only rerun when explicitly requested via retrain_model or when Lambda function changes
    rerun_on_change    = var.retrain_model ? timestamp() : "static"
    lambda_source_hash = module.generate_demo_data_lambda.lambda_function_source_code_hash
  }

  depends_on = [module.generate_demo_data_lambda]
}

# Step 2: Invoke the SageMaker training Lambda function
resource "aws_lambda_invocation" "sagemaker_train" {
  function_name = module.sagemaker_train_lambda.lambda_function_name
  input = jsonencode({
    SagemakerRoleArn = aws_iam_role.sagemaker_execution_role.arn
    Bucket           = aws_s3_bucket.data_bucket.bucket
    BucketPrefix     = local.model_prefix
    JobNamePrefix    = local.job_name_prefix
    MaxEpochs        = local.max_epochs
    BaseModel        = local.base_model
    DataBucket       = aws_s3_bucket.data_bucket.bucket
    DataBucketPrefix = local.data_prefix
  })

  triggers = {
    # Only rerun when explicitly requested via retrain_model or when Lambda function changes
    rerun_on_change    = var.retrain_model ? timestamp() : "static"
    lambda_source_hash = module.sagemaker_train_lambda.lambda_function_source_code_hash
    # Only depend on data generation result if retrain_model is true
    data_generation = var.retrain_model ? aws_lambda_invocation.generate_demo_data.result : "static"
  }

  depends_on = [
    module.sagemaker_train_lambda,
    aws_lambda_invocation.generate_demo_data
  ]
}

# Step 3: Wait for training job to complete using pure Terraform polling
# Initial wait to allow training job to start
resource "time_sleep" "initial_wait" {
  depends_on = [aws_lambda_invocation.sagemaker_train]

  create_duration = "5m" # Wait 5 minutes for training job to start
}

# Create a script for checking training status
resource "local_file" "training_status_checker" {
  filename = "${path.module}/check_training_status.py"
  content = templatefile("${path.module}/training_status_checker.py.tpl", {
    function_name = module.sagemaker_train_is_complete_lambda.lambda_function_name
    region        = data.aws_region.current.id
  })
}

# Extract job name from training response first
locals {
  training_response = jsondecode(aws_lambda_invocation.sagemaker_train.result)
  job_name          = try(local.training_response.job_name, "${local.job_name_prefix}-unknown")
}

# Poll for training completion using external data source
data "external" "training_status" {
  program = ["python3", local_file.training_status_checker.filename]

  query = {
    job_name     = local.job_name
    max_attempts = "60" # 30 minutes with 30-second intervals
  }

  depends_on = [
    time_sleep.initial_wait,
    local_file.training_status_checker
  ]
}

# Extract model information from training job response
locals {
  model_path = try(local.training_response.model_path, "${local.model_prefix}/models/${local.job_name}/output/model.tar.gz")

  # Training completion status
  training_complete   = data.external.training_status.result.status == "complete"
  training_job_status = data.external.training_status.result
}

# Additional wait after training completion for model artifacts to be fully uploaded to S3
resource "time_sleep" "model_upload_wait" {
  depends_on = [data.external.training_status]

  create_duration = "2m" # Wait 2 minutes after training completion for model upload

  triggers = {
    training_status = data.external.training_status.result.status
  }
}
