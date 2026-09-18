# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Agent Companion Chat sub-feature (v0.4.0+)
# Conditional on var.enable_agent_companion_chat

# =============================================================================
# DynamoDB Table: agent_chat_sessions
# =============================================================================

resource "aws_dynamodb_table" "agent_chat_sessions" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name         = "${local.api_name}-agent-chat-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "sessionId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "sessionId"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  dynamic "server_side_encryption" {
    for_each = local.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = local.encryption_key_arn
    }
  }

  tags = var.tags
}

# DynamoDB Table: chat messages (PK/SK schema matching CloudFormation ChatMessagesTable)
resource "aws_dynamodb_table" "agent_chat_messages" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name         = "${local.api_name}-agent-chat-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  dynamic "server_side_encryption" {
    for_each = local.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = local.encryption_key_arn
    }
  }

  tags = var.tags
}

# DynamoDB Table: conversation memory (PK/SK schema matching CloudFormation IdHelperChatMemoryTable)
resource "aws_dynamodb_table" "agent_chat_memory" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name         = "${local.api_name}-agent-chat-memory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  dynamic "server_side_encryption" {
    for_each = local.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = local.encryption_key_arn
    }
  }

  tags = var.tags
}

# =============================================================================
# IAM Role: agent_chat_processor
# =============================================================================

