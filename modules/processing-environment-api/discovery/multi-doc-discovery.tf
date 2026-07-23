# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Multi-Document Discovery pipeline.
#
# Ports the reference CloudFormation stack
# (sources/nested/multi-doc-discovery/template.yaml + the MultiDocDiscovery*
# resources in sources/template.yaml) to Terraform. The pipeline is a Step
# Functions state machine that runs: Prepare -> Embed -> Cluster ->
# Analyze (Map) -> Save.
#
# The Embed/Cluster/Analyze/Save functions are container-image Lambdas because
# their dependencies (scikit-learn, scipy, numpy, strands-agents) exceed
# Lambda's 250MB unzipped layer limit. Their image is built by a CodeBuild
# project (Docker) and pushed to ECR. The Prepare function is a plain zip
# Lambda on the base layer.
#
# Without this pipeline the startMultiDocDiscovery mutation fails with
# "MULTI_DOC_DISCOVERY_STATE_MACHINE_ARN not configured".

locals {
  # Source layout in the repo.
  multi_doc_src           = "${path.module}/../../../sources/src/lambda/multi_doc_discovery"
  idp_common_pkg_src      = "${path.module}/../../../sources/lib/idp_common_pkg"
  multi_doc_build_dir     = "${local.module_build_dir}/multi_doc_discovery"
  multi_doc_codebuild_src = "${local.multi_doc_build_dir}/codebuild_src"

  lambda_layers_bucket_name = split(":::", var.lambda_layers_bucket_arn)[1]

  # ECR image reference the container Lambdas consume.
  multi_doc_image_uri = "${aws_ecr_repository.multi_doc_discovery.repository_url}:latest"

  # Common env for the Bedrock hub-role assumption (only set when provided).
  bedrock_hub_env = merge(
    var.bedrock_hub_role_arn != "" ? { BEDROCK_ASSUME_ROLE_ARN = var.bedrock_hub_role_arn } : {},
    var.bedrock_hub_role_external_id != "" ? { BEDROCK_ASSUME_ROLE_EXTERNAL_ID = var.bedrock_hub_role_external_id } : {},
    var.bedrock_hub_role_session_name != "" ? { BEDROCK_ASSUME_ROLE_SESSION_NAME = var.bedrock_hub_role_session_name } : {},
  )

  # KMS statement fragment reused by the container Lambda roles.
  multi_doc_kms_actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]

  bedrock_model_resources = [
    "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
    "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:application-inference-profile/*",
  ]
}

# =============================================================================
# ECR Repository for the multi-doc container image
# =============================================================================

