# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature Platform — installable feature registry + AppSync operations.
# Mirrors upstream IDP v0.5.16 feature-platform/main-stack-extensions/template.yaml.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  source_root = "${path.module}/../../../sources/feature-platform/main-stack-extensions/lambdas"

  installed_features_table = "${var.name_prefix}-installed-features"

  # Per-Lambda environment. All nine share FeaturePlatformLambdaRole.
  functions = {
    list_installed_features = {
      INSTALLED_FEATURES_TABLE = local.installed_features_table
      CONFIGURATION_BUCKET     = var.configuration_bucket_name
      CATALOG_KEY              = var.catalog_key
      LOG_LEVEL                = var.log_level
    }
    list_catalog_features = {
      CONFIGURATION_BUCKET = var.configuration_bucket_name
      CATALOG_KEY          = var.catalog_key
      LOG_LEVEL            = var.log_level
    }
    register_feature = {
      INSTALLED_FEATURES_TABLE = local.installed_features_table
      LOG_LEVEL                = var.log_level
    }
    get_feature_launch_url = {
      INSTALLED_FEATURES_TABLE                         = local.installed_features_table
      CONFIGURATION_BUCKET                             = var.configuration_bucket_name
      CATALOG_KEY                                      = var.catalog_key
      ARTIFACT_REGION                                  = var.artifact_region
      DEFAULT_CUSTOMER_IDENTIFIER                      = var.default_customer_identifier
      AWS_ENDPOINT_URL_MARKETPLACE_ENTITLEMENT_SERVICE = var.simulator_entitlement_endpoint
      MAIN_STACK_NAME                                  = var.main_stack_name
      ADMIN_GROUP                                      = var.admin_group_name
      LOG_LEVEL                                        = var.log_level
    }
    check_feature_entitlement = {
      INSTALLED_FEATURES_TABLE                         = local.installed_features_table
      DEFAULT_CUSTOMER_IDENTIFIER                      = var.default_customer_identifier
      DEFAULT_BUYER_ACCOUNT_ID                         = var.default_buyer_account_id
      SIMULATOR_SOURCE_TAG                             = var.subscription_mode
      AWS_ENDPOINT_URL_MARKETPLACE_ENTITLEMENT_SERVICE = var.simulator_entitlement_endpoint
      CONFIGURATION_BUCKET                             = var.configuration_bucket_name
      CATALOG_KEY                                      = var.catalog_key
      LOG_LEVEL                                        = var.log_level
    }
    subscribe_feature = {
      SIMULATOR_ADMIN_ENDPOINT    = var.simulator_entitlement_endpoint
      INSTALLED_FEATURES_TABLE    = local.installed_features_table
      FEATURE_OFFER_ID_MAP        = var.feature_offer_id_map
      DEFAULT_CUSTOMER_IDENTIFIER = var.default_customer_identifier
      DEFAULT_BUYER_ACCOUNT_ID    = var.default_buyer_account_id
      ADMIN_GROUP                 = var.admin_group_name
      SIMULATOR_SOURCE_TAG        = var.subscription_mode
      LOG_LEVEL                   = var.log_level
    }
    unsubscribe_feature = {
      SIMULATOR_ADMIN_ENDPOINT                         = var.simulator_entitlement_endpoint
      INSTALLED_FEATURES_TABLE                         = local.installed_features_table
      DEFAULT_CUSTOMER_IDENTIFIER                      = var.default_customer_identifier
      DEFAULT_BUYER_ACCOUNT_ID                         = var.default_buyer_account_id
      AWS_ENDPOINT_URL_MARKETPLACE_ENTITLEMENT_SERVICE = var.simulator_entitlement_endpoint
      ADMIN_GROUP                                      = var.admin_group_name
      SIMULATOR_SOURCE_TAG                             = var.subscription_mode
      LOG_LEVEL                                        = var.log_level
    }
    register_feature_hooks = {
      CONFIGURATION_TABLE = var.configuration_table_name
      LOG_LEVEL           = var.log_level
    }
    apply_feature_config_preset = {
      CONFIGURATION_TABLE = var.configuration_table_name
      LOG_LEVEL           = var.log_level
    }
  }

  # API field -> backing function (some functions serve two fields). `type` is
  # retained for documentation only: the REST dispatcher routes purely on field
  # name, so Query vs Mutation no longer changes the wiring.
  resolvers = {
    listInstalledFeatures     = { type = "Query", fn = "list_installed_features" }
    listCatalogFeatures       = { type = "Query", fn = "list_catalog_features" }
    checkFeatureEntitlement   = { type = "Query", fn = "check_feature_entitlement" }
    getFeatureLaunchUrl       = { type = "Query", fn = "get_feature_launch_url" }
    registerFeature           = { type = "Mutation", fn = "register_feature" }
    unregisterFeature         = { type = "Mutation", fn = "register_feature" }
    subscribeFeature          = { type = "Mutation", fn = "subscribe_feature" }
    unsubscribeFeature        = { type = "Mutation", fn = "unsubscribe_feature" }
    registerFeatureHooks      = { type = "Mutation", fn = "register_feature_hooks" }
    unregisterFeatureHooks    = { type = "Mutation", fn = "register_feature_hooks" }
    applyFeatureConfigPreset  = { type = "Mutation", fn = "apply_feature_config_preset" }
    removeFeatureConfigPreset = { type = "Mutation", fn = "apply_feature_config_preset" }
  }
}

