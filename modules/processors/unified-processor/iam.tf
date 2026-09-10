# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM Roles and Policies for Bedrock LLM Processor

# Plan-time guard: fail (naming the step + value) if a resolved model ID isn't a
# valid model-ID/ARN shape before it becomes an IAM ARN. Inert terraform_data.
resource "terraform_data" "bedrock_model_id_validation" {
  input = local.bedrock_step_model_ids

  lifecycle {
    precondition {
      condition     = length(local.bedrock_invalid_model_ids) == 0
      error_message = "Invalid Bedrock model ID(s) resolved for one or more steps (step=value): ${join(", ", local.bedrock_invalid_model_ids)}. Each must be a full ARN or a Bedrock model / inference-profile ID (optional geo prefix us|eu|apac|ca|sa|global, then provider.model)."
    }
  }
}

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
          aws_lambda_function.pipeline_hooks_dispatcher.arn,
          var.is_summarization_enabled ? aws_lambda_function.summarization[0].arn : "",
          aws_lambda_function.assessment.arn,
          var.evaluation_enabled && var.evaluation_baseline_bucket_arn != null ? aws_lambda_function.evaluation_function[0].arn : "",
          var.enable_rule_validation ? aws_lambda_function.rule_validation_function[0].arn : "",
          var.enable_rule_validation ? aws_lambda_function.rule_validation_orchestration_function[0].arn : "",
          # BDA branch functions, always deployed (count = 1); the runtime
          # RouteByProcessingMode choice decides whether they execute.
          aws_lambda_function.bda_invoke[0].arn,
          aws_lambda_function.bda_process_results[0].arn
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

# Hook inference Lambda permissions: grant Step Functions InvokeFunction on the
# configured hook ARNs (routing stored in DynamoDB config model_lambda_hook_arn).
locals {
  hook_function_names = compact([
    var.lambda_hook_ocr,
    var.lambda_hook_classification,
    var.lambda_hook_extraction,
    var.lambda_hook_assessment,
    var.lambda_hook_summarization,
  ])
  hook_function_arns = [
    for name in local.hook_function_names :
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${name}"
  ]

  # Per-step Lambda roles that may invoke a LambdaHook at runtime; summarization
  # only when its conditional role exists.
  hook_inference_role_ids = var.enable_hook_inference ? merge(
    {
      ocr            = aws_iam_role.ocr_lambda.id
      classification = aws_iam_role.classification_lambda.id
      extraction     = aws_iam_role.extraction_lambda.id
      assessment     = aws_iam_role.assessment_lambda.id
    },
    var.is_summarization_enabled ? {
      summarization = aws_iam_role.summarization_lambda[0].id
    } : {}
  ) : {}
}

resource "aws_iam_role_policy" "state_machine_hook_inference" {
  count = var.enable_hook_inference ? 1 : 0
  name  = "${local.name_prefix}-state-machine-hook-inference-policy"
  role  = aws_iam_role.state_machine.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = local.hook_function_arns
      }
    ]
  })
}