resource "aws_ecr_repository" "multi_doc_discovery" {
  #checkov:skip=CKV_AWS_51:Mutable tags allowed for workflow flexibility (matches reference CFN)
  name                 = "${var.name_prefix}-multi-doc-${local.suffix}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  dynamic "encryption_configuration" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = var.encryption_key_arn
    }
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "multi_doc_discovery" {
  repository = aws_ecr_repository.multi_doc_discovery.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

# =============================================================================
# Stage CodeBuild source (multi_doc_discovery handlers + idp_common_pkg) to S3
# =============================================================================

# Assemble the build context: the Docker build expects
#   src/lambda/multi_doc_discovery/*.py  and  lib/idp_common_pkg/
resource "null_resource" "multi_doc_stage_source" {
  triggers = {
    # Rebuild the source zip when any handler or the idp_common package changes.
    handlers_hash  = sha1(join(",", [for f in fileset(local.multi_doc_src, "*.py") : filesha256("${local.multi_doc_src}/${f}")]))
    idp_pyproject  = filesha256("${local.idp_common_pkg_src}/pyproject.toml")
    staging_script = filesha256("${path.module}/multi-doc-discovery.tf")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      rm -rf "${local.multi_doc_codebuild_src}"
      mkdir -p "${local.multi_doc_codebuild_src}/src/lambda/multi_doc_discovery"
      mkdir -p "${local.multi_doc_codebuild_src}/lib/idp_common_pkg"
      # Handler sources for the container image.
      cp "${local.multi_doc_src}"/*.py "${local.multi_doc_codebuild_src}/src/lambda/multi_doc_discovery/"
      # idp_common package, excluding dev/build artifacts (mirrors the layer build).
      rsync -a --delete \
        --exclude='__pycache__/' \
        --exclude='*.py[cod]' \
        --exclude='*.so' \
        --exclude='.venv/' --exclude='venv/' \
        --exclude='build/' --exclude='dist/' \
        --exclude='*.egg-info/' --exclude='.eggs/' \
        --exclude='tests/' \
        --exclude='uv.lock' --exclude='poetry.lock' \
        --exclude='.git/' \
        "${local.idp_common_pkg_src}/" "${local.multi_doc_codebuild_src}/lib/idp_common_pkg/"
    EOT
  }

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "multi_doc_source" {
  type        = "zip"
  source_dir  = local.multi_doc_codebuild_src
  output_path = "${local.multi_doc_build_dir}/multi-doc-discovery-source.zip"

  depends_on = [null_resource.multi_doc_stage_source]
}

resource "aws_s3_object" "multi_doc_source" {
  bucket = local.lambda_layers_bucket_name
  key    = "source/${var.name_prefix}-multi-doc/multi-doc-discovery-source.zip"
  source = data.archive_file.multi_doc_source.output_path
  etag   = data.archive_file.multi_doc_source.output_md5
}

# =============================================================================
# CodeBuild project — builds the Docker image and pushes it to ECR
# =============================================================================

resource "aws_iam_role" "multi_doc_codebuild_role" {
  name = "${var.name_prefix}-multidoc-cb-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.${data.aws_partition.current.dns_suffix}" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "multi_doc_codebuild_policy" {
  name = "MultiDocCodeBuildPolicy"
  role = aws_iam_role.multi_doc_codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-multi-doc-${local.suffix}*"
      },
      {
        # ecr:GetAuthorizationToken is account-scoped and requires "*".
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.multi_doc_discovery.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [var.lambda_layers_bucket_arn, "${var.lambda_layers_bucket_arn}/*"]
      }
      ], var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = local.multi_doc_kms_actions
        Resource = var.encryption_key_arn
    }] : [])
  })
}

resource "aws_cloudwatch_log_group" "multi_doc_codebuild_logs" {
  name              = "/aws/codebuild/${var.name_prefix}-multi-doc-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Give IAM time to propagate before CodeBuild assumes the role.
resource "time_sleep" "multi_doc_codebuild_iam" {
  depends_on = [
    aws_iam_role.multi_doc_codebuild_role,
    aws_iam_role_policy.multi_doc_codebuild_policy,
    aws_cloudwatch_log_group.multi_doc_codebuild_logs,
  ]
  create_duration = "30s"
}

resource "aws_codebuild_project" "multi_doc_discovery" {
  name          = "${var.name_prefix}-multi-doc-${local.suffix}"
  description   = "Build Docker image for Multi-Document Discovery Lambda functions"
  service_role  = aws_iam_role.multi_doc_codebuild_role.arn
  build_timeout = 30

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    # PrivilegedMode is required for Docker builds. amazonlinux2 x86_64 image
    # matches the reference CFN; the resulting Lambda image targets x86_64.
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.id
    }
    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.multi_doc_discovery.repository_url
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.multi_doc_codebuild_logs.name
    }
  }

  source {
    type      = "S3"
    location  = "${local.lambda_layers_bucket_name}/${aws_s3_object.multi_doc_source.key}"
    buildspec = <<-EOF
      version: 0.2
      phases:
        pre_build:
          commands:
            - echo Logging in to Amazon ECR...
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.${data.aws_partition.current.dns_suffix}
        build:
          commands:
            - echo "Source directory contents:"
            - ls -la
            - echo "Creating requirements.txt..."
            - |
              cat > requirements.txt << 'REQS'
              scikit-learn>=1.5.0
              scipy>=1.14.0
              numpy==1.26.4
              Pillow==12.1.1
              pypdfium2>=5.5.0
              jinja2>=3.1.0
              strands-agents==1.14.0
              boto3>=1.34.0
              pyyaml>=6.0.0
              pydantic>=2.0.0
              REQS
            - echo "Creating Dockerfile..."
            - |
              cat > Dockerfile << 'DOCKERFILE'
              FROM public.ecr.aws/lambda/python:3.12 AS builder
              RUN dnf install -y gcc gcc-c++ make && dnf clean all
              COPY requirements.txt /tmp/requirements.txt
              RUN pip install --no-cache-dir --target /opt/python -r /tmp/requirements.txt
              COPY lib/idp_common_pkg /tmp/idp_common_pkg
              RUN pip install --no-cache-dir --no-deps --target /opt/python /tmp/idp_common_pkg
              FROM public.ecr.aws/lambda/python:3.12
              COPY --from=builder /opt/python $${LAMBDA_TASK_ROOT}/../opt/python
              ENV PYTHONPATH="$${LAMBDA_TASK_ROOT}/../opt/python:$${LAMBDA_TASK_ROOT}"
              COPY src/lambda/multi_doc_discovery/*.py $${LAMBDA_TASK_ROOT}/
              CMD ["embed_handler.handler"]
              DOCKERFILE
            - echo "Building Docker image..."
            - docker build -t $ECR_REPO_URI:$IMAGE_TAG .
        post_build:
          commands:
            - echo Pushing Docker image to ECR...
            - docker push $ECR_REPO_URI:$IMAGE_TAG
            - echo Build completed on `date`
    EOF
  }

  depends_on = [time_sleep.multi_doc_codebuild_iam]

  tags = var.tags
}

# =============================================================================
# CodeBuild trigger Lambda (reuses the repo's generic layer-codebuild-trigger)
# =============================================================================

data "archive_file" "multi_doc_build_trigger" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/lambda/layer-codebuild-trigger"
  output_path = "${local.multi_doc_build_dir}/multi-doc-build-trigger.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "multi_doc_build_trigger_role" {
  name = "${var.name_prefix}-multidoc-trig-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "multi_doc_build_trigger_policy" {
  name = "MultiDocBuildTriggerPolicy"
  role = aws_iam_role.multi_doc_build_trigger_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-multidoc-trig-${local.suffix}*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-multi-doc-${local.suffix}*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
        Resource = aws_codebuild_project.multi_doc_discovery.arn
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "multi_doc_build_trigger_logs" {
  name              = "/aws/lambda/${var.name_prefix}-multidoc-trig-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_lambda_function" "multi_doc_build_trigger" {
  function_name    = "${var.name_prefix}-multidoc-trig-${local.suffix}"
  filename         = data.archive_file.multi_doc_build_trigger.output_path
  source_code_hash = data.archive_file.multi_doc_build_trigger.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.multi_doc_build_trigger_role.arn

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.multi_doc_build_trigger_logs,
    aws_iam_role_policy.multi_doc_build_trigger_policy,
  ]

  tags = var.tags
}

# Invoke the trigger to run the Docker build during apply. Container Lambdas
# depend on this completing so the ECR image exists before they're created.
resource "aws_lambda_invocation" "multi_doc_build" {
  function_name = aws_lambda_function.multi_doc_build_trigger.function_name

  input = jsonencode({
    codebuild_project_name = aws_codebuild_project.multi_doc_discovery.name
    requirements_hash      = data.archive_file.multi_doc_source.output_md5
    force_rebuild          = var.force_rebuild_multi_doc_image
    buildspec_hash         = md5(aws_codebuild_project.multi_doc_discovery.source[0].buildspec)
  })

  triggers = {
    source_hash    = data.archive_file.multi_doc_source.output_md5
    buildspec_hash = md5(aws_codebuild_project.multi_doc_discovery.source[0].buildspec)
    force_rebuild  = var.force_rebuild_multi_doc_image ? timestamp() : "static"
  }

  depends_on = [
    aws_codebuild_project.multi_doc_discovery,
    aws_s3_object.multi_doc_source,
    aws_iam_role_policy.multi_doc_build_trigger_policy,
    time_sleep.multi_doc_codebuild_iam,
  ]
}

# =============================================================================
# Prepare Lambda (zip, base layer) — lists documents for the pipeline
# =============================================================================

data "archive_file" "multi_doc_prepare" {
  type        = "zip"
  source_dir  = local.multi_doc_src
  output_path = "${local.multi_doc_build_dir}/multi-doc-prepare.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "multi_doc_prepare_role" {
  name = "${var.name_prefix}-multidoc-prep-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "multi_doc_prepare_policy" {
  name = "MultiDocPreparePolicy"
  role = aws_iam_role.multi_doc_prepare_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.discovery_bucket.arn, "${aws_s3_bucket.discovery_bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.input_bucket_arn, "${var.input_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["appsync:GraphQL"]
        Resource = "${var.appsync_api_arn}/*"
      }
      ], var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = local.multi_doc_kms_actions
        Resource = var.encryption_key_arn
    }] : [])
  })
}

resource "aws_cloudwatch_log_group" "multi_doc_prepare_logs" {
  name              = "/aws/lambda/${var.name_prefix}-multidoc-prepare-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_lambda_function" "multi_doc_prepare" {
  function_name    = "${var.name_prefix}-multidoc-prepare-${local.suffix}"
  filename         = data.archive_file.multi_doc_prepare.output_path
  source_code_hash = data.archive_file.multi_doc_prepare.output_base64sha256
  handler          = "prepare_handler.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  role             = aws_iam_role.multi_doc_prepare_role.arn
  layers           = [var.base_layer_arn]
  kms_key_arn      = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL        = var.log_level
      DISCOVERY_BUCKET = aws_s3_bucket.discovery_bucket.id
      APPSYNC_API_URL  = var.appsync_api_url
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [aws_cloudwatch_log_group.multi_doc_prepare_logs]

  tags = var.tags
}

# =============================================================================
# Container-image Lambdas: Embed, Cluster, Analyze, Save
# =============================================================================

# Shared execution role for the four container Lambdas. Their permission sets
# in the reference CFN overlap heavily (S3 CRUD on discovery bucket, KMS,
# Bedrock invoke, AppSync, CloudWatch metrics, config-table read); we grant the
# union so a single role serves all four.
resource "aws_iam_role" "multi_doc_container_role" {
  name = "${var.name_prefix}-multidoc-fn-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "multi_doc_container_policy" {
  name = "MultiDocContainerPolicy"
  role = aws_iam_role.multi_doc_container_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.discovery_bucket.arn, "${aws_s3_bucket.discovery_bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.input_bucket_arn, "${var.input_bucket_arn}/*"]
      },
      {
        # Save reads and writes config (DynamoDBCrudPolicy); others read it.
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem"]
        Resource = [var.configuration_table_arn, "${var.configuration_table_arn}/index/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:GetInferenceProfile"]
        Resource = local.bedrock_model_resources
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["appsync:GraphQL"]
        Resource = "${var.appsync_api_arn}/*"
      }
      ],
      var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = local.multi_doc_kms_actions
        Resource = var.encryption_key_arn
      }] : [],
      var.bedrock_hub_role_arn != "" ? [{
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }] : [],
    )
  })
}

# The four container functions differ only in the image command and a couple of
# tuning knobs (memory/timeout). Drive them from a map to avoid repetition.
locals {
  multi_doc_container_functions = {
    embed = {
      command     = "embed_handler.handler"
      description = "Multi-doc discovery - generate multimodal embeddings"
      memory_size = 2048
      timeout     = 900
    }
    cluster = {
      command     = "cluster_handler.handler"
      description = "Multi-doc discovery - cluster documents by embedding similarity"
      memory_size = 2048
      timeout     = 300
    }
    analyze = {
      command     = "analyze_handler.handler"
      description = "Multi-doc discovery - analyze cluster with Strands agent"
      memory_size = 2048
      timeout     = 900
    }
    save = {
      command     = "save_handler.handler"
      description = "Multi-doc discovery - save results and generate reflection"
      memory_size = 1024
      timeout     = 900
    }
  }
}

resource "aws_cloudwatch_log_group" "multi_doc_container_logs" {
  for_each = local.multi_doc_container_functions

  name              = "/aws/lambda/${var.name_prefix}-multidoc-${each.key}-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_lambda_function" "multi_doc_container" {
  for_each = local.multi_doc_container_functions

  function_name = "${var.name_prefix}-multidoc-${each.key}-${local.suffix}"
  package_type  = "Image"
  image_uri     = local.multi_doc_image_uri
  role          = aws_iam_role.multi_doc_container_role.arn
  description   = each.value.description
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout
  kms_key_arn   = var.encryption_key_arn

  image_config {
    command = [each.value.command]
  }

  environment {
    variables = merge({
      LOG_LEVEL                = var.log_level
      DISCOVERY_BUCKET         = aws_s3_bucket.discovery_bucket.id
      CONFIGURATION_TABLE_NAME = element(split("/", var.configuration_table_arn), 1)
      APPSYNC_API_URL          = var.appsync_api_url
    }, local.bedrock_hub_env)
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # The ECR image must exist before the function can be created.
  depends_on = [
    aws_lambda_invocation.multi_doc_build,
    aws_cloudwatch_log_group.multi_doc_container_logs,
  ]

  tags = var.tags
}

# =============================================================================
# Step Functions State Machine: prepare -> embed -> cluster -> analyze -> save
# =============================================================================

resource "aws_iam_role" "multi_doc_state_machine_role" {
  name = "${var.name_prefix}-multidoc-sfn-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.${data.aws_partition.current.dns_suffix}" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "multi_doc_state_machine_policy" {
  name = "MultiDocStateMachinePolicy"
  role = aws_iam_role.multi_doc_state_machine_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = concat(
          [aws_lambda_function.multi_doc_prepare.arn],
          [for fn in aws_lambda_function.multi_doc_container : fn.arn],
        )
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.discovery_tracking.arn
      }
      ], var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
        Resource = var.encryption_key_arn
    }] : [])
  })
}

resource "aws_sfn_state_machine" "multi_doc_discovery" {
  name     = "${var.name_prefix}-multi-doc-${local.suffix}"
  role_arn = aws_iam_role.multi_doc_state_machine_role.arn

  definition = templatefile("${local.multi_doc_src}/statemachine.asl.json", {
    PrepareFunction        = aws_lambda_function.multi_doc_prepare.arn
    EmbedFunction          = aws_lambda_function.multi_doc_container["embed"].arn
    ClusterFunction        = aws_lambda_function.multi_doc_container["cluster"].arn
    AnalyzeFunction        = aws_lambda_function.multi_doc_container["analyze"].arn
    SaveFunction           = aws_lambda_function.multi_doc_container["save"].arn
    DiscoveryTrackingTable = aws_dynamodb_table.discovery_tracking.name
  })

  tags = var.tags
}
