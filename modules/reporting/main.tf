# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}

locals {
  # Extract bucket name from ARN
  # ARN format: arn:${data.aws_partition.current.partition}:s3:::bucket-name
  reporting_bucket_name = element(split(":", var.reporting_bucket_arn), length(split(":", var.reporting_bucket_arn)) - 1)

  # Module build directory
  module_build_dir = "${path.module}/.terraform-build"

  # VPC config
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Glue table for document-level evaluation metrics
resource "aws_glue_catalog_table" "document_evaluations_table" {
  name          = "document_evaluations"
  database_name = var.reporting_database_name
  description   = "Document-level evaluation metrics including accuracy, precision, recall, and F1 score"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "parquet"
    "compressionType"           = "gzip"
    "typeOfData"                = "file"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2020,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "storage.location.template" = "s3://${local.reporting_bucket_name}/evaluation_metrics/document_metrics/year=$${year}/month=$${month}/day=$${day}/"
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "document"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${local.reporting_bucket_name}/evaluation_metrics/document_metrics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "document_id"
      type = "string"
    }

    columns {
      name = "input_key"
      type = "string"
    }

    columns {
      name = "evaluation_date"
      type = "timestamp"
    }

    columns {
      name = "accuracy"
      type = "double"
    }

    columns {
      name = "precision"
      type = "double"
    }

    columns {
      name = "recall"
      type = "double"
    }

    columns {
      name = "f1_score"
      type = "double"
    }

    columns {
      name = "false_alarm_rate"
      type = "double"
    }

    columns {
      name = "false_discovery_rate"
      type = "double"
    }

    columns {
      name = "execution_time"
      type = "double"
    }

    columns {
      name = "processor_type"
      type = "string"
    }

    columns {
      name = "processing_time_ms"
      type = "bigint"
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "metadata"
      type = "string"
    }
  }
}

# Glue table for section-level evaluation metrics
resource "aws_glue_catalog_table" "section_evaluations_table" {
  name          = "section_evaluations"
  database_name = var.reporting_database_name
  description   = "Section-level evaluation metrics for individual sections within documents"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "parquet"
    "compressionType"           = "gzip"
    "typeOfData"                = "file"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2020,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "storage.location.template" = "s3://${local.reporting_bucket_name}/evaluation_metrics/section_metrics/year=$${year}/month=$${month}/day=$${day}/"
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "document"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${local.reporting_bucket_name}/evaluation_metrics/section_metrics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "document_id"
      type = "string"
    }

    columns {
      name = "section_id"
      type = "string"
    }

    columns {
      name = "section_type"
      type = "string"
    }

    columns {
      name = "accuracy"
      type = "double"
    }

    columns {
      name = "precision"
      type = "double"
    }

    columns {
      name = "recall"
      type = "double"
    }

    columns {
      name = "f1_score"
      type = "double"
    }

    columns {
      name = "false_alarm_rate"
      type = "double"
    }

    columns {
      name = "false_discovery_rate"
      type = "double"
    }

    columns {
      name = "evaluation_date"
      type = "timestamp"
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "metadata"
      type = "string"
    }
  }
}

# Glue table for attribute-level evaluation metrics
resource "aws_glue_catalog_table" "attribute_evaluations_table" {
  name          = "attribute_evaluations"
  database_name = var.reporting_database_name
  description   = "Attribute-level evaluation metrics for individual extracted attributes"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "parquet"
    "compressionType"           = "gzip"
    "typeOfData"                = "file"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2020,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "storage.location.template" = "s3://${local.reporting_bucket_name}/evaluation_metrics/attribute_metrics/year=$${year}/month=$${month}/day=$${day}/"
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "document"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${local.reporting_bucket_name}/evaluation_metrics/attribute_metrics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "document_id"
      type = "string"
    }

    columns {
      name = "section_id"
      type = "string"
    }

    columns {
      name = "section_type"
      type = "string"
    }

    columns {
      name = "attribute_name"
      type = "string"
    }

    columns {
      name = "expected"
      type = "string"
    }

    columns {
      name = "actual"
      type = "string"
    }

    columns {
      name = "matched"
      type = "boolean"
    }

    columns {
      name = "score"
      type = "double"
    }

    columns {
      name = "reason"
      type = "string"
    }

    columns {
      name = "evaluation_method"
      type = "string"
    }

    columns {
      name = "confidence"
      type = "string"
    }

    columns {
      name = "confidence_threshold"
      type = "string"
    }

    columns {
      name = "evaluation_date"
      type = "timestamp"
    }

    columns {
      name = "extracted_value"
      type = "string"
    }

    columns {
      name = "expected_value"
      type = "string"
    }

    columns {
      name = "is_correct"
      type = "boolean"
    }

    columns {
      name = "confidence_score"
      type = "double"
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "metadata"
      type = "string"
    }
  }
}

