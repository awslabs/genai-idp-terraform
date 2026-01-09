# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lambda Functions for Processing Environment API
# This file contains all Lambda functions and their associated resources for GraphQL resolvers

# =============================================================================
# SHARED RESOURCES FOR ALL LAMBDA FUNCTIONS
# =============================================================================

# Registry-compatible build directory approach
locals {
  # Module-specific build directory that works both locally and in registry
  module_build_dir = "${path.module}/.terraform-build"
  # Unique identifier for this module instance
  module_instance_id = substr(md5("${path.module}-lambda-resolvers"), 0, 8)
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Generate unique build ID for this module instance
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    # Include module instance ID for uniqueness
    module_instance_id = local.module_instance_id
    # Trigger rebuild when content changes
    content_hash = md5("lambda-resolver-functions")
  }
}

# =============================================================================
# DOCUMENT MANAGEMENT FUNCTIONS
# =============================================================================

# Upload Document Resolver Lambda
data "archive_file" "upload_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/upload_resolver"
  output_path = "${local.module_build_dir}/upload-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "upload_resolver" {
  function_name = "UploadDocumentResolver-${random_string.suffix.result}"

  filename         = data.archive_file.upload_resolver_code.output_path
  source_code_hash = data.archive_file.upload_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.upload_resolver_role.arn
  description = "Lambda function to return signed upload URL via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      INPUT_BUCKET               = local.input_bucket_name
      OUTPUT_BUCKET              = local.output_bucket_name
      EVALUATION_BASELINE_BUCKET = local.evaluation_baseline_bucket_name != null ? local.evaluation_baseline_bucket_name : ""
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# Delete Document Resolver Lambda
data "archive_file" "delete_document_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/delete_document_resolver"
  output_path = "${local.module_build_dir}/delete-document-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "delete_document_resolver" {
  function_name = "DeleteDocumentResolver-${random_string.suffix.result}"

  filename         = data.archive_file.delete_document_resolver_code.output_path
  source_code_hash = data.archive_file.delete_document_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.delete_document_resolver_role.arn
  description = "Lambda function to delete documents via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE_NAME = local.tracking_table_name
      INPUT_BUCKET        = local.input_bucket_name
      OUTPUT_BUCKET       = local.output_bucket_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# Reprocess Document Resolver Lambda
data "archive_file" "reprocess_document_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/reprocess_document_resolver"
  output_path = "${local.module_build_dir}/reprocess-document-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "reprocess_document_resolver" {
  function_name = "ReprocessDocumentResolver-${random_string.suffix.result}"

  filename         = data.archive_file.reprocess_document_resolver_code.output_path
  source_code_hash = data.archive_file.reprocess_document_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.reprocess_document_resolver_role.arn
  description = "Lambda function to reprocess documents via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      INPUT_BUCKET = local.input_bucket_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.reprocess_document_resolver_logs_attachment,
    aws_iam_role_policy_attachment.reprocess_document_resolver_s3_attachment,
    aws_iam_role_policy_attachment.reprocess_document_resolver_kms_attachment,
    aws_iam_role_policy_attachment.reprocess_document_resolver_vpc_attachment
  ]
}

# =============================================================================
# DATA RETRIEVAL FUNCTIONS
# =============================================================================

# Get File Contents Resolver Lambda
data "archive_file" "get_file_contents_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/get_file_contents_resolver"
  output_path = "${local.module_build_dir}/get-file-contents-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "get_file_contents_resolver" {
  function_name = "GetFileContentsResolver-${random_string.suffix.result}"

  filename         = data.archive_file.get_file_contents_resolver_code.output_path
  source_code_hash = data.archive_file.get_file_contents_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.get_file_contents_resolver_role.arn
  description = "Lambda function to retrieve file contents via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      OUTPUT_BUCKET = local.output_bucket_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# Configuration Resolver Lambda
data "archive_file" "configuration_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/configuration_resolver"
  output_path = "${local.module_build_dir}/configuration_resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "configuration_resolver" {
  function_name = "ConfigurationResolver-${random_string.suffix.result}"

  filename         = data.archive_file.configuration_resolver_code.output_path
  source_code_hash = data.archive_file.configuration_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.configuration_resolver_role.arn
  description = "Lambda function to manage configuration through GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# =============================================================================
# STEP FUNCTION INTEGRATION FUNCTIONS
# =============================================================================

# Get Step Function Execution Resolver Lambda
data "archive_file" "get_stepfunction_execution_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/get_stepfunction_execution_resolver"
  output_path = "${local.module_build_dir}/get-stepfunction-execution-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "get_stepfunction_execution_resolver" {
  function_name = "GetStepFunctionExecutionResolver-${random_string.suffix.result}"

  filename         = data.archive_file.get_stepfunction_execution_resolver_code.output_path
  source_code_hash = data.archive_file.get_stepfunction_execution_resolver_code.output_base64sha256

  handler     = "index.lambda_handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.get_stepfunction_execution_resolver_role.arn
  description = "Lambda function to get Step Function execution status via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE_NAME = local.tracking_table_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_logs_attachment,
    aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_stepfunctions_attachment,
    aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_vpc_attachment
  ]
}

# =============================================================================
# KNOWLEDGE BASE FUNCTIONS
# =============================================================================

