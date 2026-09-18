# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Test Studio sub-feature (v0.4.6+)
# Conditional on var.enable_test_studio

# =============================================================================
# S3 Bucket: test_sets
# =============================================================================

resource "aws_s3_bucket" "test_sets" {
  count  = var.enable_test_studio ? 1 : 0
  bucket = "${local.api_name}-test-sets"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "test_sets" {
  count  = var.enable_test_studio ? 1 : 0
  bucket = aws_s3_bucket.test_sets[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test_sets" {
  count  = var.enable_test_studio ? 1 : 0
  bucket = aws_s3_bucket.test_sets[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.encryption_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.encryption_key_arn
    }
    bucket_key_enabled = local.encryption_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "test_sets" {
  count                   = var.enable_test_studio ? 1 : 0
  bucket                  = aws_s3_bucket.test_sets[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# DynamoDB Table: test_sets
# =============================================================================

resource "aws_dynamodb_table" "test_sets" {
  count        = var.enable_test_studio ? 1 : 0
  name         = "${local.api_name}-test-sets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "testSetId"

  attribute {
    name = "testSetId"
    type = "S"
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
# IAM Role: test_studio_lambdas (shared by all Test Studio Lambdas)
# =============================================================================

resource "aws_iam_role" "test_studio_lambdas" {
  count = var.enable_test_studio ? 1 : 0
  name  = "${local.api_name}-test-studio-lambdas"

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

resource "aws_iam_role_policy" "test_studio_lambdas" {
  count = var.enable_test_studio ? 1 : 0
  name  = "test-studio-lambdas-policy"
  role  = aws_iam_role.test_studio_lambdas[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:PutItem",
          "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.test_sets[0].arn,
          "${aws_dynamodb_table.test_sets[0].arn}/index/*",
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = compact([
          aws_s3_bucket.test_sets[0].arn,
          "${aws_s3_bucket.test_sets[0].arn}/*",
          local.input_bucket_arn,
          "${local.input_bucket_arn}/*",
          local.output_bucket_arn,
          "${local.output_bucket_arn}/*",
          # Ground truth is read from here when a test set is built from the
          # input bucket, and each run's baselines are staged back into it.
          var.evaluation_baseline_bucket_arn,
          var.evaluation_baseline_bucket_arn != null ? "${var.evaluation_baseline_bucket_arn}/*" : null
        ])
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution", "states:DescribeExecution"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = [
          aws_sqs_queue.test_set_copy_queue[0].arn,
          aws_sqs_queue.test_file_copy_queue[0].arn,
          aws_sqs_queue.test_result_cache_update_queue[0].arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/00000000-0000-0000-0000-000000000000"
      }
      ],
      # test_runner._capture_config reads CONFIG_TABLE; read-only and separate
      # from the CRUD statement above.
      local.configuration_table_arn != null ? [
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
          Resource = [local.configuration_table_arn, "${local.configuration_table_arn}/index/*"]
        }
      ] : [],
      # test_results_resolver invokes the aggregation function for accuracy.
      var.evaluation_enabled ? [
        {
          Effect   = "Allow"
          Action   = ["lambda:InvokeFunction"]
          Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${local.api_name}-test-execution-aggregation"
        }
      ] : [],
      # Supplementary Athena query for split-classification metrics, confidence
      # and cost. s3:GetBucketLocation is required by Athena itself, not by any
      # call the resolver makes directly.
      var.agent_analytics.reporting_database_name != null ? [
        {
          Effect = "Allow"
          Action = [
            "athena:StartQueryExecution",
            "athena:GetQueryExecution",
            "athena:GetQueryResults",
            "athena:StopQueryExecution"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:athena:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workgroup/primary",
            "arn:${data.aws_partition.current.partition}:athena:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:datacatalog/*"
          ]
        },
        {
          Effect = "Allow"
          Action = ["glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables", "glue:GetPartitions"]
          Resource = [
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:database/${var.agent_analytics.reporting_database_name}",
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.agent_analytics.reporting_database_name}/*"
          ]
        }
      ] : [],
      var.agent_analytics.reporting_bucket_arn != null ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            var.agent_analytics.reporting_bucket_arn,
            "${var.agent_analytics.reporting_bucket_arn}/*"
          ]
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "test_studio_xray" {
  count      = var.enable_test_studio ? 1 : 0
  role       = aws_iam_role.test_studio_lambdas[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# SQS Queues for Test Studio async operations
# =============================================================================

resource "aws_sqs_queue" "test_set_copy_dlq" {
  count                     = var.enable_test_studio ? 1 : 0
  name                      = "${local.api_name}-test-set-copy-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.encryption_key_arn
  tags                      = var.tags
}

resource "aws_sqs_queue" "test_set_copy_queue" {
  count                      = var.enable_test_studio ? 1 : 0
  name                       = "${local.api_name}-test-set-copy-queue"
  visibility_timeout_seconds = 900
  kms_master_key_id          = local.encryption_key_arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.test_set_copy_dlq[0].arn
    maxReceiveCount     = 3
  })
  tags = var.tags
}

resource "aws_sqs_queue" "test_file_copy_dlq" {
  count                     = var.enable_test_studio ? 1 : 0
  name                      = "${local.api_name}-test-file-copy-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.encryption_key_arn
  tags                      = var.tags
}

resource "aws_sqs_queue" "test_file_copy_queue" {
  count                      = var.enable_test_studio ? 1 : 0
  name                       = "${local.api_name}-test-file-copy-queue"
  visibility_timeout_seconds = 900
  kms_master_key_id          = local.encryption_key_arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.test_file_copy_dlq[0].arn
    maxReceiveCount     = 3
  })
  tags = var.tags
}

resource "aws_sqs_queue" "test_result_cache_update_dlq" {
  count                     = var.enable_test_studio ? 1 : 0
  name                      = "${local.api_name}-test-result-cache-update-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.encryption_key_arn
  tags                      = var.tags
}

# getTestRun serves metrics from the cached testRunResult on the tracking item
# and, when that is missing, enqueues an aggregation here. The consumer is
# test_results_resolver itself (handle_cache_update_request). Without the queue
# the resolver logs "cannot queue cache update" and answers with no metrics,
# which the UI renders as "No Accuracy Data" even when the aggregation function
# can compute them.
resource "aws_sqs_queue" "test_result_cache_update_queue" {
  count                      = var.enable_test_studio ? 1 : 0
  name                       = "${local.api_name}-test-result-cache-update-queue"
  visibility_timeout_seconds = 900
  kms_master_key_id          = local.encryption_key_arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.test_result_cache_update_dlq[0].arn
    maxReceiveCount     = 3
  })
  tags = var.tags
}

# SQS event source mappings for file copier Lambdas
resource "aws_lambda_event_source_mapping" "test_set_copy" {
  count            = var.enable_test_studio ? 1 : 0
  event_source_arn = aws_sqs_queue.test_set_copy_queue[0].arn
  function_name    = aws_lambda_function.test_set_file_copier[0].arn
  batch_size       = 1
}

resource "aws_lambda_event_source_mapping" "test_result_cache_update" {
  count            = var.enable_test_studio ? 1 : 0
  event_source_arn = aws_sqs_queue.test_result_cache_update_queue[0].arn
  function_name    = aws_lambda_function.test_results_resolver[0].arn
  batch_size       = 1
}

resource "aws_lambda_event_source_mapping" "test_file_copy" {
  count            = var.enable_test_studio ? 1 : 0
  event_source_arn = aws_sqs_queue.test_file_copy_queue[0].arn
  function_name    = aws_lambda_function.test_file_copier[0].arn
  batch_size       = 1
}

# =============================================================================
# Helper: local for common test studio Lambda config
# =============================================================================

locals {
  test_studio_env_base = var.enable_test_studio ? {
    LOG_LEVEL       = var.log_level
    TEST_SET_BUCKET = aws_s3_bucket.test_sets[0].id
    # The evaluation baseline bucket, not the test-set bucket. The copiers use
    # this to find ground truth for input-bucket test sets and to stage each
    # run's baselines under {test_run_id}/, and the evaluation function only
    # reads the evaluation baseline bucket. Pointing it at the test-set bucket
    # made every input-bucket file look like it had no baseline and left run
    # baselines somewhere evaluation never looks. Matches upstream, which wires
    # EvaluationBaselineBucketName here.
    BASELINE_BUCKET                    = local.evaluation_baseline_bucket_name != null ? local.evaluation_baseline_bucket_name : ""
    INPUT_BUCKET                       = local.input_bucket_name
    OUTPUT_BUCKET                      = local.output_bucket_name
    TRACKING_TABLE                     = local.tracking_table_name
    CONFIG_TABLE                       = local.configuration_table_name
    TEST_SET_COPY_QUEUE_URL            = aws_sqs_queue.test_set_copy_queue[0].url
    FILE_COPY_QUEUE_URL                = aws_sqs_queue.test_file_copy_queue[0].url
    TEST_RESULT_CACHE_UPDATE_QUEUE_URL = aws_sqs_queue.test_result_cache_update_queue[0].url
  } : {}

  # Left absent rather than empty when evaluation is off: the resolver routes on
  # any value being present and only falls back when the variable is unset.
  test_studio_env = merge(
    local.test_studio_env_base,
    length(aws_lambda_function.test_execution_aggregation) > 0 ? {
      TEST_EXECUTION_AGGREGATION_FUNCTION_ARN = aws_lambda_function.test_execution_aggregation[0].arn
    } : {},
    local.test_studio_athena_env
  )

  # Athena only supplements the aggregation figures with split-classification
  # metrics, confidence and cost, and the resolver skips that query when
  # ATHENA_DATABASE is unset, so both vars are published together or not at all.
  test_studio_reporting_bucket_name = try(element(split(":", var.agent_analytics.reporting_bucket_arn), 5), null)

  test_studio_athena_env = (
    var.enable_test_studio &&
    var.agent_analytics.reporting_database_name != null &&
    local.test_studio_reporting_bucket_name != null
    ) ? {
    ATHENA_DATABASE        = var.agent_analytics.reporting_database_name
    ATHENA_OUTPUT_LOCATION = "s3://${local.test_studio_reporting_bucket_name}/athena-results/"
  } : {}
}

# =============================================================================
# Lambda: test_runner
# =============================================================================

resource "aws_cloudwatch_log_group" "test_runner" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-runner"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_runner" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/test_runner"
  output_path = "${path.module}/../../.terraform/archives/test_runner.zip"
}

resource "aws_lambda_function" "test_runner" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-runner"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_runner[0].output_path
  source_code_hash = data.archive_file.test_runner[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.test_runner]
  tags       = var.tags
}

# =============================================================================
# Lambda: test_results_resolver
# =============================================================================

resource "aws_cloudwatch_log_group" "test_results_resolver" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-results-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_results_resolver" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/test_results_resolver"
  output_path = "${path.module}/../../.terraform/archives/test_results_resolver.zip"
}

resource "aws_lambda_function" "test_results_resolver" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-results-resolver"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_results_resolver[0].output_path
  source_code_hash = data.archive_file.test_results_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.test_results_resolver]
  tags       = var.tags
}

# =============================================================================
# Lambda: test_set_resolver
# =============================================================================

resource "aws_cloudwatch_log_group" "test_set_resolver" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-set-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_set_resolver" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/test_set_resolver"
  output_path = "${path.module}/../../.terraform/archives/test_set_resolver.zip"
}

resource "aws_lambda_function" "test_set_resolver" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-set-resolver"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_set_resolver[0].output_path
  source_code_hash = data.archive_file.test_set_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  # Presigner: honor S3_ENDPOINT_URL for VPCE-targeted presigned URLs.
  environment { variables = merge(local.test_studio_env, local.s3_endpoint_url_env) }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.test_set_resolver]
  tags       = var.tags
}

# =============================================================================
# Lambda: test_set_zip_extractor
# =============================================================================

resource "aws_cloudwatch_log_group" "test_set_zip_extractor" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-set-zip-extractor"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_set_zip_extractor" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/test_set_zip_extractor"
  output_path = "${path.module}/../../.terraform/archives/test_set_zip_extractor.zip"
}

resource "aws_lambda_function" "test_set_zip_extractor" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-set-zip-extractor"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_set_zip_extractor[0].output_path
  source_code_hash = data.archive_file.test_set_zip_extractor[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 1024
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.test_set_zip_extractor]
  tags       = var.tags
}

# =============================================================================
# Lambda: test_file_copier
# =============================================================================

resource "aws_cloudwatch_log_group" "test_file_copier" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-file-copier"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_file_copier" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/test_file_copier"
  output_path = "${path.module}/../../.terraform/archives/test_file_copier.zip"
}

resource "aws_lambda_function" "test_file_copier" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-file-copier"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_file_copier[0].output_path
  source_code_hash = data.archive_file.test_file_copier[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.test_file_copier]
  tags       = var.tags
}

# =============================================================================
# Lambda: test_set_file_copier
# =============================================================================

resource "aws_cloudwatch_log_group" "test_set_file_copier" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-set-file-copier"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_set_file_copier" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/test_set_file_copier"
  output_path = "${path.module}/../../.terraform/archives/test_set_file_copier.zip"
}

resource "aws_lambda_function" "test_set_file_copier" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-set-file-copier"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_set_file_copier[0].output_path
  source_code_hash = data.archive_file.test_set_file_copier[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.test_set_file_copier]
  tags       = var.tags
}

# =============================================================================
# Lambda: delete_tests
# =============================================================================

resource "aws_cloudwatch_log_group" "delete_tests" {
  count             = var.enable_test_studio ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-delete-tests"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "delete_tests" {
  count       = var.enable_test_studio ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/delete_tests"
  output_path = "${path.module}/../../.terraform/archives/delete_tests.zip"
}

resource "aws_lambda_function" "delete_tests" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-delete-tests"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.delete_tests[0].output_path
  source_code_hash = data.archive_file.delete_tests[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.delete_tests]
  tags       = var.tags
}

# =============================================================================
# Lambda: fcc_dataset_deployer (conditional on enable_fcc_dataset)
# =============================================================================

resource "aws_cloudwatch_log_group" "fcc_dataset_deployer" {
  count             = var.enable_test_studio && var.enable_fcc_dataset ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-fcc-dataset-deployer"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "fcc_dataset_deployer" {
  count       = var.enable_test_studio && var.enable_fcc_dataset ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/fcc_dataset_deployer"
  output_path = "${path.module}/../../.terraform/archives/fcc_dataset_deployer.zip"
}

resource "aws_lambda_function" "fcc_dataset_deployer" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio && var.enable_fcc_dataset ? 1 : 0
  function_name    = "${local.api_name}-fcc-dataset-deployer"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.fcc_dataset_deployer[0].output_path
  source_code_hash = data.archive_file.fcc_dataset_deployer[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  # Deployer issues S3 calls; honor S3_ENDPOINT_URL in private VPC mode.
  environment { variables = merge(local.test_studio_env, local.s3_endpoint_url_env) }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.fcc_dataset_deployer]
  tags       = var.tags
}

# =============================================================================
# Lambda: w2_dataset_deployer (conditional on enable_w2_dataset)
#
# Mirrors fcc_dataset_deployer: a CloudFormation custom resource
# (Custom::W2DatasetDeployer, cfnresponse), not an AppSync resolver, so it gets
# no AppSync data source/resolver and no invoke-policy entry. Reuses the shared
# Test Studio role and local.test_studio_env. Memory (3008) / timeout (900) /
# ephemeral storage (10240) match the upstream W2DatasetDeployerFunction in
# sources/template.yaml — it stages parquet splits and ~2000 images into /tmp.
# =============================================================================

resource "aws_cloudwatch_log_group" "w2_dataset_deployer" {
  count             = var.enable_test_studio && var.enable_w2_dataset ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-w2-dataset-deployer"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "w2_dataset_deployer" {
  count       = var.enable_test_studio && var.enable_w2_dataset ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/w2_dataset_deployer"
  output_path = "${path.module}/../../.terraform/archives/w2_dataset_deployer.zip"
}

resource "aws_lambda_function" "w2_dataset_deployer" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio && var.enable_w2_dataset ? 1 : 0
  function_name    = "${local.api_name}-w2-dataset-deployer"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.w2_dataset_deployer[0].output_path
  source_code_hash = data.archive_file.w2_dataset_deployer[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 3008
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  ephemeral_storage { size = 10240 }
  environment { variables = local.test_studio_env }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.w2_dataset_deployer]
  tags       = var.tags
}

# =============================================================================
# NOTE: The Test Studio AppSync invoke policy, data sources, and resolvers were
# removed in the v0.6.4 REST migration. Test Studio fields (startTestRun,
# getTestRun/getTestRuns/getTestRunStatus/compareTestRuns, getTestSets,
# updateTestSet, validateTestFileName, listBucketFiles, addTestSet,
# addTestSetFromUpload, deleteTests, deleteTestSets, ...) are now routed to the
# same Test Studio Lambdas by the dispatcher via canonical keys + FIELD_ALIASES
# (see dispatcher.tf: startTestRun/compareTestRuns/addDocumentsToTestSet/
# deleteTests). The dispatcher role grants the invokes. Lambdas/queues/buckets
# above are unchanged.
# =============================================================================

# =============================================================================
# Lambda: test_execution_aggregation
#
# Produces the accuracy/precision/recall figures the Test Execution view shows.
# test_results_resolver treats this as the primary source and only supplements
# it from Athena, so without it the view reports "No Accuracy Data".
#
# Upstream builds this in the pattern stack and passes its ARN into the API
# stack. Here the API module is created before the processors, so taking it from
# a processor output would be a dependency cycle; it is built alongside the
# other Test Studio Lambdas instead and reuses their role, which already grants
# the tracking-table reads and output-bucket reads it needs.
#
# It carries exactly one layer: the code needs idp_common[evaluation] and the
# combined base + idp_common layers push the function past the unzipped size
# limit. The count keys off var.evaluation_enabled rather than the layer ARN so
# the gate stays known at plan time.
# =============================================================================

resource "aws_cloudwatch_log_group" "test_execution_aggregation" {
  count             = var.enable_test_studio && var.evaluation_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-test-execution-aggregation"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "test_execution_aggregation" {
  count       = var.enable_test_studio && var.evaluation_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/patterns/unified/src/test_execution_aggregation_function"
  output_path = "${path.module}/../../.terraform/archives/test_execution_aggregation.zip"
}

resource "aws_lambda_function" "test_execution_aggregation" {
  architectures    = [var.lambda_architecture]
  count            = var.enable_test_studio && var.evaluation_enabled ? 1 : 0
  function_name    = "${local.api_name}-test-execution-aggregation"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_execution_aggregation[0].output_path
  source_code_hash = data.archive_file.test_execution_aggregation[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 2048
  layers           = compact([var.evaluation_layer_arn])

  # Deliberately not local.test_studio_env: that map carries this function's own
  # ARN for the resolvers, which would be a self-reference.
  environment {
    variables = {
      LOG_LEVEL      = var.log_level
      TRACKING_TABLE = local.tracking_table_name != null ? local.tracking_table_name : ""
      OUTPUT_BUCKET  = local.output_bucket_name
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

  depends_on = [aws_cloudwatch_log_group.test_execution_aggregation]
  tags       = var.tags
}

# =============================================================================
# Dataset deployments
#
# Both deployers are CloudFormation custom resources upstream: they read
# RequestType and ResourceProperties and answer through cfnresponse, so a plain
# lambda invocation cannot drive them (there would be no ResponseURL to reply
# to). The functions were being created but nothing ever ran them, so neither
# labelled corpus was deployed. Wrapping each in a one-resource stack mirrors
# how mcp-integration drives its own custom resource and keeps CFN's
# create/update/delete idempotency.
#
# DatasetVersion is the deployer's idempotency key: it skips work when that
# version is already present, so bumping it is how a redeploy is forced.
# Versions, names and descriptions match sources/template.yaml.
# =============================================================================

resource "aws_cloudformation_stack" "w2_dataset" {
  count = var.enable_test_studio && var.enable_w2_dataset ? 1 : 0
  name  = "${local.api_name}-w2-dataset"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Fake W-2 tax form dataset for Test Studio"
    Resources = {
      W2DatasetDeployment = {
        Type = "Custom::W2DatasetDeployer"
        Properties = {
          ServiceToken       = aws_lambda_function.w2_dataset_deployer[0].arn
          DatasetVersion     = "1.0"
          DatasetName        = "Fake-W2-Tax-Forms"
          DatasetDescription = "Test set with 2,000 synthetic US W-2 tax form images and 45-field structured ground truth for extraction evaluation. Source: HuggingFace singhsays/fake-w2-us-tax-form-dataset (CC0: Public Domain)."
          # Re-runs the deployer when its code changes, as upstream does.
          SourceCodeHash = data.archive_file.w2_dataset_deployer[0].output_base64sha256
        }
      }
    }
  })

  tags = var.tags

  depends_on = [
    aws_lambda_function.w2_dataset_deployer,
    aws_cloudwatch_log_group.w2_dataset_deployer,
    aws_s3_bucket.test_sets,
  ]
}

resource "aws_cloudformation_stack" "fcc_dataset" {
  count = var.enable_test_studio && var.enable_fcc_dataset ? 1 : 0
  name  = "${local.api_name}-fcc-dataset"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "RealKIE-FCC-Verified dataset for Test Studio"
    Resources = {
      FccDatasetDeployment = {
        Type = "Custom::FccDatasetDeployer"
        Properties = {
          ServiceToken       = aws_lambda_function.fcc_dataset_deployer[0].arn
          DatasetVersion     = "1.1"
          DatasetName        = "RealKIE-FCC-Verified"
          DatasetDescription = "Test set with single and multi-page invoices sourced from the Federal Communications Commission (FCC) to evaluate extraction performance."
          SourceCodeHash     = data.archive_file.fcc_dataset_deployer[0].output_base64sha256
        }
      }
    }
  })

  tags = var.tags

  depends_on = [
    aws_lambda_function.fcc_dataset_deployer,
    aws_cloudwatch_log_group.fcc_dataset_deployer,
    aws_s3_bucket.test_sets,
  ]
}
