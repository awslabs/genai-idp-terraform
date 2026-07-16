# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Discovery Sub-module for Processing Environment API
# This module creates the Lambda functions, DynamoDB table, and GraphQL resolvers for document discovery functionality

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Generate unique suffix for resource names
  suffix = random_string.suffix.result

  # Extract bucket names from ARNs
  input_bucket_name = element(split(":", var.input_bucket_arn), 5)

  # Module build directory for Lambda archives
  module_build_dir = "${path.module}/.terraform-build"
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# =============================================================================
# Discovery S3 Bucket
# =============================================================================

resource "aws_s3_bucket" "discovery_bucket" {
  bucket = "${var.name_prefix}-discovery-${local.suffix}"

  tags = var.tags
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "discovery_bucket_versioning" {
  bucket = aws_s3_bucket.discovery_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption (conditional)
resource "aws_s3_bucket_server_side_encryption_configuration" "discovery_bucket_encryption" {
  bucket = aws_s3_bucket.discovery_bucket.id

  dynamic "rule" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.encryption_key_arn
        sse_algorithm     = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "discovery_bucket_pab" {
  bucket = aws_s3_bucket.discovery_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy to enforce SSL
resource "aws_s3_bucket_policy" "discovery_bucket_policy" {
  bucket = aws_s3_bucket.discovery_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.discovery_bucket.arn,
          "${aws_s3_bucket.discovery_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# CORS configuration for Web UI uploads
resource "aws_s3_bucket_cors_configuration" "discovery_bucket_cors" {
  bucket = aws_s3_bucket.discovery_bucket.id

  cors_rule {
    allowed_headers = [
      "Content-Type",
      "x-amz-content-sha256",
      "x-amz-date",
      "Authorization",
      "x-amz-security-token"
    ]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = [
      "*" # Will be restricted by bucket policy and IAM
    ]
    expose_headers = [
      "ETag",
      "x-amz-server-side-encryption"
    ]
    max_age_seconds = 3000
  }
}

# Lifecycle configuration for data retention
resource "aws_s3_bucket_lifecycle_configuration" "discovery_bucket_lifecycle" {
  bucket = aws_s3_bucket.discovery_bucket.id

  rule {
    id     = "DeleteAfterNDays"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.data_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# EventBridge notification configuration
resource "aws_s3_bucket_notification" "discovery_bucket_notification" {
  bucket      = aws_s3_bucket.discovery_bucket.id
  eventbridge = true
}

# =============================================================================
# DynamoDB Table for Discovery Job Tracking
# =============================================================================

resource "aws_dynamodb_table" "discovery_tracking" {
  name         = "${var.name_prefix}-discovery-tracking-${local.suffix}"
  billing_mode = "PAY_PER_REQUEST"
  # Single-attribute primary key on jobId, matching the discovery upload
  # resolver Lambda (index.py writes items keyed by jobId) and the reference
  # CFN template (sources/template.yaml DiscoveryTrackingTable). An earlier
  # PK/SK schema caused "Missing the key PK in the item" on PutItem.
  hash_key = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  dynamic "server_side_encryption" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = var.encryption_key_arn
    }
  }

  tags = var.tags
}

# =============================================================================
# SQS Queue for Discovery Processing
# =============================================================================

# Dead Letter Queue for failed discovery jobs
resource "aws_sqs_queue" "discovery_dlq" {
  name = "${var.name_prefix}-discovery-dlq-${local.suffix}"

  kms_master_key_id = var.encryption_key_arn

  tags = var.tags
}

# Main discovery processing queue
resource "aws_sqs_queue" "discovery_queue" {
  name                       = "${var.name_prefix}-discovery-queue-${local.suffix}"
  visibility_timeout_seconds = 960     # 16 minutes (longer than Lambda timeout)
  message_retention_seconds  = 1209600 # 14 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.discovery_dlq.arn
    maxReceiveCount     = 3
  })

  kms_master_key_id = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# Discovery Upload Resolver Lambda Function
# =============================================================================

# Generate unique build ID for upload resolver
resource "random_id" "upload_resolver_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("discovery-upload-resolver")
  }
}

# Source code archive for upload resolver
data "archive_file" "discovery_upload_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/nested/appsync/src/lambda/discovery_upload_resolver"
  output_path = "${local.module_build_dir}/discovery-upload-resolver.zip_${random_id.upload_resolver_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Discovery Upload Resolver Lambda function
resource "aws_lambda_function" "discovery_upload_resolver" {
  architectures = [var.lambda_architecture]
  function_name = "${var.name_prefix}-discovery-upload-${local.suffix}"

  filename         = data.archive_file.discovery_upload_resolver_code.output_path
  source_code_hash = data.archive_file.discovery_upload_resolver_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 60
  memory_size = 512
  role        = aws_iam_role.discovery_upload_resolver_role.arn
  description = "Handles discovery document upload requests and creates presigned URLs"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = merge({
      LOG_LEVEL                             = var.log_level
      DISCOVERY_TRACKING_TABLE              = aws_dynamodb_table.discovery_tracking.name
      DISCOVERY_QUEUE_URL                   = aws_sqs_queue.discovery_queue.url
      DISCOVERY_BUCKET                      = aws_s3_bucket.discovery_bucket.id
      MULTI_DOC_DISCOVERY_STATE_MACHINE_ARN = aws_sfn_state_machine.multi_doc_discovery.arn
    }, var.s3_endpoint_url != null ? { S3_ENDPOINT_URL = var.s3_endpoint_url } : {})
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

  tags = var.tags
}

# CloudWatch Log Group for upload resolver
resource "aws_cloudwatch_log_group" "discovery_upload_resolver_logs" {
  name              = "/aws/lambda/${aws_lambda_function.discovery_upload_resolver.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# Discovery Processor Lambda Function
# =============================================================================

# Generate unique build ID for processor
resource "random_id" "processor_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("discovery-processor")
  }
}

# Discovery processor source directory (raw Lambda code + requirements.txt)
locals {
  discovery_processor_src = "${path.module}/../../../sources/src/lambda/discovery_processor"
  # Staging directory where we assemble the source plus pip-installed
  # dependencies before zipping. The SAM-based reference build installs each
  # function's requirements.txt automatically; the archive_file approach does
  # not, so we stage explicitly here.
  discovery_processor_stage = "${local.module_build_dir}/discovery_processor_pkg"
}

# Stage processor source and install its requirements.txt (aws-requests-auth,
# used to SigV4-sign AppSync GraphQL status callbacks). Without this the
# function crashes at import with "No module named 'aws_requests_auth'".
resource "null_resource" "discovery_processor_build" {
  triggers = {
    # Rebuild when the handler or its requirements change.
    source_hash       = filesha256("${local.discovery_processor_src}/index.py")
    requirements_hash = filesha256("${local.discovery_processor_src}/requirements.txt")
  }

  provisioner "local-exec" {
    # Clean the staging dir, copy source, then pip-install requirements into it.
    # aws-requests-auth is pure Python (only needs requests, already in the
    # idp_common layer), so no platform-specific wheels are required.
    command = <<-EOT
      set -e
      rm -rf "${local.discovery_processor_stage}"
      mkdir -p "${local.discovery_processor_stage}"
      cp -r "${local.discovery_processor_src}/." "${local.discovery_processor_stage}/"
      python3 -m pip install \
        -r "${local.discovery_processor_src}/requirements.txt" \
        -t "${local.discovery_processor_stage}" \
        --no-cache-dir --upgrade
    EOT
  }

  depends_on = [null_resource.create_module_build_dir]
}

# Source code archive for processor (staged source + dependencies)
data "archive_file" "discovery_processor_code" {
  type        = "zip"
  source_dir  = local.discovery_processor_stage
  output_path = "${local.module_build_dir}/discovery-processor.zip_${random_id.processor_build_id.hex}"

  depends_on = [null_resource.discovery_processor_build]
}

# Discovery Processor Lambda function
resource "aws_lambda_function" "discovery_processor" {
  architectures = [var.lambda_architecture]
  function_name = "${var.name_prefix}-discovery-processor-${local.suffix}"

  filename         = data.archive_file.discovery_processor_code.output_path
  source_code_hash = data.archive_file.discovery_processor_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 900 # 15 minutes for complex discovery processing
  memory_size = 1024
  role        = aws_iam_role.discovery_processor_role.arn
  description = "Processes discovery jobs using ClassesDiscovery from idp_common"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      BEDROCK_LOG_LEVEL        = var.log_level
      DISCOVERY_TRACKING_TABLE = aws_dynamodb_table.discovery_tracking.name
      APPSYNC_API_URL          = var.appsync_api_url
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

  tags = var.tags
}

# CloudWatch Log Group for processor
resource "aws_cloudwatch_log_group" "discovery_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.discovery_processor.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# SQS Event Source Mapping for Discovery Processor
# =============================================================================

resource "aws_lambda_event_source_mapping" "discovery_processor_sqs" {
  event_source_arn = aws_sqs_queue.discovery_queue.arn
  function_name    = aws_lambda_function.discovery_processor.arn
  batch_size       = 1

  # Enable partial batch failure reporting
  function_response_types = ["ReportBatchItemFailures"]
}

# =============================================================================
# GraphQL Data Sources and Resolvers
# =============================================================================

# Discovery Lambda Data Source
resource "aws_appsync_datasource" "discovery_lambda" {
  api_id           = var.appsync_api_id
  name             = "DiscoveryLambda"
  description      = "Lambda function to handle discovery document uploads"
  type             = "AWS_LAMBDA"
  service_role_arn = var.appsync_lambda_role_arn

  lambda_config {
    function_arn = aws_lambda_function.discovery_upload_resolver.arn
  }
}

# Discovery Table DynamoDB Data Source
resource "aws_appsync_datasource" "discovery_table" {
  api_id           = var.appsync_api_id
  name             = "DiscoveryTable"
  description      = "DynamoDB table for discovery job tracking"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = var.appsync_dynamodb_role_arn

  dynamodb_config {
    table_name = aws_dynamodb_table.discovery_tracking.name
  }
}

# List Discovery Jobs Resolver (Query)
# Scan the jobId-keyed table and return items verbatim so all fields the UI
# reads (jobType, currentStep, totalDocuments, etc.) pass through. Matches the
# reference CFN DiscoveryJobsResolver.
resource "aws_appsync_resolver" "list_discovery_jobs" {
  api_id      = var.appsync_api_id
  type        = "Query"
  field       = "listDiscoveryJobs"
  data_source = aws_appsync_datasource.discovery_table.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Scan",
  "limit": 50,
  "consistentRead": false,
  "select": "ALL_ATTRIBUTES"
}
EOF

  response_template = <<EOF
{
  "DiscoveryJobs": $util.toJson($ctx.result.items),
  "nextToken": $util.toJson($ctx.result.nextToken)
}
EOF
}

