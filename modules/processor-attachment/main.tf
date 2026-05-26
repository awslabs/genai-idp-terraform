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

  # Build directory for archive_file outputs (used by lambda.tf and any
  # other file in this module that needs a place to drop generated zips).
  module_build_dir   = "${path.module}/.terraform-build"
  module_instance_id = substr(md5("${path.module}-processor-attachment"), 0, 8)
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create module-specific build directory. Shared by every archive_file in
# this module.
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Generate unique build ID for this module instance. Used to name zip
# outputs so multiple terraform applies don't trip over each other.
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    module_instance_id = local.module_instance_id
    content_hash       = md5("processor-attachment")
  }
}
