# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM Roles and Policies for Bedrock LLM Processor

# Step Functions State Machine Role
resource "aws_iam_role" "state_machine" {
  name = "${local.name_prefix}-state-machine-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "state_machine" {
  name = "${local.name_prefix}-state-machine-policy"
  role = aws_iam_role.state_machine.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = compact([
          aws_lambda_function.ocr.arn,
          aws_lambda_function.classification.arn,
          aws_lambda_function.extraction.arn,
          aws_lambda_function.process_results.arn,
          var.is_summarization_enabled ? aws_lambda_function.summarization[0].arn : "",
          aws_lambda_function.assessment.arn,
          var.enable_hitl ? aws_lambda_function.hitl_wait[0].arn : "",
          var.enable_hitl ? aws_lambda_function.hitl_status_update[0].arn : ""
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# OCR Lambda Role
resource "aws_iam_role" "ocr_lambda" {
  name = "${local.name_prefix}-ocr-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ocr_lambda_basic" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.ocr_lambda.name
}

resource "aws_iam_role_policy" "ocr_lambda" {
  name = "${local.name_prefix}-ocr-lambda-policy"
  role = aws_iam_role.ocr_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # AWS Textract does not support resource-level permissions - service limitation
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = local.s3_object_arns
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = local.s3_bucket_arns
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = concat(
          [local.configuration_table_arn],
          var.enable_api ? [] : [local.tracking_table_arn]
        )
      },
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = local.api_arn != null ? [
          "${local.api_arn}/types/Query/*",
          "${local.api_arn}/types/Mutation/*",
          "${local.api_arn}/types/Subscription/*"
        ] : ["*"]
      },
      {
        # CloudWatch PutMetricData requires wildcard resource but is constrained by namespace condition
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.metric_namespace
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = [
          local.encryption_key_arn
        ]
      }
    ]
  })
}

# Classification Lambda Role
resource "aws_iam_role" "classification_lambda" {
  name = "${local.name_prefix}-classification-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "classification_lambda_basic" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.classification_lambda.name
}

resource "aws_iam_role_policy" "classification_lambda" {
  name = "${local.name_prefix}-classification-lambda-policy"
  role = aws_iam_role.classification_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Foundation model permissions (always included)
      local.bedrock_model_permissions.classification != null ? [{
        Effect   = local.bedrock_model_permissions.classification.foundation_statement.effect
        Action   = local.bedrock_model_permissions.classification.foundation_statement.actions
        Resource = local.bedrock_model_permissions.classification.foundation_statement.resources
      }] : [],
      # Inference profile permissions (conditional)
      local.bedrock_model_permissions.classification != null && local.bedrock_model_permissions.classification.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.classification.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.classification.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.classification.inference_profile_statement.resources
      }] : [],
      # Standard permissions
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = local.s3_object_arns
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = local.s3_bucket_arns
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = [
            local.configuration_table_arn,
            local.tracking_table_arn
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "appsync:GraphQL"
          ]
          Resource = local.api_arn != null ? [
            "${local.api_arn}/types/Query/*",
            "${local.api_arn}/types/Mutation/*",
            "${local.api_arn}/types/Subscription/*"
          ] : ["*"]
        },
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = local.metric_namespace
            }
          }
        }
      ]
    )
  })
}

# Extraction Lambda Role
resource "aws_iam_role" "extraction_lambda" {
  name = "${local.name_prefix}-extraction-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "extraction_lambda_basic" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.extraction_lambda.name
}

resource "aws_iam_role_policy" "extraction_lambda" {
  name = "${local.name_prefix}-extraction-lambda-policy"
  role = aws_iam_role.extraction_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Foundation model permissions (always included)
      local.bedrock_model_permissions.extraction != null ? [{
        Effect   = local.bedrock_model_permissions.extraction.foundation_statement.effect
        Action   = local.bedrock_model_permissions.extraction.foundation_statement.actions
        Resource = local.bedrock_model_permissions.extraction.foundation_statement.resources
      }] : [],
      # Inference profile permissions (conditional)
      local.bedrock_model_permissions.extraction != null && local.bedrock_model_permissions.extraction.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.extraction.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.extraction.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.extraction.inference_profile_statement.resources
      }] : [],
      # Standard permissions
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = local.s3_object_arns
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = local.s3_bucket_arns
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = [
            local.configuration_table_arn,
            local.tracking_table_arn
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "appsync:GraphQL"
          ]
          Resource = local.api_arn != null ? [
            "${local.api_arn}/types/Query/*",
            "${local.api_arn}/types/Mutation/*",
            "${local.api_arn}/types/Subscription/*"
          ] : ["*"]
        },
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = local.metric_namespace
            }
          }
        }
      ]
    )
  })
}