# Update Discovery Job Status Resolver (Mutation)
# Keyed by jobId and supports the full multi-document discovery field set.
# Matches the reference CFN UpdateDiscoveryJobStatusResolver.
resource "aws_appsync_resolver" "update_discovery_job_status" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "updateDiscoveryJobStatus"
  data_source = aws_appsync_datasource.discovery_table.name

  request_template = <<EOF
## Validate status is one of the allowed values
#set($validStatuses = ["PENDING", "IN_PROGRESS", "COMPLETED", "FAILED", "OPTIMIZATION_IN_PROGRESS", "OPTIMIZATION_COMPLETED", "OPTIMIZATION_FAILED", "QUEUED", "PREPARING", "EMBEDDING", "CLUSTERING", "ANALYZING"])
#if(!$validStatuses.contains($ctx.args.status))
  $util.error("Invalid status value", "ValidationException")
#end

#set($expNames = {})
#set($expValues = {})

## Set status (required)
$util.qr($expNames.put("#status", "status"))
$util.qr($expValues.put(":status", $util.dynamodb.toDynamoDB($ctx.args.status)))
#set($updateExpression = "SET #status = :status")

## Set errorMessage (optional)
#if($ctx.args.errorMessage)
  $util.qr($expNames.put("#errorMessage", "errorMessage"))
  $util.qr($expValues.put(":errorMessage", $util.dynamodb.toDynamoDB($ctx.args.errorMessage)))
  #set($updateExpression = "$${updateExpression}, #errorMessage = :errorMessage")