resource "aws_iam_role" "agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "${local.api_name}-agent-chat-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "agent_chat_processor" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "agent-chat-processor-policy"
  role = aws_iam_role.agent_chat_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = compact([
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_messages[0].arn,
          "${aws_dynamodb_table.agent_chat_messages[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_memory[0].arn,
          "${aws_dynamodb_table.agent_chat_memory[0].arn}/index/*",
          local.tracking_table_arn,
          local.tracking_table_arn != null ? "${local.tracking_table_arn}/index/*" : null,
          local.configuration_table_arn,
          local.configuration_table_arn != null ? "${local.configuration_table_arn}/index/*" : null,
        ])
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:GetInferenceProfile"]
        Resource = "*"
      },
      {
        # OpenAI GPT-5.x via the bedrock-mantle endpoint (OpenAI Responses API),
        # a separate IAM action namespace. Mirrors upstream v0.5.16.
        Effect   = "Allow"
        Action   = ["bedrock-mantle:CreateInference", "bedrock-mantle:GetProject", "bedrock-mantle:ListProjects", "bedrock-mantle:ListTagsForResources"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:InvokeAgentRuntime"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:GetExecutionHistory",
          "states:ListExecutions"
        ]
        Resource = "*"
      },
      # appsync:GraphQL statement removed in the v0.6.4 REST migration — the
      # chat processor no longer publishes mutations to AppSync (the UI reads
      # the response stream / polls DynamoDB directly).
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = compact([local.encryption_key_arn])
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "agent_chat_processor_xray" {
  count      = var.enable_agent_companion_chat ? 1 : 0
  role       = aws_iam_role.agent_chat_processor[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: agent_chat_processor
# =============================================================================

resource "aws_cloudwatch_log_group" "agent_chat_processor" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-agent-chat-processor"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

# Build agent_chat_processor with bundled deps (strands-agents, bedrock-agentcore)
# Matches CloudFormation/SAM approach: pip install directly into the deployment package
# This avoids Lambda layer size limits (250MB unzipped) since strands+bedrock-agentcore alone exceed it
#
# IMPORTANT: archive_file is a data source (runs at plan time), so we cannot use it here.
# Instead, the null_resource builds AND zips the package, then we reference the zip directly.
# The source_code_hash is computed from a sha256 file written by the build script.
locals {
  agent_chat_processor_src        = "${path.module}/../../sources/src/lambda/agent_chat_processor"
  agent_chat_processor_build_dir  = "${path.module}/../../.terraform/tmp/agent_chat_processor_build"
  agent_chat_processor_idp_common = "${path.module}/../../sources/lib/idp_common_pkg"
  agent_chat_processor_zip        = "${path.module}/../../.terraform/archives/agent_chat_processor.zip"
  agent_chat_processor_hash_file  = "${path.module}/../../.terraform/archives/agent_chat_processor.zip.sha256"

  # CodeBuild build path when not building locally.
  use_codebuild_agent_chat = var.enable_agent_companion_chat && !var.lambda_local

  agent_chat_bucket_name = var.lambda_layers_bucket_arn != null ? split(":::", var.lambda_layers_bucket_arn)[1] : ""

  agent_chat_cb_src_key      = "source/agent-chat/lambda_src_${substr(local.agent_chat_input_hash, 0, 16)}.zip"
  agent_chat_cb_idp_key      = "source/agent-chat/idp_common_pkg_${substr(local.agent_chat_input_hash, 0, 16)}.zip"
  agent_chat_cb_artifact_key = "agent-chat/agent_chat_processor.zip"

  # Deterministic input hash over everything that changes the produced zip:
  # the Lambda source .py files, requirements.txt, and the idp_common package
  # (source files + pyproject.toml). Drives the build trigger, the source-zip
  # etag, and the function's source_code_hash so plan converges before the zip
  # exists on S3 — same input-hash idiom the layer module uses.
  agent_chat_src_files_hash = sha256(join("", [
    for f in fileset(local.agent_chat_processor_src, "**") :
    filesha256("${local.agent_chat_processor_src}/${f}")
  ]))
  agent_chat_idp_common_hash = sha256(join("", [
    for f in fileset("${local.agent_chat_processor_idp_common}/idp_common", "**/*.py") :
    filesha256("${local.agent_chat_processor_idp_common}/idp_common/${f}")
  ]))
  agent_chat_input_hash = sha256(join("-", [
    local.agent_chat_src_files_hash,
    local.agent_chat_idp_common_hash,
    filesha256("${local.agent_chat_processor_idp_common}/pyproject.toml"),
  ]))
}

resource "null_resource" "build_agent_chat_processor" {
  count = var.enable_agent_companion_chat && var.lambda_local ? 1 : 0

  triggers = {
    # Rebuild when source or idp_common changes
    src_hash = sha256(join("", [
      for f in fileset(local.agent_chat_processor_src, "**/*.py") :
      filesha256("${local.agent_chat_processor_src}/${f}")
    ]))
    idp_hash = sha256(join("", [
      for f in fileset("${local.agent_chat_processor_idp_common}/idp_common/agents", "**/*.py") :
      filesha256("${local.agent_chat_processor_idp_common}/idp_common/agents/${f}")
    ]))
    pyproject_hash = filesha256("${local.agent_chat_processor_idp_common}/pyproject.toml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      BUILD_DIR="${local.agent_chat_processor_build_dir}"
      SRC_DIR="${local.agent_chat_processor_src}"
      IDP_PKG="${local.agent_chat_processor_idp_common}"
      ZIP_OUT="${local.agent_chat_processor_zip}"
      HASH_OUT="${local.agent_chat_processor_hash_file}"

      # Clean and recreate build dir
      rm -rf "$BUILD_DIR"
      mkdir -p "$BUILD_DIR"
      mkdir -p "$(dirname "$ZIP_OUT")"

      # Copy Lambda source
      cp -r "$SRC_DIR"/. "$BUILD_DIR/"

      # Resolve absolute paths for Docker volume mounts
      ABS_BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
      ABS_IDP_PKG="$(cd "$IDP_PKG" && pwd)"
      ABS_ZIP_DIR="$(cd "$(dirname "$ZIP_OUT")" && pwd)"
      ZIP_BASENAME="$(basename "$ZIP_OUT")"
      ABS_ZIP_OUT="$ABS_ZIP_DIR/$ZIP_BASENAME"

      # Build inside a Linux x86_64 container to produce Lambda-compatible binaries
      # --platform linux/amd64 is required on Apple Silicon (arm64) hosts to produce x86_64 .so files
      # --entrypoint bash overrides the Lambda base image's custom entrypoint
      docker run --rm \
        --platform linux/amd64 \
        --entrypoint bash \
        -v "$ABS_BUILD_DIR:/build" \
        -v "$ABS_IDP_PKG:/idp_pkg:ro" \
        -v "$ABS_ZIP_DIR:/output" \
        public.ecr.aws/lambda/python:3.12 \
        -c "
          set -e
          # Install pip deps from requirements.txt, skipping the ./lib reference
          sed 's|^\./lib.*||g' /build/requirements.txt > /tmp/requirements_clean.txt
          pip3 install -r /tmp/requirements_clean.txt -t /build --quiet --no-cache-dir 2>/dev/null || true

          # Copy idp_pkg to a writable temp dir (pip needs to write egg-info during build)
          cp -rL /idp_pkg /tmp/idp_pkg_build

          # Install idp_common[agents] with all transitive deps (strands-agents, bedrock-agentcore)
          pip3 install '/tmp/idp_pkg_build[agents]' -t /build --quiet --no-cache-dir --upgrade

          # Copy idp_common source directly
          mkdir -p /build/idp_common
          cp -rL /tmp/idp_pkg_build/idp_common/. /build/idp_common/

          # Clean up build artifacts (keep dist-info for opentelemetry entry points)
          find /build -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true
          find /build -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
          find /build -type f -name '__editable__*' -delete 2>/dev/null || true
          find /build -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true

          # Create zip from inside the build dir (use python zipfile since zip may not be in the image)
          cd /build && python3 -c \"
import zipfile, os, sys
zf = zipfile.ZipFile('/output/$ZIP_BASENAME', 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.'):
    for file in files:
        if not file.endswith('.pyc'):
            filepath = os.path.join(root, file)
            zf.write(filepath)
zf.close()
print('Zip created: /output/$ZIP_BASENAME')
\"
          echo 'Docker build complete'
        "

      # Write sha256 hash file
      shasum -a 256 "$ABS_ZIP_OUT" | awk '{print $1}' > "$HASH_OUT"

      echo "Build complete: $ABS_ZIP_OUT ($(du -sh "$ABS_ZIP_OUT" | cut -f1))"
    EOT
  }
}

# Read the hash file written by the build — this forces Terraform to re-read it after apply
# The null_resource triggers ensure this file is always fresh when source changes
data "local_file" "agent_chat_processor_hash" {
  count    = var.enable_agent_companion_chat && var.lambda_local ? 1 : 0
  filename = local.agent_chat_processor_hash_file

  depends_on = [null_resource.build_agent_chat_processor]
}

# =============================================================================
# CodeBuild path (lambda_local = false, the default and what CI uses)
# =============================================================================
# Builds the self-contained agent_chat_processor zip in AWS CodeBuild instead
# of running `docker run` on the deploy host (the GitLab CI runner has no Docker
# daemon). Mirrors modules/lambda-layer-codebuild-idp: IAM role + policy (logs +
# s3), log group, time_sleep IAM-propagation guard, test_iam_permissions, an
# aws_codebuild_project with an inline S3-source buildspec, and the SHARED
data "archive_file" "agent_chat_cb_src" {
  count       = local.use_codebuild_agent_chat ? 1 : 0
  type        = "zip"
  source_dir  = local.agent_chat_processor_src
  output_path = "${path.module}/../../.terraform/tmp/agent_chat_cb_lambda_src.zip"
}

data "archive_file" "agent_chat_cb_idp" {
  count       = local.use_codebuild_agent_chat ? 1 : 0
  type        = "zip"
  source_dir  = local.agent_chat_processor_idp_common
  output_path = "${path.module}/../../.terraform/tmp/agent_chat_cb_idp_common_pkg.zip"
  excludes    = ["**/__pycache__/**", "**/*.pyc", "**/*.egg-info/**", "**/.pytest_cache/**", "tests/**"]
}

resource "aws_s3_object" "agent_chat_cb_src" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  bucket      = local.agent_chat_bucket_name
  key         = local.agent_chat_cb_src_key
  source      = data.archive_file.agent_chat_cb_src[0].output_path
  source_hash = data.archive_file.agent_chat_cb_src[0].output_md5
}

resource "aws_s3_object" "agent_chat_cb_idp" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  bucket      = local.agent_chat_bucket_name
  key         = local.agent_chat_cb_idp_key
  source      = data.archive_file.agent_chat_cb_idp[0].output_path
  source_hash = data.archive_file.agent_chat_cb_idp[0].output_md5
}

resource "aws_iam_role" "agent_chat_codebuild" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name = "${local.api_name}-agent-chat-cb-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "codebuild.amazonaws.com" }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "agent_chat_codebuild" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name = "CodeBuildPolicy"
  role = aws_iam_role.agent_chat_codebuild[0].id

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
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-agent-chat-${random_string.suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-agent-chat-${random_string.suffix.result}:*"
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
          var.lambda_layers_bucket_arn,
          "${var.lambda_layers_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "agent_chat_codebuild" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name              = "/aws/codebuild/${local.api_name}-agent-chat-${random_string.suffix.result}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${local.api_name}-agent-chat-codebuild-logs"
  })
}

