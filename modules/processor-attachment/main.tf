# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Local variables to extract resource names from ARNs
locals {
  # Extract resource names from ARNs
  # S3 bucket names (format: arn:${data.aws_partition.current.partition}:s3:::bucket-name)
  input_bucket_name   = element(split(":", var.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", var.output_bucket_arn), 5)
  working_bucket_name = element(split(":", var.working_bucket_arn), 5)

  # Evaluation baseline bucket name (optional)
  baseline_bucket_name = var.evaluation_options != null ? element(split(":", var.evaluation_options.baseline_bucket_arn), 5) : null

  # DynamoDB table names (format: arn:${data.aws_partition.current.partition}:dynamodb:region:account:table/table-name)
  configuration_table_name = element(split("/", var.configuration_table_arn), 1)
  tracking_table_name      = element(split("/", var.tracking_table_arn), 1)
  concurrency_table_name   = element(split("/", var.concurrency_table_arn), 1)

  # KMS key (format: arn:${data.aws_partition.current.partition}:kms:region:account:key/key-id)

  # VPC config
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  # Evaluation model ARN - handle both ARN and model ID formats
  evaluation_model_arn = var.evaluation_options != null ? (
    startswith(var.evaluation_options.model_id, "arn:") ?
    var.evaluation_options.model_id :
    "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:foundation-model/${var.evaluation_options.model_id}"
  ) : null
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