# The hook is invoked at runtime by each per-step Lambda, not just Step
# Functions, so grant each step's role InvokeFunction on the hook ARN(s).
# for_each keys are static so the gate stays plan-time-known.
resource "aws_iam_role_policy" "lambda_hook_inference" {
  for_each = local.hook_inference_role_ids

  name = "${local.name_prefix}-${each.key}-hook-inference-policy"
  role = each.value

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = local.hook_function_arns
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
        # Textract has no resource-level permissions
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
        Resource = [
          local.configuration_table_arn,
          # v0.6 backend workers write document status to the tracking table
          # directly (no AppSync), so this grant is unconditional — the stale
          # var.enable_api gate left OCR unable to UpdateItem when the API is on.
          local.tracking_table_arn,
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
        # PutMetricData needs wildcard, constrained by namespace condition
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

# SageMaker classification backend: allow the classification Lambda to invoke
# the UDOP endpoint directly (idp_common's native classify_page_sagemaker path).
resource "aws_iam_role_policy" "classification_lambda_sagemaker" {
  # Gate on the plan-time-known backend toggle only. When the backend is
  # "sagemaker" the endpoint ARN is required (enforced by the root module
  # validation), so it is always non-null here. Referencing the ARN itself in
  # count breaks plan when it comes from a not-yet-created endpoint (the value
  # is unknown until apply, and count cannot consume an unknown value).
  count = var.classification_backend == "sagemaker" ? 1 : 0
  name  = "${local.name_prefix}-classification-lambda-sagemaker-policy"
  role  = aws_iam_role.classification_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sagemaker:InvokeEndpoint"]
        Resource = var.classification_sagemaker_endpoint_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "classification_lambda" {
  name = "${local.name_prefix}-classification-lambda-policy"
  role = aws_iam_role.classification_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Foundation model permissions (always included)
      # OpenAI GPT-5.x (bedrock-mantle) permissions
      [local.bedrock_mantle_statement],
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
      # OpenAI GPT-5.x (bedrock-mantle) permissions
      [local.bedrock_mantle_statement],
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
        # Configuration table always needed (process_results reads config)
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
      ], [{
        # Unconditional: v0.6 workers write document status to the tracking
        # table directly regardless of the API (stale var.enable_api gate removed).
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
      # OpenAI GPT-5.x (bedrock-mantle) permissions
      [local.bedrock_mantle_statement],
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
      # DynamoDB tracking table permissions. Unconditional: v0.6 workers write
      # document status directly regardless of the API (stale var.enable_api gate removed).
      [{
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
      # OpenAI GPT-5.x (bedrock-mantle) permissions
      [local.bedrock_mantle_statement],
      # Foundation-model grant from the shared transform. No statement when no
      # model resolves (replaces a legacy un-stripped var.assessment_model_id ARN).
      local.bedrock_model_permissions.assessment != null ? [{
        Effect   = local.bedrock_model_permissions.assessment.foundation_statement.effect
        Action   = local.bedrock_model_permissions.assessment.foundation_statement.actions
        Resource = local.bedrock_model_permissions.assessment.foundation_statement.resources
      }] : [],
      # Inference profile permissions (conditional)
      local.bedrock_model_permissions.assessment != null && local.bedrock_model_permissions.assessment.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.assessment.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.assessment.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.assessment.inference_profile_statement.resources
      }] : [],
      # Escalation model the assessment Lambda invokes on low-confidence sections
      # (extraction.confidence.escalation_model). Distinct from the primary model.
      local.bedrock_model_permissions.assessment_escalation != null ? [{
        Effect   = local.bedrock_model_permissions.assessment_escalation.foundation_statement.effect
        Action   = local.bedrock_model_permissions.assessment_escalation.foundation_statement.actions
        Resource = local.bedrock_model_permissions.assessment_escalation.foundation_statement.resources
      }] : [],
      local.bedrock_model_permissions.assessment_escalation != null && local.bedrock_model_permissions.assessment_escalation.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.assessment_escalation.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.assessment_escalation.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.assessment_escalation.inference_profile_statement.resources
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

# Evaluation Lambda IAM Role
resource "aws_iam_role" "evaluation_lambda" {
  count = var.evaluation_enabled ? 1 : 0

  name = "${local.name_prefix}-evaluation-lambda-role"

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

resource "aws_iam_role_policy" "evaluation_lambda" {
  count = var.evaluation_enabled ? 1 : 0

  name = "${local.name_prefix}-evaluation-lambda-policy"
  role = aws_iam_role.evaluation_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.evaluation_baseline_bucket_arn, "${var.evaluation_baseline_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [local.output_bucket_arn, "${local.output_bucket_arn}/*", local.working_bucket_arn, "${local.working_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
        Resource = [local.tracking_table_arn, "${local.tracking_table_arn}/index/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = [local.configuration_table_arn, "${local.configuration_table_arn}/index/*"]
      },
      # OpenAI GPT-5.x (bedrock-mantle) permissions
      local.bedrock_mantle_statement,
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:GetInferenceProfile"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:application-inference-profile/*"
        ]
      },
      {
        Effect    = "Allow"
        Action    = ["cloudwatch:PutMetricData"]
        Resource  = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = local.metric_namespace } }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "evaluation_lambda_vpc" {
  count = var.evaluation_enabled && length(local.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.evaluation_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "evaluation_lambda_kms" {
  count = var.evaluation_enabled ? 1 : 0

  role       = aws_iam_role.evaluation_lambda[0].name
  policy_arn = aws_iam_policy.kms_policy.arn
}

# Add AppSync permissions if API is provided (evaluation Lambda calls
# `document_service.update_document` to publish status updates)
resource "aws_iam_role_policy" "evaluation_lambda_appsync" {
  count = var.evaluation_enabled && var.enable_api ? 1 : 0

  name = "${local.name_prefix}-evaluation-lambda-appsync-policy"
  role = aws_iam_role.evaluation_lambda[0].id

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
