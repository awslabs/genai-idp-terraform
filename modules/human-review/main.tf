# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}

locals {
  # Extract bucket name from ARN
  output_bucket_name = element(split(":", var.output_bucket_arn), 5)

  # Generate unique suffix for resource names
  suffix = random_string.suffix.result
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create Cognito User Pool Client for A2I
resource "aws_cognito_user_pool_client" "a2i_client" {
  name                                 = "${var.name_prefix}-a2i-client-${local.suffix}"
  user_pool_id                         = var.user_pool_id
  generate_secret                      = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = ["https://a2i.aws.amazon.com/callback"]
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

# IAM role for A2I Flow Definition
resource "aws_iam_role" "a2i_flow_definition_role" {
  name = "${var.name_prefix}-a2i-flow-definition-role-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "A2IFlowDefinitionAccess"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = [
            var.output_bucket_arn,
            "${var.output_bucket_arn}/*"
          ]
        },
      ]
    })
  }

  dynamic "inline_policy" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      name = "KMSAccess"
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
            Resource = [var.encryption_key_arn]
          }
        ]
      })
    }
  }

  tags = var.tags
}

# Attach SageMaker policy to A2I Flow Definition role
resource "aws_iam_role_policy_attachment" "a2i_flow_definition_sagemaker_policy" {
  role       = aws_iam_role.a2i_flow_definition_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Create Cognito Updater Function
module "cognito_updater_function" {
  source = "./functions/cognito-updater"

  name_prefix         = "${var.name_prefix}-cognito-updater"
  user_pool_id        = var.user_pool_id
  user_pool_client_id = aws_cognito_user_pool_client.a2i_client.id
  workteam_name       = var.workteam_name

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_tracing_mode  = var.lambda_tracing_mode

  tags = var.tags
}

# Create A2I Resources Function
module "create_a2i_resources_function" {
  source = "./functions/create-a2i-resources"

  name_prefix              = "${var.name_prefix}-create-a2i-resources"
  workteam_arn             = var.private_workforce_arn
  flow_definition_role_arn = aws_iam_role.a2i_flow_definition_role.arn
  output_bucket_arn        = var.output_bucket_arn
  output_bucket_name       = local.output_bucket_name

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_tracing_mode  = var.lambda_tracing_mode

  tags = var.tags
}

# Create Get Workforce URL Function
module "get_workforce_url_function" {
  source = "./functions/get-workforce-url"

  name_prefix           = "${var.name_prefix}-get-workforce-url"
  workteam_name         = var.workteam_name
  private_workforce_arn = var.private_workforce_arn

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_tracing_mode  = var.lambda_tracing_mode

  tags = var.tags
}

# Create custom resources to trigger the functions
resource "null_resource" "cognito_updater_trigger" {
  triggers = {
    function_arn = module.cognito_updater_function.function_arn
    source_hash  = module.cognito_updater_function.source_hash
  }

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.cognito_updater_function.function_name} --payload '{}' /dev/null"
  }

  depends_on = [
    aws_cognito_user_pool_client.a2i_client
  ]
}

resource "null_resource" "a2i_resources_trigger" {
  triggers = {
    function_arn = module.create_a2i_resources_function.function_arn
    source_hash  = module.create_a2i_resources_function.source_hash
  }

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.create_a2i_resources_function.function_name} --payload '{\"StackName\":\"${var.stack_name}\"}' /dev/null"
  }

  depends_on = [
    null_resource.cognito_updater_trigger
  ]
}

resource "null_resource" "get_workforce_url_trigger" {
  triggers = {
    function_arn = module.get_workforce_url_function.function_arn
    source_hash  = module.get_workforce_url_function.source_hash
  }

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.get_workforce_url_function.function_name} --payload '{\"WorkteamName\":\"${var.workteam_name}\",\"PrivateWorkforceArn\":\"${var.private_workforce_arn}\"}' /dev/null"
  }

  depends_on = [
    null_resource.a2i_resources_trigger
  ]
}

# SSM Parameter to store workforce portal URL
resource "aws_ssm_parameter" "workforce_portal_url" {
  name  = "/${var.name_prefix}/human-review/workforce-portal-url"
  type  = "String"
  value = "placeholder" # Will be updated by get_workforce_url_function

  tags = var.tags
}

# SSM Parameter to store labeling console URL
resource "aws_ssm_parameter" "labeling_console_url" {
  name  = "/${var.name_prefix}/human-review/labeling-console-url"
  type  = "String"
  value = "placeholder" # Will be updated by get_workforce_url_function

  tags = var.tags
}
