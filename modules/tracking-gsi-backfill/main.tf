# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Tracking-table GSI backfill (upstream v0.5.1)
#
# Operator-triggered, default-off backfill that populates the `ItemType` (and
# `HITLPendingReview`) attributes on tracking-table items that predate the
# `TypeDateIndex` GSI, so historical items appear in type/time-range queries.
#
# Creates the worker Lambda (`backfill_gsi_attributes`, `index.lambda_handler`),
# its execution role, log group, source archive, and the Step Functions state
# machine that drives it (with the IAM-propagation guard). The run is started
# explicitly by an operator; this module never auto-starts a run.
#
# Runtime/timeout/memory/env mirror `sources/template.yaml`
# `BackfillWorkerFunction` exactly (python3.12, 900s, 512MB, env LOG_LEVEL).

# =============================================================================
# CloudWatch log group
# =============================================================================

resource "aws_cloudwatch_log_group" "backfill_worker" {
  name              = "/aws/lambda/${var.name_prefix}-gsi-backfill-worker"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

# =============================================================================
# Lambda source archive (referenced from the read-only sources/ snapshot)
# =============================================================================

data "archive_file" "backfill_worker" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/backfill_gsi_attributes"
  output_path = "${path.module}/../../.terraform/archives/backfill_gsi_attributes.zip"
}

# =============================================================================
# IAM role: least-privilege for the backfill worker
# =============================================================================

resource "aws_iam_role" "backfill_worker" {
  name = "${var.name_prefix}-gsi-backfill-worker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "backfill_worker" {
  name = "gsi-backfill-worker-policy"
  role = aws_iam_role.backfill_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Scoped to exactly this Lambda's own log group (and its streams).
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          aws_cloudwatch_log_group.backfill_worker.arn,
          "${aws_cloudwatch_log_group.backfill_worker.arn}:*",
        ]
      },
      {
        # Read/update the tracking table and its indexes — and nothing else.
        # Mirrors the upstream DynamoDBCrudPolicy scoped to TrackingTable, but
        # narrowed to exactly the actions the worker performs.
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [
          var.tracking_table_arn,
          "${var.tracking_table_arn}/index/*",
        ]
      },
      {
        # KMS access to exactly the tracking-table encryption key.
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = [var.encryption_key_arn]
      },
    ]
  })
}

# =============================================================================
# Lambda: backfill_gsi_attributes worker
# =============================================================================

resource "aws_lambda_function" "backfill_worker" {
  architectures    = [var.lambda_architecture]
  function_name    = "${var.name_prefix}-gsi-backfill-worker"
  role             = aws_iam_role.backfill_worker.arn
  filename         = data.archive_file.backfill_worker.output_path
  source_code_hash = data.archive_file.backfill_worker.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 512
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL = var.log_level
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.backfill_worker,
    aws_iam_role_policy.backfill_worker,
  ]

  tags = var.tags
}

# =============================================================================
# Step Functions state machine: GSI attribute backfill
# =============================================================================
#
# Mirrors `sources/template.yaml` `BackfillStateMachine` faithfully. The
# upstream definition is an inline `Map` (Iterator + MaxConcurrency 10) where
# the worker Lambda performs the segmented DynamoDB parallel scan itself and
# returns a continuation token past its timeout — NOT a Service-integration
# Distributed Map with an `ItemReader`. We render the exact upstream ASL via
# `templatefile` (the template lives in this module dir, never under
# `sources/`). Because the map only invokes the worker, the state-machine role
# grants exactly `lambda:InvokeFunction` and nothing else; the worker (not the
# state machine) reads DynamoDB. We add only the CloudWatch Logs delivery +
# X-Ray permissions the wrapper's SFN logging convention requires (see
# unified-processor).
#
# There is no `aws_lambda_invocation` and no trigger/auto-start resource:
# applying this module creates the machinery only. The operator starts the run
# explicitly (`aws stepfunctions start-execution`), so `terraform apply` never
# mutates tracking-table data unattended.

# CloudWatch log group for the state machine (vended-logs path).
resource "aws_cloudwatch_log_group" "backfill_state_machine" {
  name              = "/aws/vendedlogs/states/${var.name_prefix}-gsi-backfill"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

# Least-privilege state-machine role.
resource "aws_iam_role" "backfill_state_machine" {
  name = "${var.name_prefix}-gsi-backfill-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# The lambda:InvokeFunction statement is scoped to exactly the backfill worker.
# The CloudWatch Logs vended-log-delivery actions (logs:CreateLogDelivery/... ) and
# the X-Ray actions only support a "*" resource — a documented AWS requirement for
# log-delivery and tracing management, not over-broad scoping. This mirrors the
# wrapper's other logged state machines (modules/processors/unified-processor/iam.tf).
resource "aws_iam_role_policy" "backfill_state_machine" {
  name = "gsi-backfill-sfn-policy"
  role = aws_iam_role.backfill_state_machine.id

  #tfsec:ignore:aws-iam-no-policy-wildcards
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Exactly the upstream BackfillStateMachinePolicy: invoke the worker and
        # nothing else. The worker (not the state machine) reads DynamoDB.
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.backfill_worker.arn]
      },
      {
        # CloudWatch Logs vended-log delivery for the state machine's execution
        # logging. These actions only support a "*" resource (a documented AWS
        # requirement for log-delivery management), mirroring the wrapper's other
        # logged state machines (unified-processor).
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
        ]
        Resource = ["*"]
      },
    ]
  })
}

# Wait for the state-machine IAM role + inline policy + log group to propagate
# before CreateStateMachine. Without this, AWS validates log-destination access
# synchronously and fails with an AccessDeniedException. 30s per project
# convention (terraform-conventions.md; same guard as unified-processor,
# sagemaker-udop-processor, and the codebuild modules).
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.backfill_state_machine,
    aws_iam_role_policy.backfill_state_machine,
    aws_cloudwatch_log_group.backfill_state_machine,
  ]

  create_duration = "30s"
}

resource "aws_sfn_state_machine" "backfill" {
  depends_on = [time_sleep.wait_for_iam_propagation]

  name     = "${var.name_prefix}-gsi-backfill"
  role_arn = aws_iam_role.backfill_state_machine.arn

  definition = templatefile("${path.module}/templates/backfill.asl.json.tftpl", {
    backfill_worker_function_arn = aws_lambda_function.backfill_worker.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.backfill_state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = var.tags
}
