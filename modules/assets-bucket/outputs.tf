# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "bucket_name" {
  description = "Name of the S3 bucket for application assets"
  value       = aws_s3_bucket.assets_bucket.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket for application assets"
  value       = aws_s3_bucket.assets_bucket.arn
}

output "bucket_id" {
  description = "ID of the S3 bucket for application assets"
  value       = aws_s3_bucket.assets_bucket.id
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.assets_bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.assets_bucket.bucket_regional_domain_name
}

output "bucket_suffix" {
  description = "Random suffix used in the bucket name"
  value       = random_string.bucket_suffix.result
}