# IAM eventual-consistency guard (project convention — see terraform-conventions
# steering). Matches the layer module's 30s wait before the build role is used.
resource "time_sleep" "agent_chat_cb_iam_propagation" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  depends_on = [
    aws_iam_role.agent_chat_codebuild,
    aws_iam_role_policy.agent_chat_codebuild,
    aws_cloudwatch_log_group.agent_chat_codebuild
  ]

  create_duration = "30s"
}

# IAM-propagation wait for the trigger Lambda's role/policy (separate from the
# CodeBuild-role wait to avoid a dependency cycle).
resource "time_sleep" "agent_chat_cb_trigger_iam_propagation" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  depends_on = [
    aws_iam_role.agent_chat_cb_trigger_lambda,
    aws_iam_role_policy.agent_chat_cb_trigger_lambda
  ]

  create_duration = "30s"
}

resource "null_resource" "agent_chat_cb_test_iam_permissions" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  depends_on = [time_sleep.agent_chat_cb_iam_propagation]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Testing IAM role propagation for agent-chat CodeBuild..."
      sleep 10
      echo "IAM role should be ready: ${aws_iam_role.agent_chat_codebuild[0].arn}"
    EOT
  }

  triggers = {
    role_arn  = aws_iam_role.agent_chat_codebuild[0].arn
    policy_id = aws_iam_role_policy.agent_chat_codebuild[0].id
  }
}

