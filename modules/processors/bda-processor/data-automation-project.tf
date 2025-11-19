# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Data Automation Project
 *
 * This module defines the interface for an Amazon Bedrock Data Automation Project.
 * Data Automation Projects in Amazon Bedrock provide a managed way to extract
 * structured data from documents using foundation models.
 */

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
# This is a data source to get information about the Bedrock Data Automation Project
data "aws_arn" "data_automation_project" {
  arn = var.data_automation_project_arn
}

locals {
  project_id = element(split("/", data.aws_arn.data_automation_project.resource), 1)
}

# IAM policy for invoking the Data Automation Project
resource "aws_iam_policy" "invoke_data_automation_project" {
  name        = "InvokeDataAutomationProject-${random_string.suffix.result}"
  description = "Policy for invoking Bedrock Data Automation Project"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeDataAutomationAsync"
        ]
        Effect = "Allow"
        Resource = [
          var.data_automation_project_arn,
          "arn:${data.aws_partition.current.partition}:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:data-automation-profile/us.data-automation-v1",
          "arn:${data.aws_partition.current.partition}:bedrock:us-west-1:${data.aws_caller_identity.current.account_id}:data-automation-profile/us.data-automation-v1",
          "arn:${data.aws_partition.current.partition}:bedrock:us-east-2:${data.aws_caller_identity.current.account_id}:data-automation-profile/us.data-automation-v1",
          "arn:${data.aws_partition.current.partition}:bedrock:us-west-2:${data.aws_caller_identity.current.account_id}:data-automation-profile/us.data-automation-v1",
        ]
      }
    ]
  })
}
