# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Processing Environment API Example
 *
 * This example demonstrates how to use the Processing Environment API module from the GenAI IDP Accelerator.
 * It creates all the necessary resources including DynamoDB tables, S3 buckets, and the GraphQL API.
 */

provider "aws" {
  region = var.region
}

# Create S3 buckets for document processing
resource "aws_s3_bucket" "input_bucket" {
  bucket = "${var.prefix}-input-bucket-${random_string.suffix.result}"
  tags   = var.tags
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = "${var.prefix}-output-bucket-${random_string.suffix.result}"
  tags   = var.tags
}

resource "aws_s3_bucket" "evaluation_baseline_bucket" {
  bucket = "${var.prefix}-baseline-bucket-${random_string.suffix.result}"
  tags   = var.tags
}

# Create DynamoDB tables
module "tracking_table" {
  source = "../../modules/tracking-table"

  table_name                     = "${var.prefix}-tracking-table"
  billing_mode                   = var.billing_mode
  read_capacity                  = var.read_capacity
  write_capacity                 = var.write_capacity
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled

  tags = var.tags
}

module "configuration_table" {
  source = "../../modules/configuration-table"

  table_name                     = "${var.prefix}-configuration-table"
  billing_mode                   = var.billing_mode
  read_capacity                  = var.read_capacity
  write_capacity                 = var.write_capacity
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled

  tags = var.tags
}

module "concurrency_table" {
  source = "../../modules/concurrency-table"

  table_name                     = "${var.prefix}-concurrency-table"
  billing_mode                   = var.billing_mode
  read_capacity                  = var.read_capacity
  write_capacity                 = var.write_capacity
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled

  tags = var.tags
}

# Create the Processing Environment API using the new ARN-based approach
module "processing_environment_api" {
  source = "../../modules/processing-environment-api"

  name = "${var.prefix}-processing-api"

  # Required resources using the new ARN-based approach
  tracking_table_arn = module.tracking_table.table_arn
  input_bucket_arn   = aws_s3_bucket.input_bucket.arn
  output_bucket_arn  = aws_s3_bucket.output_bucket.arn

  # Optional configuration
  configuration_table_arn        = module.configuration_table.table_arn
  evaluation_baseline_bucket_arn = aws_s3_bucket.evaluation_baseline_bucket.arn

  # Logging
  log_level          = "INFO"
  log_retention_days = 7

  tags = var.tags
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