resource "aws_codebuild_project" "agent_chat_processor" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name          = "${local.api_name}-agent-chat-${random_string.suffix.result}"
  description   = "Build the self-contained agent_chat_processor Lambda zip (idp_common[agents] bundled)"
  build_timeout = 60
  service_role  = aws_iam_role.agent_chat_codebuild[0].arn

  depends_on = [
    null_resource.agent_chat_cb_test_iam_permissions,
    aws_iam_role.agent_chat_codebuild,
    aws_iam_role_policy.agent_chat_codebuild,
    aws_cloudwatch_log_group.agent_chat_codebuild
  ]

  dynamic "vpc_config" {
    for_each = local.codebuild_has_network ? [1] : []
    content {
      vpc_id             = var.vpc_config.vpc_id
      subnets            = var.vpc_config.subnet_ids
      security_group_ids = var.vpc_config.security_group_ids
    }
  }

  # The buildspec uploads the produced zip to a deterministic S3 key itself
  # (the role has s3:PutObject), so no CodeBuild-managed artifact is needed.
  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    # Architecture-aware: arm64 uses the aarch64 standard image + ARM_CONTAINER.
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
      name  = "ASSETS_BUCKET"
      value = local.agent_chat_bucket_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ARTIFACT_KEY"
      value = local.agent_chat_cb_artifact_key
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "IDP_COMMON_KEY"
      value = local.agent_chat_cb_idp_key
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "IDP_COMMON_EXTRAS"
      value = "agents"
      type  = "PLAINTEXT"
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.agent_chat_codebuild[0].name
    }
  }

  source {
    type      = "S3"
    location  = "${local.agent_chat_bucket_name}/${aws_s3_object.agent_chat_cb_src[0].key}"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.12
  build:
    commands:
      - |
        set -e
        BUILD=/tmp/build
        rm -rf "$BUILD" /tmp/idp_common_pkg
        mkdir -p "$BUILD" /tmp/idp_common_pkg

        # The CodeBuild S3 source is the Lambda source zip, unpacked at the root
        # (index.py, requirements.txt, ...). Fetch + unpack idp_common_pkg from
        # its own S3 object.
        aws s3 cp "s3://$ASSETS_BUCKET/$IDP_COMMON_KEY" /tmp/idp_common_pkg.zip
        (cd /tmp/idp_common_pkg && unzip -q /tmp/idp_common_pkg.zip)

        # (1) Lambda source into the build dir.
        cp -rL ./. "$BUILD/"

        # (2) pip install requirements.txt, stripping any ./lib line first.
        sed 's|^\./lib.*||g' "$BUILD/requirements.txt" > /tmp/requirements_clean.txt
        pip install -r /tmp/requirements_clean.txt -t "$BUILD" --no-cache-dir || true

        # (3) pip install idp_common_pkg[agents] (strands-agents, bedrock-agentcore, ...).
        pip install "/tmp/idp_common_pkg[$IDP_COMMON_EXTRAS]" -t "$BUILD" --no-cache-dir --upgrade

        # (4) Copy the idp_common package source into the build dir.
        mkdir -p "$BUILD/idp_common"
        cp -rL /tmp/idp_common_pkg/idp_common/. "$BUILD/idp_common/"

        # (5) Clean build artifacts.
        find "$BUILD" -type d -name '*.egg-info'   -exec rm -rf {} + 2>/dev/null || true
        find "$BUILD" -type d -name '__pycache__'  -exec rm -rf {} + 2>/dev/null || true
        find "$BUILD" -type d -name 'tests'        -exec rm -rf {} + 2>/dev/null || true
        find "$BUILD" -type f -name '__editable__*' -delete 2>/dev/null || true
        find "$BUILD" -type f -name '*.pyc'        -delete 2>/dev/null || true

        # (6) Zip the build dir contents (files at archive root; index.py at root).
        cd "$BUILD" && zip -r -q /tmp/agent_chat_processor.zip . -x '*.pyc'

        aws s3 cp /tmp/agent_chat_processor.zip "s3://$ASSETS_BUCKET/$ARTIFACT_KEY"
        echo "Uploaded s3://$ASSETS_BUCKET/$ARTIFACT_KEY"
  post_build:
    commands:
      - echo agent_chat_processor build complete
EOF
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# CodeBuild trigger Lambda (reuses the SHARED idp-layer-codebuild-trigger source
# used by lambda-layer-codebuild-idp): start_build + synchronous monitor to
# completion, returning statusCode 200 on SUCCEEDED.
# ----------------------------------------------------------------------------
data "archive_file" "agent_chat_cb_trigger_lambda" {
  count       = local.use_codebuild_agent_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/idp-layer-codebuild-trigger"
  output_path = "${path.module}/../../.terraform/tmp/agent_chat_cb_trigger_lambda_${random_string.suffix.result}.zip"
}

resource "aws_iam_role" "agent_chat_cb_trigger_lambda" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name = "${local.api_name}-agent-chat-cbt-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "agent_chat_cb_trigger_lambda" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name = "CodeBuildTriggerLambdaPolicy"
  role = aws_iam_role.agent_chat_cb_trigger_lambda[0].id

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
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.api_name}-agent-chat-cbt-*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-agent-chat-${random_string.suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-agent-chat-${random_string.suffix.result}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [
          aws_codebuild_project.agent_chat_processor[0].arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "agent_chat_cb_trigger_lambda" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  name              = "/aws/lambda/${local.api_name}-agent-chat-cbt-${random_string.suffix.result}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${local.api_name}-agent-chat-codebuild-trigger-lambda-logs"
  })
}

