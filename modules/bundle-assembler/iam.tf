# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

resource "aws_iam_role" "assembler" {
  name = "${var.name_prefix}-assembler-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "assembler" {
  name = "BundleAssemblerPolicy"
  role = aws_iam_role.assembler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-assembler-${random_string.suffix.result}*"
      },
      {
        # Read parts + head/delete on the staging bucket. ListBucket applies to
        # the bucket ARN; object actions to /*.
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [aws_s3_bucket.staging.arn, "${aws_s3_bucket.staging.arn}/*"]
      },
      {
        # Write the merged bundle to the IDP input bucket; head_object for the
        # idempotency guard.
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${var.idp_input_bucket_arn}/*"
      },
      {
        # ListBucket on the input bucket so the idempotency head_object on a
        # MISSING key returns 404 (not 403 Forbidden). Without this S3 masks a
        # missing object as Forbidden and the assembler fails on first run.
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.idp_input_bucket_arn
      }
      ], var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = var.encryption_key_arn
    }] : [])
  })
}

# VPC ENI permissions when the Lambda runs in a VPC.
resource "aws_iam_role_policy" "assembler_vpc" {
  #checkov:skip=CKV_AWS_355:EC2 network interface ops require wildcard — ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface ops require wildcard — ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "BundleAssemblerVpcPolicy"
  role  = aws_iam_role.assembler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"]
      Resource = "*"
    }]
  })
}
