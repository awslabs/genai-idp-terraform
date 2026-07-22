# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# BDA branch Lambda functions. Always deployed (count = 1) so both branches are
# present on every façade; runtime routing selects the branch per document.
# Mirrors upstream template.yaml InvokeBDAFunction / BDAProcessResultsFunction /
# BDACompletionFunction. Packaged zip+layer (the engine convention), not the
# upstream Image packaging.

# Archive sources (always rendered)

data "archive_file" "bda_invoke_lambda" {
  count = 1

  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/unified/src/bda_invoke_function"
  output_path = "${path.module}/bda_invoke_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "bda_process_results_lambda" {
  count = 1

  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/unified/src/bda_processresults_function"
  output_path = "${path.module}/bda_processresults_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "bda_completion_lambda" {
  count = 1

  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/unified/src/bda_completion_function"
  output_path = "${path.module}/bda_completion_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

# BDA Invoke Function: kicks off the async BDA job and registers the Step
# Functions task token so the completion function can resume the workflow.

resource "aws_lambda_function" "bda_invoke" {
  architectures = [var.lambda_architecture]
  count         = 1

  function_name = "${local.name_prefix}-bda-invoke"
  role          = aws_iam_role.bda_invoke_lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 3008

  filename         = data.archive_file.bda_invoke_lambda[0].output_path
  source_code_hash = data.archive_file.bda_invoke_lambda[0].output_base64sha256

  layers = [var.idp_common_layer_arn != null ? var.idp_common_layer_arn : var.base_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE   = local.tracking_table_name
      METRIC_NAMESPACE = local.metric_namespace
      MAX_WORKERS      = 20
      LOG_LEVEL        = local.log_level
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

resource "aws_cloudwatch_log_group" "bda_invoke_lambda" {
  count = 1

  name              = "/aws/lambda/${aws_lambda_function.bda_invoke[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# BDA Process Results Function: copies BDA outputs into the output bucket and
# builds the Document sections (used by both fresh-job and reprocessing paths).

resource "aws_lambda_function" "bda_process_results" {
  architectures = [var.lambda_architecture]
  count         = 1

  function_name = "${local.name_prefix}-bda-process-results"
  role          = aws_iam_role.bda_process_results_lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 3008

  filename         = data.archive_file.bda_process_results_lambda[0].output_path
  source_code_hash = data.archive_file.bda_process_results_lambda[0].output_base64sha256

  layers = [var.idp_common_layer_arn != null ? var.idp_common_layer_arn : var.base_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      LOG_LEVEL                = local.log_level
      TRACKING_TABLE           = local.tracking_table_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      WORKING_BUCKET           = local.working_bucket_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
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

resource "aws_cloudwatch_log_group" "bda_process_results_lambda" {
  count = 1

  name              = "/aws/lambda/${aws_lambda_function.bda_process_results[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# BDA Completion Function (async, EventBridge-driven): receives BDA job-completion
# events, looks up the stored task token, and resumes the waiting task.

resource "aws_sqs_queue" "bda_completion_dlq" {
  count = 1

  name                       = "${local.name_prefix}-bda-completion-dlq"
  kms_master_key_id          = local.encryption_key_id
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "bda_completion_dlq" {
  count = 1

  queue_url = aws_sqs_queue.bda_completion_dlq[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.bda_completion_dlq[0].arn
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

resource "aws_lambda_function" "bda_completion" {
  architectures = [var.lambda_architecture]
  count         = 1

  function_name = "${local.name_prefix}-bda-completion"
  role          = aws_iam_role.bda_completion_lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 1024

  filename         = data.archive_file.bda_completion_lambda[0].output_path
  source_code_hash = data.archive_file.bda_completion_lambda[0].output_base64sha256

  layers = [var.idp_common_layer_arn != null ? var.idp_common_layer_arn : var.base_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE   = local.tracking_table_name
      METRIC_NAMESPACE = local.metric_namespace
      LOG_LEVEL        = local.log_level
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.bda_completion_dlq[0].arn
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

  depends_on = [aws_iam_role_policy.bda_completion_lambda]
}

resource "aws_cloudwatch_log_group" "bda_completion_lambda" {
  count = 1

  name              = "/aws/lambda/${aws_lambda_function.bda_completion[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# EventBridge rule for BDA job-completion events -> completion function
resource "aws_cloudwatch_event_rule" "bda_completion" {
  count = 1

  name        = "${local.name_prefix}-bda-completion"
  description = "Routes Bedrock Data Automation job-completion events to the BDA completion function"

  event_pattern = jsonencode({
    source = ["aws.bedrock"]
    "detail-type" = [
      "Bedrock Data Automation Job Succeeded",
      "Bedrock Data Automation Job Failed With Client Error",
      "Bedrock Data Automation Job Failed With Service Error"
    ]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "bda_completion" {
  count = 1

  rule      = aws_cloudwatch_event_rule.bda_completion[0].name
  target_id = "BDACompletionFunction"
  arn       = aws_lambda_function.bda_completion[0].arn

  retry_policy {
    maximum_event_age_in_seconds = 7200 # 2 hours
    maximum_retry_attempts       = 3
  }
}

resource "aws_lambda_permission" "bda_completion_eventbridge" {
  count = 1

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bda_completion[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bda_completion[0].arn
}