resource "aws_lambda_function" "agent_chat_cb_trigger" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  architectures    = [var.lambda_architecture]
  filename         = data.archive_file.agent_chat_cb_trigger_lambda[0].output_path
  function_name    = "${local.api_name}-agent-chat-cbt-${random_string.suffix.result}"
  role             = aws_iam_role.agent_chat_cb_trigger_lambda[0].arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 256
  source_code_hash = data.archive_file.agent_chat_cb_trigger_lambda[0].output_base64sha256

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.agent_chat_cb_trigger_lambda,
    aws_iam_role_policy.agent_chat_cb_trigger_lambda
  ]

  tags = var.tags
}

# Runs the CodeBuild project synchronously at apply and blocks until it
# SUCCEEDS (the trigger Lambda monitors to completion). Only after this returns
# does the produced zip exist at agent_chat_cb_artifact_key.
resource "aws_lambda_invocation" "agent_chat_trigger_codebuild" {
  count = local.use_codebuild_agent_chat ? 1 : 0

  function_name = aws_lambda_function.agent_chat_cb_trigger[0].function_name

  input = jsonencode({
    codebuild_project_name = aws_codebuild_project.agent_chat_processor[0].name
    requirements_hash      = local.agent_chat_input_hash
    idp_common_extras      = ["agents"]
    force_rebuild          = false
    buildspec_hash         = md5(aws_codebuild_project.agent_chat_processor[0].source[0].buildspec)
  })

  triggers = {
    input_hash     = local.agent_chat_input_hash
    buildspec_hash = md5(aws_codebuild_project.agent_chat_processor[0].source[0].buildspec)
  }

  depends_on = [
    aws_codebuild_project.agent_chat_processor,
    aws_iam_role_policy.agent_chat_codebuild,
    aws_s3_object.agent_chat_cb_src,
    aws_s3_object.agent_chat_cb_idp,
    time_sleep.agent_chat_cb_iam_propagation,
    time_sleep.agent_chat_cb_trigger_iam_propagation
  ]
}

