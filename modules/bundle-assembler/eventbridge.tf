# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Fire the assembler when a bundle's manifest.json (the completion sentinel) is
# created in the staging bucket.

resource "aws_cloudwatch_event_rule" "manifest_created" {
  name        = "${var.name_prefix}-manifest-${random_string.suffix.result}"
  description = "Assemble a bundle when its manifest.json is written to the staging bucket"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.staging.id] }
      object = { key = [{ suffix = "manifest.json" }] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "manifest_to_assembler" {
  rule      = aws_cloudwatch_event_rule.manifest_created.name
  target_id = "BundleAssembler"
  arn       = aws_lambda_function.assembler.arn

  retry_policy {
    maximum_event_age_in_seconds = 7200
    maximum_retry_attempts       = 3
  }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge-${random_string.suffix.result}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.assembler.function_name
  principal     = "events.${data.aws_partition.current.dns_suffix}"
  source_arn    = aws_cloudwatch_event_rule.manifest_created.arn
}
