# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# DynamoDB Data Source for Tracking Table
resource "aws_appsync_datasource" "tracking_table" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "TrackingTableDataSource"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = aws_iam_role.appsync_dynamodb_role.arn

  dynamodb_config {
    table_name = local.tracking_table_name
    region     = data.aws_region.current.id
  }
}

# Note: Lambda data sources have been moved to their respective lambda_*.tf files
# for better organization and maintainability