resource "aws_lambda_function" "agent_chat_processor" {
  architectures = [var.lambda_architecture]
  count         = var.enable_agent_companion_chat ? 1 : 0

  function_name = "${local.api_name}-agent-chat-processor"
  role          = aws_iam_role.agent_chat_processor[0].arn

  # CodeBuild path uses s3_bucket/s3_key; local path uses filename.
  filename  = local.use_codebuild_agent_chat ? null : local.agent_chat_processor_zip
  s3_bucket = local.use_codebuild_agent_chat ? local.agent_chat_bucket_name : null
  s3_key    = local.use_codebuild_agent_chat ? local.agent_chat_cb_artifact_key : null
  source_code_hash = local.use_codebuild_agent_chat ? local.agent_chat_input_hash : base64encode(
    data.local_file.agent_chat_processor_hash[0].content
  )
  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 600
  memory_size = 1024

  # No layers - all deps bundled into the zip (matches CloudFormation/SAM approach)
  # strands-agents + bedrock-agentcore exceed Lambda's 250MB limit when combined with any layer
  layers = []

  environment {
    variables = {
      LOG_LEVEL                   = var.log_level
      STRANDS_LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE         = aws_dynamodb_table.agent_chat_sessions[0].name
      CHAT_MESSAGES_TABLE         = aws_dynamodb_table.agent_chat_messages[0].name
      ID_HELPER_CHAT_MEMORY_TABLE = aws_dynamodb_table.agent_chat_memory[0].name
      MEMORY_METHOD               = "dynamodb"
      STREAMING_ENABLED           = "true"
      BEDROCK_REGION              = data.aws_region.current.region
      CONFIGURATION_TABLE_NAME    = local.configuration_table_name != null ? local.configuration_table_name : ""
      TRACKING_TABLE_NAME         = local.tracking_table_name != null ? local.tracking_table_name : ""
      LOOKUP_FUNCTION_NAME        = var.lookup_function_name != null ? var.lookup_function_name : ""
      INPUT_BUCKET                = local.input_bucket_name
      OUTPUT_BUCKET               = local.output_bucket_name
      # APPSYNC_API_URL intentionally empty post-v0.6.4: the processor writes
      # DynamoDB directly and streams to the browser instead of publishing to
      # AppSync (see docs/migration-appsync-to-rest.md §2/§3).
      APPSYNC_API_URL             = ""
      MAX_CONVERSATION_TURNS      = "20"
      MAX_MESSAGE_SIZE_KB         = "8.5"
      DATA_RETENTION_DAYS         = tostring(var.data_retention_in_days)
      AWS_STACK_NAME              = local.api_name
      CLOUDWATCH_LOG_GROUP_PREFIX = "/aws/lambda/${local.api_name}"
      ATHENA_DATABASE             = var.agent_analytics.reporting_database_name != null ? var.agent_analytics.reporting_database_name : ""
      ATHENA_OUTPUT_LOCATION      = var.agent_analytics.reporting_bucket_arn != null ? "s3://${element(split(":", var.agent_analytics.reporting_bucket_arn), length(split(":", var.agent_analytics.reporting_bucket_arn)) - 1)}/athena-results/" : ""
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # On the CodeBuild path, block until the build has produced the S3 artifact.
  depends_on = [
    aws_cloudwatch_log_group.agent_chat_processor,
    aws_lambda_invocation.agent_chat_trigger_codebuild,
  ]
  tags = var.tags
}

# =============================================================================
# IAM Role: agent_chat_resolver (AppSync → Lambda)
# =============================================================================

resource "aws_iam_role" "agent_chat_resolver" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "${local.api_name}-agent-chat-resolver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "agent_chat_resolver" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "agent-chat-resolver-policy"
  role = aws_iam_role.agent_chat_resolver[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.agent_chat_processor[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_messages[0].arn,
          "${aws_dynamodb_table.agent_chat_messages[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = compact([local.encryption_key_arn])
      }
    ]
  })
}