# Process Results Lambda Role
resource "aws_iam_role" "process_results_lambda" {
  name = "${local.name_prefix}-process-results-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "process_results_lambda_basic" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.process_results_lambda.name
}

resource "aws_iam_role_policy" "process_results_lambda" {
  name = "${local.name_prefix}-process-results-lambda-policy"
  role = aws_iam_role.process_results_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = local.s3_object_arns
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = local.s3_bucket_arns
      },
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = local.api_arn != null ? [
          "${local.api_arn}/types/Query/*",
          "${local.api_arn}/types/Mutation/*",
          "${local.api_arn}/types/Subscription/*"
        ] : ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.metric_namespace
          }
        }
      }
      ], var.enable_api ? [] : [{
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [local.tracking_table_arn]
    }])
  })
}

# Summarization Lambda Role (conditional)
resource "aws_iam_role" "summarization_lambda" {
  count = var.is_summarization_enabled ? 1 : 0
  name  = "${local.name_prefix}-summarization-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "summarization_lambda_basic" {
  count      = var.is_summarization_enabled ? 1 : 0
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.summarization_lambda[0].name
}

resource "aws_iam_role_policy" "summarization_lambda" {
  count = var.is_summarization_enabled ? 1 : 0
  name  = "${local.name_prefix}-summarization-lambda-policy"
  role  = aws_iam_role.summarization_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Foundation model permissions (always included)
      local.bedrock_model_permissions.summarization != null ? [{
        Effect   = local.bedrock_model_permissions.summarization.foundation_statement.effect
        Action   = local.bedrock_model_permissions.summarization.foundation_statement.actions
        Resource = local.bedrock_model_permissions.summarization.foundation_statement.resources
      }] : [],
      # Inference profile permissions (conditional)
      local.bedrock_model_permissions.summarization != null && local.bedrock_model_permissions.summarization.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.summarization.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.summarization.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.summarization.inference_profile_statement.resources
      }] : [],
      # Standard permissions
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = local.s3_object_arns
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = local.s3_bucket_arns
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = [
            local.configuration_table_arn,
            local.tracking_table_arn
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "appsync:GraphQL"
          ]
          Resource = local.api_arn != null ? [
            "${local.api_arn}/types/Query/*",
            "${local.api_arn}/types/Mutation/*",
            "${local.api_arn}/types/Subscription/*"
          ] : ["*"]
        },
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = local.metric_namespace
            }
          }
        }
      ]
    )
  })
}


# Add KMS permissions if encryption key is provided
resource "aws_iam_policy" "kms_policy" {
  name        = "${local.name_prefix}-kms-policy"
  description = "KMS policy for BDA processor functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ocr_lambda_attachment" {
  role       = aws_iam_role.ocr_lambda.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "classification_lambda_kms_attachment" {
  role       = aws_iam_role.classification_lambda.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "extraction_lambda_kms_attachment" {
  role       = aws_iam_role.extraction_lambda.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "process_results_lambda_kms_attachment" {
  role       = aws_iam_role.process_results_lambda.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "summarization_kms_attachment" {
  count      = var.is_summarization_enabled ? 1 : 0
  role       = aws_iam_role.summarization_lambda[0].name
  policy_arn = aws_iam_policy.kms_policy.arn
}

# Assessment Lambda IAM Role (always deployed, controlled by configuration)
resource "aws_iam_role" "assessment_lambda" {
  name = "${local.name_prefix}-assessment-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "assessment_lambda" {
  name = "${local.name_prefix}-assessment-lambda-policy"
  role = aws_iam_role.assessment_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.assessment.function_name}",
            "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.assessment.function_name}:*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.input_bucket_arn,
            "${local.input_bucket_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.output_bucket_arn,
            "${local.output_bucket_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.working_bucket_arn,
            "${local.working_bucket_arn}/*"
          ]
        },

        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = [
            local.configuration_table_arn,
            "${local.configuration_table_arn}/index/*"
          ]
        }
      ],
      # Conditional DynamoDB tracking table permissions (only when API is disabled)
      var.enable_api ? [] : [{
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      }],
      # Foundation model permissions
      local.bedrock_model_permissions.assessment != null ? [{
        Effect   = local.bedrock_model_permissions.assessment.foundation_statement.effect
        Action   = local.bedrock_model_permissions.assessment.foundation_statement.actions
        Resource = local.bedrock_model_permissions.assessment.foundation_statement.resources
        }] : [{
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel*", "bedrock:GetFoundationModel"]
        Resource = ["arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.assessment_model_id}"]
      }],
      # Inference profile permissions (conditional)
      local.bedrock_model_permissions.assessment != null && local.bedrock_model_permissions.assessment.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.assessment.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.assessment.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.assessment.inference_profile_statement.resources
      }] : [],
      [
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = local.metric_namespace
            }
          }
        }
      ]
    )
  })
}

