# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM Roles and Policies for SageMaker UDOP Processor
#
# Note: CloudWatch PutMetricData permissions use wildcard resources but are constrained by namespace conditions

# Bedrock model permissions for all models used by this processor
locals {
  # Collect all Bedrock models used by this processor
  bedrock_models = compact([
    var.extraction_model_id != null ? "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.extraction_model_id}" : null,
    var.summarization_model_id != null ? "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.summarization_model_id}" : null,
    var.evaluation_model_id != null ? "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.evaluation_model_id}" : null,
    # Assessment model ARN
    "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.assessment_model_id}",
  ])
}

# Create IAM policy for Bedrock model permissions
resource "aws_iam_policy" "bedrock_model_permissions" {
  count       = length(local.bedrock_models) > 0 ? 1 : 0
  name        = "${local.name_prefix}-bedrock-model-permissions"
  description = "Permissions for Bedrock models used by SageMaker UDOP processor"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream"
          ]
          Resource = local.bedrock_models
        }
      ],
      length(local.bedrock_models) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "bedrock:GetFoundationModel",
            "bedrock:GetInferenceProfile"
          ]
          Resource = "*"
        }
      ] : []
    )
  })
}

# Attach centralized Bedrock model permissions to roles that need them
resource "aws_iam_role_policy_attachment" "classification_function_bedrock" {
  count      = length(local.bedrock_models) > 0 ? 1 : 0
  role       = aws_iam_role.classification_function_role.name
  policy_arn = aws_iam_policy.bedrock_model_permissions[0].arn
}

resource "aws_iam_role_policy_attachment" "extraction_function_bedrock" {
  count      = length(local.bedrock_models) > 0 ? 1 : 0
  role       = aws_iam_role.extraction_function_role.name
  policy_arn = aws_iam_policy.bedrock_model_permissions[0].arn
}

resource "aws_iam_role_policy_attachment" "summarization_function_bedrock" {
  count      = length(local.bedrock_models) > 0 ? 1 : 0
  role       = aws_iam_role.summarization_function_role.name
  policy_arn = aws_iam_policy.bedrock_model_permissions[0].arn
}

resource "aws_iam_role_policy_attachment" "assessment_lambda_bedrock" {
  count      = length(local.bedrock_models) > 0 ? 1 : 0
  role       = aws_iam_role.assessment_lambda.name
  policy_arn = aws_iam_policy.bedrock_model_permissions[0].arn
}

# Step Functions Role
resource "aws_iam_role" "step_functions_role" {
  name = "${local.name_prefix}-sfn-role"

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

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${local.name_prefix}-sfn-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = compact([
          aws_lambda_function.ocr_function.arn,
          aws_lambda_function.classification_function.arn,
          aws_lambda_function.extraction_function.arn,
          aws_lambda_function.process_results_function.arn,
          aws_lambda_function.summarization_function.arn,
          aws_lambda_function.assessment_function.arn
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

# OCR Function Role
resource "aws_iam_role" "ocr_function_role" {
  name = "${local.name_prefix}-sagemaker-udop-ocr-role"

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

resource "aws_iam_role_policy_attachment" "ocr_function_basic_execution" {
  role       = aws_iam_role.ocr_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ocr_function_vpc_access" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.ocr_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "ocr_function_policy" {
  name = "${local.name_prefix}-sagemaker-udop-ocr-policy"
  role = aws_iam_role.ocr_function_role.id

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
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*",
          "${local.working_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.input_bucket_arn,
          local.output_bucket_arn,
          local.working_bucket_arn
        ]
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
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

# OCR Function AppSync Policy (conditional)
resource "aws_iam_role_policy" "ocr_function_appsync_policy" {
  for_each = var.enable_api ? { "appsync" = true } : {}

  name = "${local.name_prefix}-sagemaker-udop-ocr-appsync-policy"
  role = aws_iam_role.ocr_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = [
          "${var.api_arn}/types/Query/*",
          "${var.api_arn}/types/Mutation/*",
          "${var.api_arn}/types/Subscription/*"
        ]
      }
    ]
  })
}

# Classification Function Role
resource "aws_iam_role" "classification_function_role" {
  name = "${local.name_prefix}-classification-role"

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

resource "aws_iam_role_policy_attachment" "classification_function_basic_execution" {
  role       = aws_iam_role.classification_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "classification_function_vpc_access" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.classification_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "classification_function_policy" {
  name = "${local.name_prefix}-sagemaker-udop-classification-policy"
  role = aws_iam_role.classification_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = var.classification_endpoint_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*",
          "${local.working_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.input_bucket_arn,
          local.output_bucket_arn,
          local.working_bucket_arn
        ]
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
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

# Classification Function AppSync Policy (conditional)
resource "aws_iam_role_policy" "classification_function_appsync_policy" {
  for_each = var.enable_api ? { "appsync" = true } : {}

  name = "${local.name_prefix}-sagemaker-udop-classification-appsync-policy"
  role = aws_iam_role.classification_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = [
          "${var.api_arn}/types/Query/*",
          "${var.api_arn}/types/Mutation/*",
          "${var.api_arn}/types/Subscription/*"
        ]
      }
    ]
  })
}