# =============================================================================
# Lambda: agent_chat_resolver
# =============================================================================

resource "aws_cloudwatch_log_group" "agent_chat_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-agent-chat-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "agent_chat_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/agent_chat_resolver"
  output_path = "${path.module}/../../.terraform/archives/agent_chat_resolver.zip"
}

resource "aws_lambda_function" "agent_chat_resolver" {
  architectures = [var.lambda_architecture]
  count         = var.enable_agent_companion_chat ? 1 : 0

  function_name    = "${local.api_name}-agent-chat-resolver"
  role             = aws_iam_role.agent_chat_resolver[0].arn
  filename         = data.archive_file.agent_chat_resolver[0].output_path
  source_code_hash = data.archive_file.agent_chat_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30

  layers = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                     = var.log_level
      AGENT_CHAT_PROCESSOR_FUNCTION = aws_lambda_function.agent_chat_processor[0].function_name
      AGENT_CHAT_PROCESSOR_ARN      = aws_lambda_function.agent_chat_processor[0].arn
      CHAT_MESSAGES_TABLE           = aws_dynamodb_table.agent_chat_messages[0].name
      CHAT_SESSIONS_TABLE           = aws_dynamodb_table.agent_chat_sessions[0].name
      DATA_RETENTION_DAYS           = tostring(var.data_retention_in_days)
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.agent_chat_resolver]
  tags       = var.tags
}

# =============================================================================
# Session management resolver Lambdas (shared IAM role)
# =============================================================================

resource "aws_iam_role" "chat_session_resolvers" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "${local.api_name}-chat-session-resolvers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "chat_session_resolvers" {
  count = var.enable_agent_companion_chat ? 1 : 0

  name = "chat-session-resolvers-policy"
  role = aws_iam_role.chat_session_resolvers[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.agent_chat_sessions[0].arn,
          "${aws_dynamodb_table.agent_chat_sessions[0].arn}/index/*",
          aws_dynamodb_table.agent_chat_messages[0].arn,
          "${aws_dynamodb_table.agent_chat_messages[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = compact([local.encryption_key_arn])
      }
    ]
  })
}

