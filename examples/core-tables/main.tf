# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # GenAI IDP Core Tables Example
 *
 * This example demonstrates how to use the core table modules from the GenAI IDP Accelerator.
 * It creates the three fundamental DynamoDB tables needed for the document processing solution:
 * - Concurrency Table: For managing concurrent document processing tasks
 * - Configuration Table: For storing system configuration settings
 * - Tracking Table: For tracking document processing status and results
 */

provider "aws" {
  region = var.region
}

# Create the concurrency table
module "concurrency_table" {
  source = "../../modules/concurrency-table"

  table_name                     = "${var.prefix}-concurrency-table"
  billing_mode                   = var.billing_mode
  read_capacity                  = var.read_capacity
  write_capacity                 = var.write_capacity
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.deletion_protection_enabled

  tags = var.tags
}

# Create the configuration table
module "configuration_table" {
  source = "../../modules/configuration-table"

  table_name                     = "${var.prefix}-configuration-table"
  billing_mode                   = var.billing_mode
  read_capacity                  = var.read_capacity
  write_capacity                 = var.write_capacity
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.deletion_protection_enabled

  tags = var.tags
}

# Create the tracking table
module "tracking_table" {
  source = "../../modules/tracking-table"

  table_name                     = "${var.prefix}-tracking-table"
  billing_mode                   = var.billing_mode
  read_capacity                  = var.read_capacity
  write_capacity                 = var.write_capacity
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.deletion_protection_enabled

  tags = var.tags
}
