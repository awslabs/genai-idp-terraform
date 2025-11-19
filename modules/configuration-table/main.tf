# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Configuration Table Module
 *
 * This module creates a DynamoDB table for storing configuration settings for the document processing solution.
 * The table uses a fixed partition key "Configuration" to store various configuration items such as:
 * - Document extraction schemas and templates
 * - Model parameters and prompt configurations
 * - Evaluation criteria and thresholds
 * - UI settings and customizations
 * - Processing workflow configurations
 */

resource "aws_dynamodb_table" "configuration_table" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = "Configuration"

  attribute {
    name = "Configuration"
    type = "S"
  }

  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  deletion_protection_enabled = var.deletion_protection_enabled
  table_class                 = var.table_class

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = var.tags
}
