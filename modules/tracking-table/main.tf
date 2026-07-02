# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Tracking Table Module
 *
 * This module creates a DynamoDB table for tracking document processing status and results.
 * The table uses a composite key (PK, SK) to efficiently store and query information about 
 * documents being processed, including their current status, processing history, and extraction results.
 * The table design supports various access patterns needed for monitoring and reporting on document
 * processing activities.
 */

resource "aws_dynamodb_table" "tracking_table" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Attributes backing the TypeDateIndex GSI (upstream TrackingTable, v0.5.1).
  attribute {
    name = "ItemType"
    type = "S"
  }

  attribute {
    name = "InitialEventTime"
    type = "S"
  }

  # TypeDateIndex replaces both the old listDocuments scan and the
  # HITLPendingReviewIndex. Non-key attribute list copied verbatim from
  # sources/template.yaml (TrackingTable.GlobalSecondaryIndexes). DynamoDB adds a
  # GSI in place, so this is an additive, non-replacing table update.
  global_secondary_index {
    name            = "TypeDateIndex"
    hash_key        = "ItemType"
    range_key       = "InitialEventTime"
    projection_type = "INCLUDE"
    non_key_attributes = [
      "ObjectKey",
      "ObjectStatus",
      "CompletionTime",
      "ConfigVersion",
      "EvaluationStatus",
      "NumPages",
      "ConfidenceAlertCount",
      "HITLTriggered",
      "HITLCompleted",
      "HITLStatus",
      "HITLReviewOwner",
      "HITLReviewedBy",
      "TestRunId",
      "TestSetName",
      "CreatedAt",
      "CompletedFiles",
      "FailedFiles",
      "FilesCount",
      "Status",
      "CompletedAt",
    ]

    # GSI capacity is only meaningful under PROVISIONED billing; gate it the same
    # way the base table does so PAY_PER_REQUEST tables omit it entirely.
    read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
    write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
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
