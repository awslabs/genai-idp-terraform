# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# B8 — BedrockHubRoleArn cross-account assume-role (v0.5.12).
#
# When var.bedrock_hub_role_arn is non-empty, the Bedrock-calling processing
# Lambdas are granted sts:AssumeRole scoped to EXACTLY that ARN (and no other),
# so idp_common.bedrock.session can assume a centralized "hub" account role for
# Bedrock calls. The grant attaches in the shared unified-processor engine, so
# all three façades (bda / bedrock-llm / sagemaker-udop) inherit it.
#
# When var.bedrock_hub_role_arn is empty/unset, NONE of these policies render
# (count = 0) and no BEDROCK_ASSUME_ROLE_* env var is set on the Lambdas, so an
# existing same-account deployment shows no B8-attributable diff (Req 10.2/10.4).
#
# The Resource is scoped to exactly the supplied hub role ARN (Req 10.3); tfsec
# passes on the scoped statement (Req 10.5).

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