#end

## Set discoveredClassName (optional)
#if($ctx.args.discoveredClassName)
  $util.qr($expNames.put("#discoveredClassName", "discoveredClassName"))
  $util.qr($expValues.put(":discoveredClassName", $util.dynamodb.toDynamoDB($ctx.args.discoveredClassName)))
  #set($updateExpression = "$${updateExpression}, #discoveredClassName = :discoveredClassName")
#end

## Set statusMessage (optional)
#if($ctx.args.statusMessage)
  $util.qr($expNames.put("#statusMessage", "statusMessage"))
  $util.qr($expValues.put(":statusMessage", $util.dynamodb.toDynamoDB($ctx.args.statusMessage)))
  #set($updateExpression = "$${updateExpression}, #statusMessage = :statusMessage")
#end

## Multi-document discovery fields (optional)
#if($ctx.args.jobType)
  $util.qr($expNames.put("#jobType", "jobType"))
  $util.qr($expValues.put(":jobType", $util.dynamodb.toDynamoDB($ctx.args.jobType)))
  #set($updateExpression = "$${updateExpression}, #jobType = :jobType")
#end

#if($ctx.args.currentStep)
  $util.qr($expNames.put("#currentStep", "currentStep"))
  $util.qr($expValues.put(":currentStep", $util.dynamodb.toDynamoDB($ctx.args.currentStep)))
  #set($updateExpression = "$${updateExpression}, #currentStep = :currentStep")
#end

