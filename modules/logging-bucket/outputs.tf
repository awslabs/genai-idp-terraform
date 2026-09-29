# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "bucket_arn" {
  description = "ARN of the access-log destination bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the access-log destination bucket"
  value       = aws_s3_bucket.this.id
}
