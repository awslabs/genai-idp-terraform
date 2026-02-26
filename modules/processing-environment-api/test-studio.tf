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
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
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
        Resource = [
          aws_s3_bucket.test_sets[0].arn,
          "${aws_s3_bucket.test_sets[0].arn}/*",
          local.input_bucket_arn,
          "${local.input_bucket_arn}/*",
          local.output_bucket_arn,
          "${local.output_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution", "states:DescribeExecution"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "test_studio_xray" {
  count      = var.enable_test_studio ? 1 : 0
  role       = aws_iam_role.test_studio_lambdas[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Helper: local for common test studio Lambda config
# =============================================================================

locals {
  test_studio_env = var.enable_test_studio ? {
    LOG_LEVEL        = var.log_level
    TEST_SETS_TABLE  = aws_dynamodb_table.test_sets[0].name
    TEST_SETS_BUCKET = aws_s3_bucket.test_sets[0].id
    INPUT_BUCKET     = local.input_bucket_name
    OUTPUT_BUCKET    = local.output_bucket_name
    TRACKING_TABLE   = local.tracking_table_name
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
  source_dir  = "${path.module}/../../sources/src/lambda/test_runner"
  output_path = "${path.module}/../../.terraform/archives/test_runner.zip"
}

resource "aws_lambda_function" "test_runner" {
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-runner"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_runner[0].output_path
  source_code_hash = data.archive_file.test_runner[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  layers           = compact([var.idp_common_layer_arn])
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
  source_dir  = "${path.module}/../../sources/src/lambda/test_results_resolver"
  output_path = "${path.module}/../../.terraform/archives/test_results_resolver.zip"
}

resource "aws_lambda_function" "test_results_resolver" {
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-results-resolver"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_results_resolver[0].output_path
  source_code_hash = data.archive_file.test_results_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])
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
  source_dir  = "${path.module}/../../sources/src/lambda/test_set_resolver"
  output_path = "${path.module}/../../.terraform/archives/test_set_resolver.zip"
}

resource "aws_lambda_function" "test_set_resolver" {
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-set-resolver"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_set_resolver[0].output_path
  source_code_hash = data.archive_file.test_set_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
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
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-set-zip-extractor"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_set_zip_extractor[0].output_path
  source_code_hash = data.archive_file.test_set_zip_extractor[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 1024
  layers           = compact([var.idp_common_layer_arn])
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
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-file-copier"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_file_copier[0].output_path
  source_code_hash = data.archive_file.test_file_copier[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  layers           = compact([var.idp_common_layer_arn])
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
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-test-set-file-copier"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.test_set_file_copier[0].output_path
  source_code_hash = data.archive_file.test_set_file_copier[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  layers           = compact([var.idp_common_layer_arn])
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
  source_dir  = "${path.module}/../../sources/src/lambda/delete_tests"
  output_path = "${path.module}/../../.terraform/archives/delete_tests.zip"
}

resource "aws_lambda_function" "delete_tests" {
  count            = var.enable_test_studio ? 1 : 0
  function_name    = "${local.api_name}-delete-tests"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.delete_tests[0].output_path
  source_code_hash = data.archive_file.delete_tests[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  layers           = compact([var.idp_common_layer_arn])
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
  count            = var.enable_test_studio && var.enable_fcc_dataset ? 1 : 0
  function_name    = "${local.api_name}-fcc-dataset-deployer"
  role             = aws_iam_role.test_studio_lambdas[0].arn
  filename         = data.archive_file.fcc_dataset_deployer[0].output_path
  source_code_hash = data.archive_file.fcc_dataset_deployer[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  layers           = compact([var.idp_common_layer_arn])
  environment { variables = local.test_studio_env }
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
# AppSync data sources and resolvers for Test Studio
# =============================================================================

resource "aws_appsync_datasource" "test_runner" {
  count            = var.enable_test_studio ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "TestRunnerDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.test_runner[0].arn }
}

resource "aws_appsync_datasource" "test_results_resolver" {
  count            = var.enable_test_studio ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "TestResultsResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.test_results_resolver[0].arn }
}

resource "aws_appsync_datasource" "test_set_resolver" {
  count            = var.enable_test_studio ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "TestSetResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.test_set_resolver[0].arn }
}

resource "aws_appsync_datasource" "test_set_zip_extractor" {
  count            = var.enable_test_studio ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "TestSetZipExtractorDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.test_set_zip_extractor[0].arn }
}

resource "aws_appsync_datasource" "delete_tests" {
  count            = var.enable_test_studio ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "DeleteTestsDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.delete_tests[0].arn }
}

resource "aws_appsync_datasource" "test_set_file_copier" {
  count            = var.enable_test_studio ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "TestSetFileCopierDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.test_set_file_copier[0].arn }
}

resource "aws_appsync_resolver" "run_test" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "startTestRun"
  data_source = aws_appsync_datasource.test_runner[0].name
}

resource "aws_appsync_resolver" "get_test_run" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getTestRun"
  data_source = aws_appsync_datasource.test_results_resolver[0].name
}

resource "aws_appsync_resolver" "get_test_results" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getTestRuns"
  data_source = aws_appsync_datasource.test_results_resolver[0].name
}

resource "aws_appsync_resolver" "get_test_run_status" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getTestRunStatus"
  data_source = aws_appsync_datasource.test_results_resolver[0].name
}

resource "aws_appsync_resolver" "compare_test_runs" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "compareTestRuns"
  data_source = aws_appsync_datasource.test_results_resolver[0].name
}

resource "aws_appsync_resolver" "list_test_sets" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getTestSets"
  data_source = aws_appsync_datasource.test_set_resolver[0].name
}

resource "aws_appsync_resolver" "validate_test_file_name" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "validateTestFileName"
  data_source = aws_appsync_datasource.test_set_resolver[0].name
}

resource "aws_appsync_resolver" "list_bucket_files" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listBucketFiles"
  data_source = aws_appsync_datasource.test_set_file_copier[0].name
}

resource "aws_appsync_resolver" "upload_test_set" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "addTestSetFromUpload"
  data_source = aws_appsync_datasource.test_set_zip_extractor[0].name
}

resource "aws_appsync_resolver" "add_test_set" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "addTestSet"
  data_source = aws_appsync_datasource.test_set_resolver[0].name
}

resource "aws_appsync_resolver" "delete_tests" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteTests"
  data_source = aws_appsync_datasource.delete_tests[0].name
}

resource "aws_appsync_resolver" "delete_test_set" {
  count       = var.enable_test_studio ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteTestSets"
  data_source = aws_appsync_datasource.delete_tests[0].name
}
