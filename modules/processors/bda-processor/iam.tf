# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # IAM Roles and Policies
 *
 * This file defines the IAM roles and policies for the BDA processor.
 */

# IAM Role for Step Functions State Machine
resource "aws_iam_role" "state_machine_role" {
  name = "${var.name}-state-machine-${random_string.suffix.result}"

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

  tags = var.tags
}

# IAM Policy for Step Functions State Machine
resource "aws_iam_policy" "state_machine_policy" {
  #checkov:skip=CKV_AWS_355:CloudWatch Logs and X-Ray require wildcard resources as log groups/streams and trace segments are created dynamically
  #checkov:skip=CKV_AWS_290:CloudWatch Logs and X-Ray require wildcard resources as log groups/streams and trace segments are created dynamically
  name        = "${var.name}-state-machine-policy-${random_string.suffix.result}"
  description = "Policy for BDA processor state machine"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect = "Allow"
        Resource = [
          aws_lambda_function.invoke_bda.arn,
          aws_lambda_function.process_results.arn,
          aws_lambda_function.summarization.arn
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach policy to state machine role
resource "aws_iam_role_policy_attachment" "state_machine_policy_attachment" {
  role       = aws_iam_role.state_machine_role.name
  policy_arn = aws_iam_policy.state_machine_policy.arn
}

# IAM Role for Invoke BDA Lambda Function
resource "aws_iam_role" "invoke_bda_role" {
  name = "${var.name}-invoke-bda-${random_string.suffix.result}"

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

  tags = var.tags
}

# IAM Policy for Invoke BDA Lambda Function
resource "aws_iam_policy" "invoke_bda_policy" {
  name        = "${var.name}-invoke-bda-policy-${random_string.suffix.result}"
  description = "Policy for BDA processor invoke BDA function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*"
        ]
        Effect = "Allow"
        Resource = [
          var.input_bucket_arn,
          "${var.input_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*",
          "s3:DeleteObject*",
          "s3:PutObject",
          "s3:PutObjectLegalHold",
          "s3:PutObjectRetention",
          "s3:PutObjectTagging",
          "s3:PutObjectVersionTagging",
          "s3:Abort*"
        ]
        Effect = "Allow"
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*",
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      }],
      # Tracking table permissions (always needed for task token tracking)
      [{
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Effect = "Allow"
        Resource = [
          var.tracking_table_arn,
          "${var.tracking_table_arn}/index/*"
        ]
      }],
      [
        {
          Action = [
            "sqs:SendMessage"
          ]
          Effect = "Allow"
          Resource = [
            aws_sqs_queue.invoke_bda_dlq.arn
          ]
        },
        {
          # CloudWatch PutMetricData requires wildcard resource but is constrained by namespace condition
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Effect   = "Allow"
          Resource = "*"
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = var.metric_namespace
            }
          }
      }]
    )
  })
}

# Attach policy to invoke BDA role
resource "aws_iam_role_policy_attachment" "invoke_bda_policy_attachment" {
  role       = aws_iam_role.invoke_bda_role.name
  policy_arn = aws_iam_policy.invoke_bda_policy.arn
}

# Attach BDA invoke policy to invoke BDA role
resource "aws_iam_role_policy_attachment" "invoke_bda_data_automation_attachment" {
  role       = aws_iam_role.invoke_bda_role.name
  policy_arn = aws_iam_policy.invoke_data_automation_project.arn
}

# IAM Role for Process Results Lambda Function
resource "aws_iam_role" "process_results_role" {
  name = "${var.name}-process-results-${random_string.suffix.result}"

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

  tags = var.tags
}

# IAM Policy for Process Results Lambda Function
resource "aws_iam_policy" "process_results_policy" {
  name        = "${var.name}-process-results-policy-${random_string.suffix.result}"
  description = "Policy for BDA processor process results function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.input_bucket_arn,
          "${var.input_bucket_arn}/*",
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = [
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      },

      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          var.configuration_table_arn,
          "${var.configuration_table_arn}/index/*"
        ]
      },
      {
        Action = [
          "appsync:GraphQL"
        ]
        Effect   = "Allow"
        Resource = var.api_arn != null ? "${var.api_arn}/types/Mutation/*" : "*"
      },
      {
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter",
          "ssm:GetParametersByPath"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "bedrock:GetDataAutomationProject",
          "bedrock:ListDataAutomationProjects",
          "bedrock:GetBlueprint",
          "bedrock:GetBlueprintRecommendation"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect = "Allow"
        Resource = [
          aws_sqs_queue.process_results_dlq.arn
        ]
      },
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      }
    ]
  })
}