# Glue table for metering data
resource "aws_glue_catalog_table" "metering_table" {
  name          = "metering"
  database_name = var.reporting_database_name
  description   = "Cost and usage metrics for document processing operations"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "parquet"
    "compressionType"           = "gzip"
    "typeOfData"                = "file"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2020,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "storage.location.template" = "s3://${local.reporting_bucket_name}/metering/year=$${year}/month=$${month}/day=$${day}/"
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "document"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${local.reporting_bucket_name}/metering/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "document_id"
      type = "string"
    }

    columns {
      name = "context"
      type = "string"
    }

    columns {
      name = "service_api"
      type = "string"
    }

    columns {
      name = "unit"
      type = "string"
    }

    columns {
      name = "value"
      type = "double"
    }

    columns {
      name = "number_of_pages"
      type = "integer"
    }

    columns {
      name = "processor_type"
      type = "string"
    }

    columns {
      name = "operation_type"
      type = "string"
    }

    columns {
      name = "cost_usd"
      type = "double"
    }

    columns {
      name = "tokens_consumed"
      type = "bigint"
    }

    columns {
      name = "processing_time_ms"
      type = "bigint"
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "metadata"
      type = "string"
    }
  }
}
# Lambda function for saving reporting data
resource "aws_lambda_function" "save_reporting_data" {
  function_name = "${var.name_prefix}-save-reporting-data-${random_string.suffix.result}"

  filename         = data.archive_file.save_reporting_data_code.output_path
  source_code_hash = data.archive_file.save_reporting_data_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 1024
  role        = aws_iam_role.save_reporting_data_role.arn
  description = "Lambda function that saves document evaluation data to the reporting bucket in Parquet format"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL        = var.log_level
      METRIC_NAMESPACE = var.metric_namespace
      REPORTING_BUCKET = local.reporting_bucket_name
      OUTPUT_BUCKET    = var.output_bucket_name
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [local.vpc_config] : []
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

# Source code archive
data "archive_file" "save_reporting_data_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/save_reporting_data"
  output_path = "${local.module_build_dir}/save-reporting-data.zip"

  depends_on = [null_resource.create_module_build_dir]
}

# IAM role for save reporting data function
resource "aws_iam_role" "save_reporting_data_role" {
  name = "${var.name_prefix}-save-reporting-data-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for save reporting data function
resource "aws_iam_policy" "save_reporting_data_policy" {
  name = "${var.name_prefix}-save-reporting-data-policy-${random_string.suffix.result}"

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
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.reporting_bucket_arn,
          "${var.reporting_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "save_reporting_data_policy_attachment" {
  role       = aws_iam_role.save_reporting_data_role.name
  policy_arn = aws_iam_policy.save_reporting_data_policy.arn
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_policy" "kms_policy" {
  for_each    = toset(["enabled"])
  name        = "${var.name_prefix}-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for reporting functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = var.encryption_key_arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "save_reporting_data_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.save_reporting_data_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

# VPC policy
resource "aws_iam_policy" "vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name        = "${var.name_prefix}-vpc-policy-${random_string.suffix.result}"
  description = "VPC policy for reporting functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 network interface operations for VPC Lambda - AWS service limitation requires wildcard resource
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "save_reporting_data_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.save_reporting_data_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "save_reporting_data_logs" {
  name              = "/aws/lambda/${aws_lambda_function.save_reporting_data.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}
