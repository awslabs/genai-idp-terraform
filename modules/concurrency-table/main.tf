# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Concurrency Table Module
 *
 * This module creates a DynamoDB table for managing concurrency limits in document processing.
 * The table is used to track and limit concurrent document processing tasks,
 * preventing resource exhaustion and ensuring system stability under load.
 */

resource "aws_dynamodb_table" "concurrency_table" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = "counter_id"

  attribute {
    name = "counter_id"
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

locals {
  item_json = file("${path.module}/item.json")
  item_tf   = jsondecode(local.item_json)
}

resource "aws_dynamodb_table_item" "workflow_counter" {
  table_name = aws_dynamodb_table.concurrency_table.name
  hash_key   = aws_dynamodb_table.concurrency_table.hash_key

  item = jsonencode(local.item_tf)

  lifecycle {
    ignore_changes = [item]
  }
}