# IAM Policy for Process Results Lambda Function - HITL (Human-in-the-Loop) permissions
resource "aws_iam_policy" "process_results_hitl_policy" {
  for_each = var.bda_metadata_table_arn != null ? toset(["enabled"]) : toset([])

  name        = "${var.name}-process-results-hitl-policy-${random_string.suffix.result}"
  description = "HITL permissions for BDA processor process results function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = var.bda_metadata_table_arn != null ? [
          var.bda_metadata_table_arn,
          "${var.bda_metadata_table_arn}/index/*"
        ] : []
      },
      {
        Action = [
          "sagemaker:StartHumanLoop"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:sagemaker:*:*:flow-definition/*"
      }
    ]
  })
}

# Attach policy to process results role
resource "aws_iam_role_policy_attachment" "process_results_policy_attachment" {
  role       = aws_iam_role.process_results_role.name
  policy_arn = aws_iam_policy.process_results_policy.arn
}

# Attach HITL policy to process results role
resource "aws_iam_role_policy_attachment" "process_results_hitl_policy_attachment" {
  for_each = var.bda_metadata_table_arn != null ? toset(["enabled"]) : toset([])

  role       = aws_iam_role.process_results_role.name
  policy_arn = aws_iam_policy.process_results_hitl_policy["enabled"].arn
}

# IAM Role for Summarization Lambda Function
resource "aws_iam_role" "summarization_role" {
  name = "${var.name}-summarization-${random_string.suffix.result}"

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

  tags = var.tags
}

# IAM Policy for Summarization Lambda Function
resource "aws_iam_policy" "summarization_policy" {
  name        = "${var.name}-summarization-policy-${random_string.suffix.result}"
  description = "Policy for BDA processor summarization function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.input_bucket_arn,
          "${var.input_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "dynamodb:GetItem"
        ]
        Effect   = "Allow"
        Resource = var.configuration_table_arn
      },

      {
        Action = [
          "appsync:GraphQL"
        ]
        Effect   = "Allow"
        Resource = var.api_arn != null ? "${var.api_arn}/types/Mutation/*" : "*"
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect = "Allow"
        Resource = [
          aws_sqs_queue.summarization_dlq.arn
        ]
      },
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      }
    ]
  })
}

# Attach policy to summarization role
resource "aws_iam_role_policy_attachment" "summarization_policy_attachment" {
  role       = aws_iam_role.summarization_role.name
  policy_arn = aws_iam_policy.summarization_policy.arn
}

# Add default Bedrock permissions for summarization function (regardless of model configuration)
resource "aws_iam_policy" "summarization_default_bedrock_policy" {
  #checkov:skip=CKV_AWS_355:Bedrock InvokeModel requires wildcard resource to support all foundation model formats and cross-region inference
  name        = "${var.name}-summarization-default-bedrock-policy-${random_string.suffix.result}"
  description = "Default Bedrock policy for summarization function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel*",
          "bedrock:GetFoundationModel"
        ]
        Effect   = "Allow"
        Resource = "*" # Using broader permissions to ensure all model formats are covered
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "summarization_default_bedrock_attachment" {
  role       = aws_iam_role.summarization_role.name
  policy_arn = aws_iam_policy.summarization_default_bedrock_policy.arn
}

# Add Bedrock permissions if summarization model is provided
resource "aws_iam_policy" "summarization_bedrock_policy" {
  #checkov:skip=CKV_AWS_355:Bedrock InvokeModel requires wildcard resource to support all foundation model formats and cross-region inference
  count       = var.summarization_model_id != null ? 1 : 0
  name        = "${var.name}-summarization-bedrock-policy-${random_string.suffix.result}"
  description = "Bedrock policy for summarization function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel*",
          "bedrock:GetFoundationModel"
        ]
        Effect   = "Allow"
        Resource = "*" # Using broader permissions to ensure all model formats are covered
      },
      {
        Action = [
          "bedrock:GetInferenceProfile",
          "bedrock:InvokeModel*"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}::foundation-model/${var.summarization_model_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "summarization_bedrock_attachment" {
  count      = var.summarization_model_id != null ? 1 : 0
  role       = aws_iam_role.summarization_role.name
  policy_arn = aws_iam_policy.summarization_bedrock_policy[0].arn
}

# Add guardrail permissions if summarization guardrail is provided
resource "aws_iam_policy" "summarization_guardrail_policy" {
  count       = var.summarization_guardrail != null ? 1 : 0
  name        = "${var.name}-summarization-guardrail-policy-${random_string.suffix.result}"
  description = "Guardrail policy for summarization function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Effect   = "Allow"
        Resource = var.summarization_guardrail.guardrail_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "summarization_guardrail_attachment" {
  count      = var.summarization_guardrail != null ? 1 : 0
  role       = aws_iam_role.summarization_role.name
  policy_arn = aws_iam_policy.summarization_guardrail_policy[0].arn
}

# IAM Role for BDA Completion Lambda Function
resource "aws_iam_role" "bda_completion_role" {
  name = "${var.name}-bda-completion-${random_string.suffix.result}"

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

  tags = var.tags
}

# IAM Policy for BDA Completion Lambda Function
resource "aws_iam_policy" "bda_completion_policy" {
  name        = "${var.name}-bda-completion-policy-${random_string.suffix.result}"
  description = "Policy for BDA processor completion function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },

      {
        Action = [
          "states:SendTaskSuccess",
          "states:SendTaskFailure",
          "states:SendTaskHeartbeat"
        ]
        Effect   = "Allow"
        Resource = aws_sfn_state_machine.document_processing.arn
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:DeleteItem"
        ]
        Effect = "Allow"
        Resource = [
          var.tracking_table_arn,
          "${var.tracking_table_arn}/index/*"
        ]
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.bda_completion_dlq.arn
      },
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      }
    ]
  })
}

# Attach policy to BDA completion role
resource "aws_iam_role_policy_attachment" "bda_completion_policy_attachment" {
  role       = aws_iam_role.bda_completion_role.name
  policy_arn = aws_iam_policy.bda_completion_policy.arn
}
# =============================================================================
# ADDITIONAL IAM ROLES (previously in missing_roles.tf)
# =============================================================================
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# HITL Wait Function IAM Role
resource "aws_iam_role" "hitl_wait_role" {
  name = "${var.name}-hitl-wait-${random_string.suffix.result}"

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

  tags = var.tags
}

# HITL Wait Function Policy
resource "aws_iam_policy" "hitl_wait_policy" {
  name = "${var.name}-hitl-wait-policy-${random_string.suffix.result}"

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
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.configuration_table_arn,
          var.tracking_table_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "hitl_wait_policy_attachment" {
  role       = aws_iam_role.hitl_wait_role.name
  policy_arn = aws_iam_policy.hitl_wait_policy.arn
}

resource "aws_iam_role_policy_attachment" "hitl_wait_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.hitl_wait_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

# HITL Process Function IAM Role
resource "aws_iam_role" "hitl_process_role" {
  name = "${var.name}-hitl-process-${random_string.suffix.result}"

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

  tags = var.tags
}

# HITL Process Function Policy
resource "aws_iam_policy" "hitl_process_policy" {
  name = "${var.name}-hitl-process-policy-${random_string.suffix.result}"

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
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.configuration_table_arn,
          var.tracking_table_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
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
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*",
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "hitl_process_policy_attachment" {
  role       = aws_iam_role.hitl_process_role.name
  policy_arn = aws_iam_policy.hitl_process_policy.arn
}

resource "aws_iam_role_policy_attachment" "hitl_process_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.hitl_process_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

# HITL Status Update Function IAM Role
resource "aws_iam_role" "hitl_status_update_role" {
  name = "${var.name}-hitl-status-${random_string.suffix.result}"

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

  tags = var.tags
}

# HITL Status Update Function Policy
resource "aws_iam_policy" "hitl_status_update_policy" {
  name = "${var.name}-hitl-status-update-policy-${random_string.suffix.result}"

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
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.configuration_table_arn,
          var.tracking_table_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },

    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "hitl_status_update_policy_attachment" {
  role       = aws_iam_role.hitl_status_update_role.name
  policy_arn = aws_iam_policy.hitl_status_update_policy.arn
}

resource "aws_iam_role_policy_attachment" "hitl_status_update_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.hitl_status_update_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

# IAM Role for Evaluation Lambda Function
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_role" "evaluation_role" {
#   count = var.evaluation_baseline_bucket != null ? 1 : 0
#   name  = "${var.name}-evaluation-role-${random_string.suffix.result}"
# 
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
# 
#   tags = var.tags
# }

# IAM Policy for Evaluation Lambda Function
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_policy" "evaluation_policy" {
#   count       = var.evaluation_baseline_bucket != null ? 1 : 0
#   name        = "${var.name}-evaluation-policy-${random_string.suffix.result}"
#   description = "Policy for BDA processor evaluation function"
# 
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Effect   = "Allow"
#         Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
#       },
#       {
#         Action = [
#           "s3:GetObject",
#           "s3:ListBucket"
#         ]
#         Effect = "Allow"
#         Resource = [
#           var.output_bucket_arn,
#           "${var.output_bucket_arn}/*",
#           var.evaluation_baseline_bucket.bucket_arn,
#           "${var.evaluation_baseline_bucket.bucket_arn}/*"
#         ]
#       },
#       {
#         Action = [
#           "dynamodb:GetItem"
#         ]
#         Effect = "Allow"
#         Resource = [
#           var.tracking_table_arn,
#           var.configuration_table_arn
#         ]
#       },
#       {
#         Action = [
#           "appsync:GraphQL"
#         ]
#         Effect   = "Allow"
#         Resource = var.api_arn != null ? "${var.api_arn}/types/Mutation/*" : "*"
#       },
#       {
#         Action = [
#           "sqs:SendMessage"
#         ]
#         Effect   = "Allow"
#         Resource = aws_sqs_queue.evaluation_dlq[0].arn
#       },
#       {
#         Action = [
#           "cloudwatch:PutMetricData"
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#         Condition = {
#           StringEquals = {
#             "cloudwatch:namespace" = var.metric_namespace
#           }
#         }
#       }
#     ]
#   })
# }

# Attach policy to evaluation role
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_role_policy_attachment" "evaluation_policy_attachment" {
#   count      = var.evaluation_baseline_bucket != null ? 1 : 0
#   role       = aws_iam_role.evaluation_role[0].name
#   policy_arn = aws_iam_policy.evaluation_policy[0].arn
# }

# Add Bedrock permissions for evaluation
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_policy" "evaluation_bedrock_policy" {
#   count       = var.evaluation_baseline_bucket != null && var.evaluation_model_id != null ? 1 : 0
#   name        = "${var.name}-evaluation-bedrock-policy-${random_string.suffix.result}"
#   description = "Bedrock policy for evaluation function"
# 
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "bedrock:InvokeModel"
#         ]
#         Effect   = "Allow"
#         Resource = var.evaluation_model_id
#       }
#     ]
#   })
# }

# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_role_policy_attachment" "evaluation_bedrock_attachment" {
#   count      = var.evaluation_baseline_bucket != null && var.evaluation_model_id != null ? 1 : 0
#   role       = aws_iam_role.evaluation_role[0].name
#   policy_arn = aws_iam_policy.evaluation_bedrock_policy[0].arn
# }

# Add KMS permissions if encryption key is provided
resource "aws_iam_policy" "kms_policy" {
  for_each    = toset(["enabled"])
  name        = "${var.name}-kms-policy-${random_string.suffix.result}"
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
        Resource = var.encryption_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "invoke_bda_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.invoke_bda_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

resource "aws_iam_role_policy_attachment" "process_results_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.process_results_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

resource "aws_iam_role_policy_attachment" "summarization_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.summarization_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

resource "aws_iam_role_policy_attachment" "bda_completion_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.bda_completion_role.name
  policy_arn = aws_iam_policy.kms_policy["enabled"].arn
}

# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_role_policy_attachment" "evaluation_kms_attachment" {
#   for_each   = var.evaluation_baseline_bucket != null ? toset(["enabled"]) : toset([])
#   role       = aws_iam_role.evaluation_role[0].name
#   policy_arn = aws_iam_policy.kms_policy["enabled"].arn
# }

# Add VPC permissions if VPC config is provided
resource "aws_iam_policy" "vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name        = "${var.name}-vpc-policy-${random_string.suffix.result}"
  description = "VPC policy for BDA processor functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 network interface operations for VPC Lambda - AWS service limitation requires wildcard resource
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "invoke_bda_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.invoke_bda_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "process_results_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.process_results_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "summarization_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.summarization_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "bda_completion_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.bda_completion_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_iam_role_policy_attachment" "evaluation_vpc_attachment" {
#   count      = length(var.vpc_subnet_ids) > 0 && var.evaluation_baseline_bucket != null ? 1 : 0
#   role       = aws_iam_role.evaluation_role[0].name
#   policy_arn = aws_iam_policy.vpc_policy[0].arn
# }

# VPC permissions for HITL functions
resource "aws_iam_role_policy_attachment" "hitl_wait_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.hitl_wait_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "hitl_process_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.hitl_process_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "hitl_status_update_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.hitl_status_update_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}