# create_chat_session_resolver
resource "aws_cloudwatch_log_group" "create_chat_session_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-create-chat-session-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "create_chat_session_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/create_chat_session_resolver"
  output_path = "${path.module}/../../.terraform/archives/create_chat_session_resolver.zip"
}

resource "aws_lambda_function" "create_chat_session_resolver" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-create-chat-session-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.create_chat_session_resolver[0].output_path
  source_code_hash = data.archive_file.create_chat_session_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.create_chat_session_resolver]
  tags       = var.tags
}

# list_agent_chat_sessions_resolver
resource "aws_cloudwatch_log_group" "list_agent_chat_sessions_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-list-chat-sessions-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "list_agent_chat_sessions_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/list_agent_chat_sessions_resolver"
  output_path = "${path.module}/../../.terraform/archives/list_agent_chat_sessions_resolver.zip"
}

resource "aws_lambda_function" "list_agent_chat_sessions_resolver" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-list-chat-sessions-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.list_agent_chat_sessions_resolver[0].output_path
  source_code_hash = data.archive_file.list_agent_chat_sessions_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.list_agent_chat_sessions_resolver]
  tags       = var.tags
}

# get_agent_chat_messages_resolver
resource "aws_cloudwatch_log_group" "get_agent_chat_messages_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-get-chat-messages-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "get_agent_chat_messages_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/get_agent_chat_messages_resolver"
  output_path = "${path.module}/../../.terraform/archives/get_agent_chat_messages_resolver.zip"
}

resource "aws_lambda_function" "get_agent_chat_messages_resolver" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-get-chat-messages-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.get_agent_chat_messages_resolver[0].output_path
  source_code_hash = data.archive_file.get_agent_chat_messages_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_MESSAGES_TABLE = aws_dynamodb_table.agent_chat_messages[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.get_agent_chat_messages_resolver]
  tags       = var.tags
}

# delete_agent_chat_session_resolver
resource "aws_cloudwatch_log_group" "delete_agent_chat_session_resolver" {
  count             = var.enable_agent_companion_chat ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-delete-chat-session-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "delete_agent_chat_session_resolver" {
  count       = var.enable_agent_companion_chat ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/delete_agent_chat_session_resolver"
  output_path = "${path.module}/../../.terraform/archives/delete_agent_chat_session_resolver.zip"
}

resource "aws_lambda_function" "delete_agent_chat_session_resolver" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_agent_companion_chat ? 1 : 0
  function_name    = "${local.api_name}-delete-chat-session-resolver"
  role             = aws_iam_role.chat_session_resolvers[0].arn
  filename         = data.archive_file.delete_agent_chat_session_resolver[0].output_path
  source_code_hash = data.archive_file.delete_agent_chat_session_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      CHAT_MESSAGES_TABLE = aws_dynamodb_table.agent_chat_messages[0].name
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.agent_chat_sessions[0].name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.delete_agent_chat_session_resolver]
  tags       = var.tags
}

# =============================================================================
# NOTE: The AppSync data sources/resolvers for Agent Companion Chat
# (sendAgentChatMessage, listChatSessions, getChatMessages / getAgentChatMessages,
# deleteChatSession, updateChatSessionTitle) were removed in the v0.6.4 REST
# migration. These fields are now routed to the same resolver Lambdas by the
# dispatcher (see dispatcher.tf field_function_map); the dispatcher role grants
# the invokes. The Lambda functions/tables/roles above are unchanged.
# =============================================================================

resource "aws_iam_role_policy_attachment" "agent_chat_codebuild_vpc_access" {
  count      = local.use_codebuild_agent_chat && local.codebuild_has_network ? 1 : 0
  role       = aws_iam_role.agent_chat_codebuild[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSCodeBuildVPCAccessExecutionRole"
}
