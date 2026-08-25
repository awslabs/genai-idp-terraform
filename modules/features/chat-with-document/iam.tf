# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM statement sets for the Chat-with-Document Lambdas. Mirrors the upstream
# v0.5.12 policies on `ChatWithDocumentProcessorFunction` (main template) and
# `SendChatDocumentMessageResolverFunction` (nested appsync template).
#
# Bedrock invoke scope includes `application-inference-profile/*` and
# `GetInferenceProfile` (B1, Requirement 4) so v0.5.7+ inference-profile model
# paths work for large-context chat (e.g. Opus 4.7 1M).

locals {
  # ---------------------------------------------------------------------------
  # Processor Lambda IAM (long-running, calls Bedrock + publishes to AppSync)
  # ---------------------------------------------------------------------------
  processor_iam_statements = concat(
    [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Sid      = "OutputBucketReadWrite"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket", "s3:PutObject"]
        Resource = [var.output_bucket_arn, "${var.output_bucket_arn}/*"]
      },
      {
        Sid    = "ConfigAndTrackingRead"
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = compact([
          var.configuration_table_arn,
          var.configuration_table_arn != null ? "${var.configuration_table_arn}/index/*" : null,
          var.tracking_table_arn,
          var.tracking_table_arn != null ? "${var.tracking_table_arn}/index/*" : null,
        ])
      },
      # The former "AppSyncPublish" statement (appsync:GraphQL on
      # "${var.appsync_graphql_api_arn}/types/Mutation/*") is removed: IDP v0.6.4
      # deleted AppSync, so there is no GraphQL endpoint to publish streaming
      # updates to. The processor now writes chat state to DynamoDB and tokens
      # stream over the chat-stream Lambda Function URL, neither of which needs
      # this grant. Keeping it would have granted appsync:GraphQL against an API
      # Gateway ARN, which cannot match anything.
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetInferenceProfile",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:application-inference-profile/*",
        ]
      },
      {
        Sid = "BedrockMantle"
        # OpenAI GPT-5.x via the bedrock-mantle endpoint (OpenAI Responses API),
        # a separate IAM action namespace. Mirrors upstream v0.5.16.
        Effect = "Allow"
        Action = [
          "bedrock-mantle:CreateInference",
          "bedrock-mantle:GetProject",
          "bedrock-mantle:ListProjects",
          "bedrock-mantle:ListTagsForResources",
        ]
        Resource = "*"
      },
      {
        Sid    = "BedrockMarketplace"
        Effect = "Allow"
        Action = [
          "aws-marketplace:Subscribe",
          "aws-marketplace:Unsubscribe",
          "aws-marketplace:ViewSubscriptions",
        ]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
    ],
    var.encryption_key_arn != null ? [
      {
        Sid    = "Kms"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = var.encryption_key_arn
      }
    ] : [],
    var.guardrail_id_and_version != null ? [
      {
        Sid      = "Guardrail"
        Effect   = "Allow"
        Action   = "bedrock:ApplyGuardrail"
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:guardrail/${split(":", var.guardrail_id_and_version)[0]}"
      }
    ] : [],
  )

  # ---------------------------------------------------------------------------
  # Resolver Lambda IAM (lightweight, async-invokes processor + session CRUD)
  # ---------------------------------------------------------------------------
  resolver_iam_statements = concat(
    [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Sid    = "SessionsTableCrud"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
        ]
        Resource = [
          aws_dynamodb_table.chat_document_sessions.arn,
          "${aws_dynamodb_table.chat_document_sessions.arn}/index/*",
        ]
      },
      {
        Sid      = "InvokeProcessor"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.chat_processor.arn
      },
    ],
    var.encryption_key_arn != null ? [
      {
        Sid    = "Kms"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = var.encryption_key_arn
      }
    ] : [],
  )
}