# Extraction Function Role
resource "aws_iam_role" "extraction_function_role" {
  name = "${local.name_prefix}-sagemaker-udop-extraction-role"

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

resource "aws_iam_role_policy_attachment" "extraction_function_basic_execution" {
  role       = aws_iam_role.extraction_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "extraction_function_vpc_access" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.extraction_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "extraction_function_policy" {
  name = "${local.name_prefix}-sagemaker-udop-extraction-policy"
  role = aws_iam_role.extraction_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*",
          "${local.working_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.input_bucket_arn,
          local.output_bucket_arn,
          local.working_bucket_arn
        ]
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
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
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
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

# Extraction Function AppSync Policy (conditional)
resource "aws_iam_role_policy" "extraction_function_appsync_policy" {
  for_each = var.enable_api ? { "appsync" = true } : {}

  name = "${local.name_prefix}-sagemaker-udop-extraction-appsync-policy"
  role = aws_iam_role.extraction_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = [
          "${var.api_arn}/types/Query/*",
          "${var.api_arn}/types/Mutation/*",
          "${var.api_arn}/types/Subscription/*"
        ]
      }
    ]
  })
}

# Process Results Function Role
resource "aws_iam_role" "process_results_function_role" {
  name = "${local.name_prefix}-results-role"

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

resource "aws_iam_role_policy_attachment" "process_results_function_basic_execution" {
  role       = aws_iam_role.process_results_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "process_results_function_vpc_access" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.process_results_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "process_results_function_policy" {
  name = "${local.name_prefix}-sagemaker-udop-process-results-policy"
  role = aws_iam_role.process_results_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*",
          "${local.working_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.input_bucket_arn,
          local.output_bucket_arn,
          local.working_bucket_arn
        ]
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
          local.tracking_table_arn
        ]
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
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

# Process Results Function AppSync Policy (conditional)
resource "aws_iam_role_policy" "process_results_function_appsync_policy" {
  for_each = var.enable_api ? { "appsync" = true } : {}

  name = "${local.name_prefix}-sagemaker-udop-process-results-appsync-policy"
  role = aws_iam_role.process_results_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = [
          "${var.api_arn}/types/Query/*",
          "${var.api_arn}/types/Mutation/*",
          "${var.api_arn}/types/Subscription/*"
        ]
      }
    ]
  })
}

# Summarization Function Role
resource "aws_iam_role" "summarization_function_role" {
  name = "${local.name_prefix}-role"

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

resource "aws_iam_role_policy_attachment" "summarization_function_basic_execution" {
  role       = aws_iam_role.summarization_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "summarization_function_vpc_access" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.summarization_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "summarization_function_policy" {
  name = "${local.name_prefix}-sagemaker-udop-summarization-policy"
  role = aws_iam_role.summarization_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
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
        Resource = [
          "${local.input_bucket_arn}/*",
          "${local.output_bucket_arn}/*",
          "${local.working_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.input_bucket_arn,
          local.output_bucket_arn,
          local.working_bucket_arn
        ]
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
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
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
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

# Summarization Function AppSync Policy (conditional)
resource "aws_iam_role_policy" "summarization_function_appsync_policy" {
  for_each = var.enable_api ? { "appsync" = true } : {}

  name = "${local.name_prefix}-sagemaker-udop-summarization-appsync-policy"
  role = aws_iam_role.summarization_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = [
          "${var.api_arn}/types/Query/*",
          "${var.api_arn}/types/Mutation/*",
          "${var.api_arn}/types/Subscription/*"
        ]
      }
    ]
  })
}

# Assessment Lambda Role (always deployed, controlled by configuration)
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
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
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
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
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
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          local.configuration_table_arn,
          "${local.configuration_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.assessment_model_id}"
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
  })
}

# Add AppSync permissions if API is provided
resource "aws_iam_role_policy" "assessment_lambda_appsync" {
  for_each = var.enable_api ? { "appsync" = true } : {}

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
        Resource = "${var.api_arn}/types/Mutation/*"
      }
    ]
  })
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_role_policy" "assessment_lambda_kms" {
  name = "${local.name_prefix}-assessment-lambda-kms-policy"
  role = aws_iam_role.assessment_lambda.id

  policy = var.encryption_key_arn != null ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.encryption_key_arn != null ? var.encryption_key_arn : "*"
      }
    ]
    }) : jsonencode({
    Version   = "2012-10-17"
    Statement = []
  })
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "assessment_lambda_vpc" {
  count = length(local.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.assessment_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ocr_function_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.ocr_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "classification_function_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.classification_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "extraction_function_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.extraction_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "process_results_function_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.process_results_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "summarization_function_vpc" {
  count      = var.summarization_model_id != null && length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.summarization_function_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
