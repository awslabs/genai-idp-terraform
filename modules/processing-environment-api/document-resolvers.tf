# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Document listing / versions / sample-document resolvers (IDP v0.6.4)
#
# WHY THESE ARRIVE ONLY NOW
#
# Under AppSync these operations were VTL resolvers wired straight to a DynamoDB
# data source, so the wrapper needed no Lambda for them. IDP v0.6.0 replaced the
# VTL with real Lambda resolvers, and the REST dispatcher's in-process
# `ddb_direct` module only picked up a SUBSET of the old DynamoDB-direct fields
# (`getDocument`, `listDocumentsDateHour`, `listDocumentsDateShard`, the discovery
# and agent-job fields). `listDocuments` is NOT in `ddb_direct._HANDLED`; the
# dispatcher's FIELD_ALIASES maps it onto the canonical `getDocumentCount`, which
# must resolve to ListDocumentsGSIResolverFunction.
#
# Phase 2 of this upgrade assumed listDocuments was ddb_direct-served, so these
# four Lambdas were never ported and `getDocumentCount` was absent from the
# field-function map. The dispatcher therefore fell through to its 404 branch and
# the Web UI's Document List failed on login with:
#
#   Failed to list documents (NotFound): unknown operation: listDocuments
#
# Mirrors sources/nested/api-resolvers/template.yaml:
#   ListDocumentsGSIResolverFunction        -> getDocumentCount (alias: listDocuments)
#   ListDocumentsByDateRangeResolverFunction-> listDocumentsByDateRange
#   DocumentVersionsResolverFunction        -> compareDocumentVersions
#                                              (aliases: getDocumentVersion,
#                                               listDocumentVersions,
#                                               deleteDocumentVersion)
#   GetSampleDocumentResolverFunction       -> getSampleDocumentUrl
#
# The Users-table grants are conditional on RBAC being enabled (var.users_table_name
# non-empty); the resolvers read it to scope results by the caller's allowed config
# versions, and skip that when RBAC is off.

locals {
  document_resolver_src = "${path.module}/../../sources/nested/api-resolvers/src/lambda"

  users_table_arn_prefix = "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}"

  # GetItem/Query on the RBAC Users table + its GSIs, only when RBAC is on.
  document_resolver_users_statements = var.users_table_name != "" ? [{
    Effect = "Allow"
    Action = ["dynamodb:Query", "dynamodb:GetItem"]
    Resource = [
      local.users_table_arn_prefix,
      "${local.users_table_arn_prefix}/index/*",
    ]
  }] : []

  document_resolver_kms_statements = var.encryption_key_arn != null ? [{
    Effect = "Allow"
    Action = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    Resource = [var.encryption_key_arn]
  }] : []

  document_resolvers = {
    list_documents_gsi_resolver = {
      name        = "ListDocumentsGSIResolver"
      description = "Lists documents via the TrackingTable TypeDateIndex GSI (serves listDocuments/getDocumentCount)"
      timeout     = 30
      memory      = 256
      environment = {
        TRACKING_TABLE_NAME = local.tracking_table_name != null ? local.tracking_table_name : ""
        USERS_TABLE_NAME    = var.users_table_name
      }
    }
    list_documents_range_resolver = {
      name        = "ListDocumentsByDateRangeResolver"
      description = "Lists documents by date range via GraphQL API"
      timeout     = 120
      memory      = 512
      environment = {
        TRACKING_TABLE_NAME = local.tracking_table_name != null ? local.tracking_table_name : ""
        USERS_TABLE_NAME    = var.users_table_name
      }
    }
    document_versions_resolver = {
      name        = "DocumentVersionsResolver"
      description = "Compares/lists/deletes document output versions (IDP v0.6 document versions)"
      timeout     = 60
      memory      = 512
      environment = {
        TRACKING_TABLE = local.tracking_table_name != null ? local.tracking_table_name : ""
        OUTPUT_BUCKET  = local.output_bucket_name
      }
    }
    get_sample_document_resolver = {
      name        = "GetSampleDocumentResolver"
      description = "Presigns sample documents from the configuration bucket"
      timeout     = 30
      memory      = 256
      environment = {
        CONFIGURATION_BUCKET = local.configuration_table_name != null ? "${local.api_name}-config" : ""
      }
    }
  }
}

data "archive_file" "document_resolver" {
  for_each = local.document_resolvers

  type        = "zip"
  source_dir  = "${local.document_resolver_src}/${each.key}"
  output_path = "${path.module}/.terraform-archives/${each.key}.zip"
}

resource "aws_iam_role" "document_resolver" {
  for_each = local.document_resolvers

  name = "${local.api_name}-${replace(each.key, "_", "-")}-role"

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

resource "aws_iam_role_policy_attachment" "document_resolver_basic" {
  for_each = local.document_resolvers

  role       = aws_iam_role.document_resolver[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "document_resolver_vpc" {
  for_each = var.vpc_config != null ? local.document_resolvers : {}

  role       = aws_iam_role.document_resolver[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Per-resolver least-privilege data access.
resource "aws_iam_role_policy" "document_resolver" {
  for_each = local.document_resolvers

  name = "${local.api_name}-${replace(each.key, "_", "-")}-policy"
  role = aws_iam_role.document_resolver[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # list_documents_gsi_resolver only ever Queries the TypeDateIndex GSI, so it
      # is scoped to that index rather than given table-wide CRUD.
      each.key == "list_documents_gsi_resolver" ? [{
        Effect   = "Allow"
        Action   = ["dynamodb:Query"]
        Resource = ["${var.tracking_table_arn}/index/TypeDateIndex"]
      }] : [],
      each.key == "list_documents_range_resolver" ? [{
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [var.tracking_table_arn, "${var.tracking_table_arn}/index/*"]
      }] : [],
      each.key == "document_versions_resolver" ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
          ]
          Resource = [var.tracking_table_arn, "${var.tracking_table_arn}/index/*"]
        },
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:ListBucketVersions"]
          Resource = [var.output_bucket_arn]
        },
        {
          # Version-aware: document version history pins prior runs' output bytes
          # as noncurrent object versions, so reads and deletes must name versions.
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
          ]
          Resource = ["${var.output_bucket_arn}/*"]
        },
      ] : [],
      each.key == "get_sample_document_resolver" ? [{
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:${data.aws_partition.current.partition}:s3:::${local.api_name}-config/samples/*"]
      }] : [],
      # Users-table read for RBAC scoping applies to the two listing resolvers.
      contains(["list_documents_gsi_resolver", "list_documents_range_resolver"], each.key) ? local.document_resolver_users_statements : [],
      local.document_resolver_kms_statements,
    )
  })
}

resource "aws_cloudwatch_log_group" "document_resolver" {
  for_each = local.document_resolvers

  name              = "/aws/lambda/${each.value.name}-${random_string.suffix.result}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_lambda_function" "document_resolver" {
  for_each = local.document_resolvers

  architectures = [var.lambda_architecture]
  function_name = "${each.value.name}-${random_string.suffix.result}"

  filename         = data.archive_file.document_resolver[each.key].output_path
  source_code_hash = data.archive_file.document_resolver[each.key].output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = each.value.timeout
  memory_size = each.value.memory
  role        = aws_iam_role.document_resolver[each.key].arn
  layers      = compact([var.base_layer_arn, var.idp_common_layer_arn])
  description = each.value.description

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = merge({ LOG_LEVEL = var.log_level }, each.value.environment)
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [aws_cloudwatch_log_group.document_resolver]

  tags = var.tags
}