#if($ctx.args.totalDocuments)
  $util.qr($expNames.put("#totalDocuments", "totalDocuments"))
  $util.qr($expValues.put(":totalDocuments", $util.dynamodb.toDynamoDB($ctx.args.totalDocuments)))
  #set($updateExpression = "$${updateExpression}, #totalDocuments = :totalDocuments")
#end

#if($ctx.args.clustersFound)
  $util.qr($expNames.put("#clustersFound", "clustersFound"))
  $util.qr($expValues.put(":clustersFound", $util.dynamodb.toDynamoDB($ctx.args.clustersFound)))
  #set($updateExpression = "$${updateExpression}, #clustersFound = :clustersFound")
#end

#if($ctx.args.discoveredClasses)
  $util.qr($expNames.put("#discoveredClasses", "discoveredClasses"))
  $util.qr($expValues.put(":discoveredClasses", $util.dynamodb.toDynamoDB($ctx.args.discoveredClasses)))
  #set($updateExpression = "$${updateExpression}, #discoveredClasses = :discoveredClasses")
#end

#if($ctx.args.reflectionReport)
  $util.qr($expNames.put("#reflectionReport", "reflectionReport"))
  $util.qr($expValues.put(":reflectionReport", $util.dynamodb.toDynamoDB($ctx.args.reflectionReport)))
  #set($updateExpression = "$${updateExpression}, #reflectionReport = :reflectionReport")
#end

## Set updatedAt to current timestamp
$util.qr($expNames.put("#updatedAt", "updatedAt"))
$util.qr($expValues.put(":updatedAt", $util.dynamodb.toDynamoDB($util.time.nowISO8601())))
#set($updateExpression = "$${updateExpression}, #updatedAt = :updatedAt")

## Set completedAt when status is a terminal state
#if($ctx.args.status == "COMPLETED" || $ctx.args.status == "FAILED" || $ctx.args.status == "OPTIMIZATION_COMPLETED" || $ctx.args.status == "OPTIMIZATION_FAILED")
  $util.qr($expNames.put("#completedAt", "completedAt"))
  $util.qr($expValues.put(":completedAt", $util.dynamodb.toDynamoDB($util.time.nowISO8601())))
  #set($updateExpression = "$${updateExpression}, #completedAt = :completedAt")
#end

{
  "version": "2018-05-29",
  "operation": "UpdateItem",
  "key": {
    "jobId": $util.dynamodb.toDynamoDBJson($ctx.args.jobId)
  },
  "update": {
    "expression": "$updateExpression",
    "expressionNames": $utils.toJson($expNames),
    "expressionValues": $utils.toJson($expValues)
  }
}
EOF

  response_template = <<EOF
$util.toJson($ctx.result)
EOF
}

# Delete Discovery Job Resolver (Mutation)
# The UI calls deleteDiscoveryJob when removing jobs. Keyed by jobId, matching
# the reference CFN DeleteDiscoveryJobResolver.
resource "aws_appsync_resolver" "delete_discovery_job" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "deleteDiscoveryJob"
  data_source = aws_appsync_datasource.discovery_table.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "DeleteItem",
  "key": {
    "jobId": $util.dynamodb.toDynamoDBJson($ctx.args.jobId)
  }
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#else
  true
#end
EOF
}

# =============================================================================
# Discovery Lambda Resolvers (Mutation)
#
# These four mutations are all served by the single discovery upload resolver
# Lambda (aws_appsync_datasource.discovery_lambda), which dispatches on
# event.info.fieldName. They use direct Lambda invocation (no VTL mapping
# templates), matching the reference CFN template
# (sources/nested/appsync/template.yaml).
#
# The AppSync service role's lambda:InvokeFunction permission on this Lambda is
# granted by the parent module (processing-environment-api/iam.tf), so no IAM
# changes are required here.
# =============================================================================

# Presigned URL + discovery job creation for single-document discovery uploads
resource "aws_appsync_resolver" "upload_discovery_document" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "uploadDiscoveryDocument"
  data_source = aws_appsync_datasource.discovery_lambda.name
}

# LLM-based section boundary auto-detection for discovery documents
resource "aws_appsync_resolver" "auto_detect_sections" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "autoDetectSections"
  data_source = aws_appsync_datasource.discovery_lambda.name
}

# Start the multi-document discovery Step Functions pipeline
resource "aws_appsync_resolver" "start_multi_doc_discovery" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "startMultiDocDiscovery"
  data_source = aws_appsync_datasource.discovery_lambda.name
}

# Presigned URL for uploading a zip file of documents for multi-doc discovery
resource "aws_appsync_resolver" "upload_multi_doc_discovery_zip" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "uploadMultiDocDiscoveryZip"
  data_source = aws_appsync_datasource.discovery_lambda.name
}