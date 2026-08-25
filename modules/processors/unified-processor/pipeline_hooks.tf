# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Pipeline Hooks Dispatcher
#
# The dispatcher Lambda understands two families of extension point:
#
#   * six per-step points, configured as `<step>.postHook` lists — postOcr,
#     postClassification, postExtraction, postAssessment, postRuleValidation,
#     postSummarization;
#   * two FLAT points added in IDP v0.6, configured as standalone top-level
#     config sections rather than lists — `preprocessing` (runs FIRST, before
#     the BDA/pipeline routing decision) and `postprocessing` (runs LAST, after
#     evaluation, on the shared tail).
#
# It reads the active configuration version from the ConfigurationTable and
# fans out to the registered hook Lambdas. Inert by default: with no hook
# configured the dispatcher returns after a single config read and the pipeline
# is unchanged. Mirrors upstream IDP v0.6.4 (patterns/unified).
#
# NOTE: this workflow's state machine (main.tf) wires only FIVE of the six
# points — postOcr, postClassification, postExtraction, postAssessment,
# postSummarization. `postRuleValidation` is intentionally NOT wired because
# the Terraform-authored unified workflow has no rule-validation state to hang
# it on (upstream's ASL has RuleValidation -> RuleValidationOrchestration ->
# PostRuleValidationHook; those states are not ported here). If the
# rule-validation step is added to main.tf, wire its postRuleValidation hook
# the same way as the other five.

data "archive_file" "pipeline_hooks_dispatcher" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/unified/src/pipeline_hooks_function"
  output_path = "${path.module}/pipeline_hooks_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "pipeline_hooks_dispatcher" {
  name = "${local.name_prefix}-pipeline-hooks-dispatcher-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "pipeline_hooks_dispatcher_basic" {
  role       = aws_iam_role.pipeline_hooks_dispatcher.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "pipeline_hooks_dispatcher_vpc" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.pipeline_hooks_dispatcher.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "pipeline_hooks_dispatcher" {
  name = "${local.name_prefix}-pipeline-hooks-dispatcher-policy"
  role = aws_iam_role.pipeline_hooks_dispatcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Read the active configuration version and its inline `<step>.postHook`
        # lists. GetItem on any Config#* row plus Scan to find IsActive=true.
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:Scan"]
          Resource = local.configuration_table_arn
        },
        # Status-only write: flip the doc row to PREPROCESSING while a
        # preprocessing hook runs (UI step visibility; best-effort).
        {
          Effect   = "Allow"
          Action   = ["dynamodb:UpdateItem"]
          Resource = local.tracking_table_arn
        },
        # Document mutation: when a hook returns an INLINE updated document
        # dict, the dispatcher spills it to the working bucket in the same
        # compressed-wrapper shape the step Lambdas use, so the next step's
        # Document.load_document() resolves it normally. PutObject only — the
        # dispatcher never reads documents back, so a hook that needs to READ
        # the document uses its own role.
        {
          Effect   = "Allow"
          Action   = "s3:PutObject"
          Resource = "${local.working_bucket_arn}/compressed_documents/*"
        },
        # Two parallel allow paths for hook Lambdas (fail closed otherwise):
        #   1. Tag-based ABAC for vertical-product packs (idp:feature-id tag).
        #   2. Name-prefix GENAIIDP-* for admin-managed hook Lambdas.
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:*"
          Condition = {
            StringLike = { "aws:ResourceTag/idp:feature-id" = "*" }
          }
        },
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:GENAIIDP-*"
        }
      ],
      var.encryption_key_arn != null ? [{
        Effect = "Allow"
        # Encrypt/GenerateDataKey are needed to WRITE the compressed-document
        # object above; the working bucket is encrypted with the
        # customer-managed key.
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = var.encryption_key_arn
      }] : []
    )
  })
}

resource "aws_lambda_function" "pipeline_hooks_dispatcher" {
  architectures = [var.lambda_architecture]
  function_name = "${local.name_prefix}-pipeline-hooks-dispatcher"
  role          = aws_iam_role.pipeline_hooks_dispatcher.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  # Hooks are invoked synchronously (RequestResponse) through the dispatcher,
  # so its timeout must cover the LONGEST hook it fronts — upstream budgets up
  # to ~890s for the PII-redaction preprocessing hook's multi-page
  # Textract+vision passes. 900 is the Lambda maximum, and matches upstream
  # (patterns/unified/template.yaml PipelineHooksDispatcherFunction). The
  # dispatcher's own boto3 lambda client raises read_timeout to match.
  timeout     = 900
  memory_size = 256

  filename         = data.archive_file.pipeline_hooks_dispatcher.output_path
  source_code_hash = data.archive_file.pipeline_hooks_dispatcher.output_base64sha256

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = local.log_level
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      # Lets the dispatcher surface PREPROCESSING as the document's visible
      # status while a preprocessing hook runs (best-effort, cosmetic).
      TRACKING_TABLE = local.tracking_table_name
      # Destination for a hook-returned INLINE updated document, spilled to S3
      # as a compressed reference for the next step. Unused when hooks are
      # read-only or return their own compressed reference.
      WORKING_BUCKET = local.working_bucket_name
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "pipeline_hooks_dispatcher" {
  name              = "/aws/lambda/${aws_lambda_function.pipeline_hooks_dispatcher.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = local.common_tags
}
