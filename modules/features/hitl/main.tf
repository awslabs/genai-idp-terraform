# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # HITL Feature Submodule
 *
 * Minimal feature-plugin submodule for Human-In-The-Loop (HITL) review.
 *
 * In v0.5.12 the HITL *gate* runs inline in the unified state machine
 * (`CheckHITLRequired` -> `MarkHITLPending`, async); the only interactive piece
 * is the `complete_section_review` Lambda (claim / release / skip / complete a
 * section review), which physically lives in `modules/processing-environment-api`.
 *
 * This submodule therefore emits a MINIMAL feature-plugin contract — the
 * `complete_section_review` resolver definitions plus the IAM statements and
 * environment wiring those resolvers/Lambda need — for the API module to
 * compose via its `enabled_feature_contracts` `for_each` mechanism. It mirrors
 * the CDK accelerator's `api.enable(feature)` composition. It does not itself
 * create the Lambda or AppSync data source; the API module owns those.
 */

locals {
  # ---------------------------------------------------------------------------
  # Resolvers
  # ---------------------------------------------------------------------------
  # The four HITL mutations all front the same `complete_section_review` Lambda
  # data source, mirroring hitl.tf in processing-environment-api. Each entry
  # supplies the GraphQL type/field and the data source name; request/response
  # templates use the standard Lambda Invoke/passthrough VTL, matching the
  # default the API module's feature-resolver composition falls back to.
  invoke_request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  invoke_response_template = "$util.toJson($context.result)"

  hitl_resolvers = {
    completeSectionReview = {
      type              = "Mutation"
      field             = "completeSectionReview"
      data_source       = var.data_source_name
      request_template  = local.invoke_request_template
      response_template = local.invoke_response_template
    }
    claimReview = {
      type              = "Mutation"
      field             = "claimReview"
      data_source       = var.data_source_name
      request_template  = local.invoke_request_template
      response_template = local.invoke_response_template
    }
    releaseReview = {
      type              = "Mutation"
      field             = "releaseReview"
      data_source       = var.data_source_name
      request_template  = local.invoke_request_template
      response_template = local.invoke_response_template
    }
    skipAllSectionsReview = {
      type              = "Mutation"
      field             = "skipAllSectionsReview"
      data_source       = var.data_source_name
      request_template  = local.invoke_request_template
      response_template = local.invoke_response_template
    }
  }

  # ---------------------------------------------------------------------------
  # IAM statements
  # ---------------------------------------------------------------------------
  # Mirrors the `complete_section_review` execution-role policy in hitl.tf:
  # tracking-table CRUD, document-bucket read/write, optional SQS send for the
  # reprocessing trigger, optional KMS, plus the AppSync lambda:InvokeFunction
  # permission. Optional statements drop out cleanly when their input is null.
  hitl_iam_statements = concat(
    var.tracking_table_arn != null ? [
      {
        Sid    = "HitlTrackingTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = [
          var.tracking_table_arn,
          "${var.tracking_table_arn}/index/*"
        ]
      }
    ] : [],
    length(local.document_bucket_resources) > 0 ? [
      {
        Sid      = "HitlDocumentBucketAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = local.document_bucket_resources
      }
    ] : [],
    var.document_queue_arn != null ? [
      {
        Sid      = "HitlReprocessingQueueSend"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = var.document_queue_arn
      }
    ] : [],
    var.encryption_key_arn != null ? [
      {
        Sid      = "HitlKmsAccess"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.encryption_key_arn
      }
    ] : [],
    var.lambda_function_arn != null ? [
      {
        Sid      = "HitlInvokeCompleteSectionReview"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = var.lambda_function_arn
      }
    ] : [],
  )

  # S3 resource list (bucket + objects) for each non-null document bucket.
  document_bucket_resources = compact(flatten([
    var.output_bucket_arn != null ? [var.output_bucket_arn, "${var.output_bucket_arn}/*"] : [],
    var.working_bucket_arn != null ? [var.working_bucket_arn, "${var.working_bucket_arn}/*"] : [],
    var.input_bucket_arn != null ? [var.input_bucket_arn, "${var.input_bucket_arn}/*"] : [],
  ]))

  # ---------------------------------------------------------------------------
  # Environment wiring
  # ---------------------------------------------------------------------------
  # Mirrors the `complete_section_review` Lambda env block in hitl.tf. Empty
  # strings preserve the "set but unused" semantics the upstream Lambda expects.
  hitl_environment = {
    TRACKING_TABLE_NAME = var.tracking_table_name != null ? var.tracking_table_name : ""
    OUTPUT_BUCKET       = var.output_bucket_name != null ? var.output_bucket_name : ""
    INPUT_BUCKET        = var.input_bucket_name != null ? var.input_bucket_name : ""
    WORKING_BUCKET      = var.working_bucket_name != null ? var.working_bucket_name : ""
    QUEUE_URL           = var.document_queue_url != null ? var.document_queue_url : ""
  }
}
