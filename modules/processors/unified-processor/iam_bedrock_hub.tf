# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# BedrockHubRoleArn cross-account assume-role (v0.5.12). When
# var.bedrock_hub_role_arn is non-empty, the Bedrock-calling Lambdas get
# sts:AssumeRole scoped to exactly that ARN so idp_common can assume a hub
# account role. Empty/unset renders nothing (count = 0), so same-account
# deployments show no diff.

resource "aws_iam_role_policy" "classification_bedrock_hub_assume" {
  count = local.bedrock_hub_enabled ? 1 : 0

  name = "${local.name_prefix}-classification-bedrock-hub-assume-policy"
  role = aws_iam_role.classification_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "extraction_bedrock_hub_assume" {
  count = local.bedrock_hub_enabled ? 1 : 0

  name = "${local.name_prefix}-extraction-bedrock-hub-assume-policy"
  role = aws_iam_role.extraction_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "assessment_bedrock_hub_assume" {
  count = local.bedrock_hub_enabled ? 1 : 0

  name = "${local.name_prefix}-assessment-bedrock-hub-assume-policy"
  role = aws_iam_role.assessment_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "summarization_bedrock_hub_assume" {
  count = local.bedrock_hub_enabled && var.is_summarization_enabled ? 1 : 0

  name = "${local.name_prefix}-summarization-bedrock-hub-assume-policy"
  role = aws_iam_role.summarization_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "evaluation_bedrock_hub_assume" {
  count = local.bedrock_hub_enabled && var.evaluation_enabled ? 1 : 0

  name = "${local.name_prefix}-evaluation-bedrock-hub-assume-policy"
  role = aws_iam_role.evaluation_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "rule_validation_bedrock_hub_assume" {
  count = local.bedrock_hub_enabled && var.enable_rule_validation ? 1 : 0

  name = "${local.name_prefix}-rule-validation-bedrock-hub-assume-policy"
  role = aws_iam_role.rule_validation_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.bedrock_hub_role_arn
      }
    ]
  })
}
