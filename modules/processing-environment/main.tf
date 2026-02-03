# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Processing Environment Module
 *
 * This module creates the core infrastructure for the Intelligent Document Processing solution.
 * It orchestrates the end-to-end document processing workflow, from document ingestion to 
 * structured data extraction and result tracking.
 */

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Extract bucket names from ARNs (format: arn:${data.aws_partition.current.partition}:s3:::bucket-name)
  input_bucket_name   = element(split(":", var.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", var.output_bucket_arn), 5)
  working_bucket_name = element(split(":", var.working_bucket_arn), 5)

  # Lambda function names (to avoid circular dependencies in IAM policies)
  queue_sender_function_name         = "idp-queue-sender-${random_string.suffix.result}"
  workflow_tracker_function_name     = "idp-workflow-tracker-${random_string.suffix.result}"
  lookup_function_name               = "idp-lookup-function-${random_string.suffix.result}"
  update_configuration_function_name = "idp-update-configuration-${random_string.suffix.result}"

  # Create tables if not provided
  create_configuration_table = var.configuration_table_arn == null
  create_tracking_table      = var.tracking_table_arn == null
  create_concurrency_table   = var.concurrency_table_arn == null





  # Evaluation bucket name if provided
  baseline_bucket_name = var.evaluation_config != null ? element(split(":", var.evaluation_config.baseline_bucket_arn), 5) : null

  # Reporting bucket name if provided
  reporting_bucket_name = var.enable_reporting ? element(split(":", var.reporting_bucket_arn), 5) : null

  # KMS key configuration
  key = var.encryption_key_arn != null ? {
    key_id  = element(split("/", var.encryption_key_arn), 1)
    key_arn = var.encryption_key_arn
  } : null



  # For backward compatibility with configuration_table
  configuration_table = local.create_configuration_table ? module.configuration_table[0] : {
    table_name = element(split("/", var.configuration_table_arn), 1)
    table_arn  = var.configuration_table_arn
  }

  # For backward compatibility with tracking_table
  tracking_table = local.create_tracking_table ? module.tracking_table[0] : {
    table_name = element(split("/", var.tracking_table_arn), 1)
    table_arn  = var.tracking_table_arn
  }

  # For backward compatibility with concurrency_table
  concurrency_table = local.create_concurrency_table ? module.concurrency_table[0] : {
    table_name = element(split("/", var.concurrency_table_arn), 1)
    table_arn  = var.concurrency_table_arn
  }
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create DynamoDB tables if not provided
module "configuration_table" {
  count  = local.create_configuration_table ? 1 : 0
  source = "../configuration-table"

  table_name                     = "idp-configuration-table-${random_string.suffix.result}"
  kms_key_arn                    = local.key != null ? local.key.key_arn : null
  point_in_time_recovery_enabled = true

  tags = var.tags

  depends_on = [random_string.suffix]
}

module "tracking_table" {
  count  = local.create_tracking_table ? 1 : 0
  source = "../tracking-table"

  table_name                     = "idp-tracking-table-${random_string.suffix.result}"
  kms_key_arn                    = local.key != null ? local.key.key_arn : null
  point_in_time_recovery_enabled = true

  tags = var.tags

  depends_on = [random_string.suffix]
}

module "concurrency_table" {
  count  = local.create_concurrency_table ? 1 : 0
  source = "../concurrency-table"

  table_name                     = "idp-concurrency-table-${random_string.suffix.result}"
  kms_key_arn                    = local.key != null ? local.key.key_arn : null
  point_in_time_recovery_enabled = true

  tags = var.tags

  depends_on = [random_string.suffix]
}