###########################################################################
# Installed feature registry
###########################################################################
resource "aws_dynamodb_table" "installed_features" {
  name         = local.installed_features_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "featureId"

  attribute {
    name = "featureId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.encryption_key_arn
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = var.tags
}

###########################################################################
# Shared Lambda execution role for all nine feature-platform Lambdas
###########################################################################
resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-feature-platform-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.name_prefix}-feature-platform-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"]
          Resource = [aws_dynamodb_table.installed_features.arn, "${aws_dynamodb_table.installed_features.arn}/index/*"]
        },
        # registerFeatureHooks / applyFeatureConfigPreset write the host ConfigurationTable.
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan"]
          Resource = var.configuration_table_arn
        },
        # Marketplace entitlement checks.
        {
          Effect   = "Allow"
          Action   = ["aws-marketplace:GetEntitlements"]
          Resource = "*"
        },
        # getFeatureLaunchUrl resolves an installed feature stack ARN.
        {
          Effect   = "Allow"
          Action   = ["cloudformation:DescribeStacks"]
          Resource = "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:stack/${var.main_stack_name}-feature-*/*"
        },
        # Read the feature catalog (catalog.json) from the configuration bucket.
        {
          Effect = "Allow"
          Action = ["s3:GetObject"]
          Resource = var.configuration_bucket_name != "" ? [
            "arn:${data.aws_partition.current.partition}:s3:::${var.configuration_bucket_name}/*"
          ] : ["arn:${data.aws_partition.current.partition}:s3:::placeholder-fp-bucket/*"]
        }
      ],
      var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.encryption_key_arn
      }] : [],
      length(var.seller_bucket_object_arns) > 0 ? [{
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = var.seller_bucket_object_arns
      }] : []
    )
  })
}

###########################################################################
# Nine Lambdas
###########################################################################
data "archive_file" "feature" {
  for_each    = local.functions
  type        = "zip"
  source_dir  = "${local.source_root}/${each.key}"
  output_path = "${path.module}/fp_${each.key}.zip"
}

resource "aws_lambda_function" "feature" {
  architectures = [var.lambda_architecture]
  for_each      = local.functions

  function_name = "${var.name_prefix}-fp-${replace(each.key, "_", "-")}"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.feature[each.key].output_path
  source_code_hash = data.archive_file.feature[each.key].output_base64sha256

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = each.value
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "feature" {
  for_each          = local.functions
  name              = "/aws/lambda/${aws_lambda_function.feature[each.key].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

###########################################################################
# Transport (IDP v0.6.4): REST dispatcher, not AppSync
#
# This module used to provision an AppSync service role, one Lambda data source
# per function, and one resolver per field, all against `var.graphql_api_id`.
# Upstream deleted AppSync in v0.6.0, so all of that is gone: the module now
# only publishes a field -> Lambda ARN map (see the `field_functions` output),
# which `processing-environment-api` merges into the REST dispatcher's
# field-function map. The dispatcher invokes these Lambdas directly with an
# AppSync-shaped event, so no service role and no per-field resource is needed.
#
# Removing `graphql_api_id` also removes this module's only dependency on the
# API module, which is what lets the API module consume `field_functions`
# without creating a dependency cycle.
###########################################################################

###########################################################################
# WebUI bucket policy statement fragment (consumed by the main web-ui policy)
###########################################################################
resource "aws_ssm_parameter" "webui_bucket_policy_statement" {
  name        = "/${var.main_stack_name}/feature-platform/webui-bucket-policy-statement"
  description = "Policy statement fragment the main stack's WebUIBucketPolicy merges."
  type        = "String"
  value = jsonencode({
    Sid       = "AllowFeatureStackUiBundleWrites"
    Effect    = "Allow"
    Principal = { AWS = "*" }
    Action    = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    Resource  = "*"
    Condition = {
      StringEquals = { "aws:PrincipalTag/idp:feature-id" = "$${aws:PrincipalTag/idp:feature-id}" }
    }
  })

  tags = var.tags
}