# Query Knowledge Base Resolver Lambda
data "archive_file" "query_knowledge_base_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/query_knowledgebase_resolver"
  output_path = "${local.module_build_dir}/query-knowledge-base-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "query_knowledge_base_resolver" {
  for_each      = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  function_name = "QueryKnowledgeBaseResolver-${random_string.suffix.result}"

  filename         = data.archive_file.query_knowledge_base_resolver_code.output_path
  source_code_hash = data.archive_file.query_knowledge_base_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 60
  memory_size = 512
  role        = aws_iam_role.query_knowledge_base_resolver_role["enabled"].arn
  description = "Lambda function to query Bedrock Knowledge Base via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      KB_ID                    = local.knowledge_base_id != null ? local.knowledge_base_id : ""
      KB_ACCOUNT_ID            = data.aws_caller_identity.current.account_id
      KB_REGION                = data.aws_region.current.id
      MODEL_ID                 = local.knowledge_base_model_id != null ? local.knowledge_base_model_id : ""
      LOG_LEVEL                = var.log_level
      GUARDRAIL_ID_AND_VERSION = var.knowledge_base.guardrail_id_and_version != null ? var.knowledge_base.guardrail_id_and_version : ""
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# =============================================================================
# BASELINE MANAGEMENT FUNCTIONS
# =============================================================================

# Copy to Baseline Resolver Lambda
data "archive_file" "copy_to_baseline_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/copy_to_baseline_resolver"
  output_path = "${local.module_build_dir}/copy-to-baseline-resolver.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "copy_to_baseline_resolver" {
  for_each      = var.evaluation_enabled ? { "enabled" = true } : {}
  function_name = "CopyToBaselineResolver-${random_string.suffix.result}"

  filename         = data.archive_file.copy_to_baseline_resolver_code.output_path
  source_code_hash = data.archive_file.copy_to_baseline_resolver_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.copy_to_baseline_resolver_role["enabled"].arn
  description = "Lambda function to copy documents to baseline via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      OUTPUT_BUCKET              = local.output_bucket_name
      EVALUATION_BASELINE_BUCKET = local.evaluation_baseline_bucket_name != null ? local.evaluation_baseline_bucket_name : ""
      TRACKING_TABLE_NAME        = local.tracking_table_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# =============================================================================
# APPSYNC DATASOURCES
# =============================================================================

# Upload Resolver Data Source
resource "aws_appsync_datasource" "upload_resolver" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "UploadResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.upload_resolver.arn
  }
}

# Delete Document Resolver Data Source
resource "aws_appsync_datasource" "delete_document_resolver" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "DeleteDocumentResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.delete_document_resolver.arn
  }
}

# Reprocess Document Resolver Data Source
resource "aws_appsync_datasource" "reprocess_document_resolver" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "ReprocessDocumentResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.reprocess_document_resolver.arn
  }
}

# Get File Contents Resolver Data Source
resource "aws_appsync_datasource" "get_file_contents_resolver" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "GetFileContentsResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.get_file_contents_resolver.arn
  }
}

# Configuration Resolver Data Source
resource "aws_appsync_datasource" "configuration" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "ConfigurationDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.configuration_resolver.arn
  }
}

# Get Step Function Execution Resolver Data Source
resource "aws_appsync_datasource" "get_stepfunction_execution_resolver" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "GetStepFunctionExecutionResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.get_stepfunction_execution_resolver.arn
  }
}

# Query Knowledge Base Resolver Data Source
resource "aws_appsync_datasource" "query_knowledge_base_resolver" {
  for_each         = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  api_id           = aws_appsync_graphql_api.api.id
  name             = "QueryKnowledgeBaseResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.query_knowledge_base_resolver["enabled"].arn
  }
}

# Copy to Baseline Resolver Data Source
resource "aws_appsync_datasource" "copy_to_baseline_resolver" {
  for_each         = var.evaluation_enabled ? { "enabled" = true } : {}
  api_id           = aws_appsync_graphql_api.api.id
  name             = "CopyToBaselineResolverDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.copy_to_baseline_resolver["enabled"].arn
  }
}

# =============================================================================
# APPSYNC RESOLVERS
# =============================================================================

# Upload Document Resolver
resource "aws_appsync_resolver" "upload_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "uploadDocument"
  data_source = aws_appsync_datasource.upload_resolver.name
}

# Delete Document Resolver
resource "aws_appsync_resolver" "delete_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteDocument"
  data_source = aws_appsync_datasource.delete_document_resolver.name
}

# Reprocess Document Resolver
resource "aws_appsync_resolver" "reprocess_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "reprocessDocument"
  data_source = aws_appsync_datasource.reprocess_document_resolver.name
}

# Get File Contents Resolver
resource "aws_appsync_resolver" "get_file_contents" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getFileContents"
  data_source = aws_appsync_datasource.get_file_contents_resolver.name
}

# Get Configuration Resolver
resource "aws_appsync_resolver" "get_configuration" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getConfiguration"
  data_source = aws_appsync_datasource.configuration.name
}

# Update Configuration Resolver
resource "aws_appsync_resolver" "update_configuration" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "updateConfiguration"
  data_source = aws_appsync_datasource.configuration.name
}

# Get Step Function Execution Resolver
resource "aws_appsync_resolver" "get_stepfunction_execution" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getStepFunctionExecution"
  data_source = aws_appsync_datasource.get_stepfunction_execution_resolver.name
}

# Query Knowledge Base Resolver
resource "aws_appsync_resolver" "query_knowledge_base" {
  for_each    = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "queryKnowledgeBase"
  data_source = aws_appsync_datasource.query_knowledge_base_resolver["enabled"].name
}

# Copy to Baseline Resolver
resource "aws_appsync_resolver" "copy_to_baseline" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "copyToBaseline"
  data_source = aws_appsync_datasource.copy_to_baseline_resolver["enabled"].name
}