# Add AppSync permissions if API is provided
resource "aws_iam_role_policy" "assessment_lambda_appsync" {
  count = var.enable_api ? 1 : 0

  name = "${local.name_prefix}-assessment-lambda-appsync-policy"
  role = aws_iam_role.assessment_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = "${local.api_arn}/types/Mutation/*"
      }
    ]
  })
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_role_policy" "assessment_lambda_kms" {
  name = "${local.name_prefix}-assessment-lambda-kms-policy"
  role = aws_iam_role.assessment_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = local.encryption_key_arn
      }
    ]
  })
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "assessment_lambda_vpc" {
  count = length(local.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.assessment_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "assessment_kms_attachment" {
  role       = aws_iam_role.assessment_lambda.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

# VPC permissions for Lambda functions
resource "aws_iam_role_policy_attachment" "ocr_lambda_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.ocr_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "classification_lambda_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.classification_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "extraction_lambda_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.extraction_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "process_results_lambda_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.process_results_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "summarization_lambda_vpc" {
  count      = var.is_summarization_enabled && length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.summarization_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# HITL Wait Lambda IAM Role (conditional)
resource "aws_iam_role" "hitl_wait_lambda" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.name_prefix}-hitl-wait-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "hitl_wait_lambda" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.name_prefix}-hitl-wait-lambda-policy"
  role  = aws_iam_role.hitl_wait_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${local.working_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Add AppSync permissions if API is provided
resource "aws_iam_role_policy" "hitl_wait_lambda_appsync" {
  count = var.enable_hitl && var.enable_api ? 1 : 0
  name  = "${local.name_prefix}-hitl-wait-lambda-appsync-policy"
  role  = aws_iam_role.hitl_wait_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = [
          "${local.api_arn}/types/Mutation/*"
        ]
      }
    ]
  })
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_role_policy" "hitl_wait_lambda_kms" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.name_prefix}-hitl-wait-lambda-kms-policy"
  role  = aws_iam_role.hitl_wait_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.encryption_key_arn
      }
    ]
  })
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "hitl_wait_lambda_vpc" {
  count      = var.enable_hitl && length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.hitl_wait_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "hitl_wait_kms_attachment" {
  count      = var.enable_hitl ? 1 : 0
  role       = aws_iam_role.hitl_wait_lambda[0].name
  policy_arn = aws_iam_policy.kms_policy.arn
}

# HITL Status Update Lambda IAM Role (conditional)
resource "aws_iam_role" "hitl_status_update_lambda" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.name_prefix}-hitl-status-update-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "hitl_status_update_lambda" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.name_prefix}-hitl-status-update-lambda-policy"
  role  = aws_iam_role.hitl_status_update_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${local.working_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_role_policy" "hitl_status_update_lambda_kms" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.name_prefix}-hitl-status-update-lambda-kms-policy"
  role  = aws_iam_role.hitl_status_update_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.encryption_key_arn
      }
    ]
  })
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "hitl_status_update_lambda_vpc" {
  count      = var.enable_hitl && length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.hitl_status_update_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "hitl_status_update_kms_attachment" {
  count      = var.enable_hitl ? 1 : 0
  role       = aws_iam_role.hitl_status_update_lambda[0].name
  policy_arn = aws_iam_policy.kms_policy.arn
}
