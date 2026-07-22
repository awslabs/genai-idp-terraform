# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs mirror upstream nested/alb-hosting/template.yaml.

output "web_ui_url" {
  description = "Web UI URL served via the ALB."
  value       = "https://${aws_lb.this.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "alb_hosted_zone_id" {
  description = "ALB canonical hosted zone ID (for Route53 alias records)."
  value       = aws_lb.this.zone_id
}

output "s3_vpc_endpoint_id" {
  description = "S3 interface VPC endpoint ID."
  value       = aws_vpc_endpoint.s3.id
}

output "s3_vpc_endpoint_dns_name" {
  description = <<-EOT
    Regional DNS name of the S3 interface VPC endpoint with the leading "*."
    stripped. Build presigned-URL hosts as "<bucket>.<this-value>" so browser
    uploads resolve through the VPCE.
  EOT
  # aws_vpc_endpoint.dns_entry[0].dns_name is "*.bucket.vpce-....vpce.amazonaws.com";
  # upstream strips the "*." prefix (CFN Split on "*." take index 1).
  value = trimprefix(aws_vpc_endpoint.s3.dns_entry[0].dns_name, "*.")
}

output "alb_security_group_id" {
  description = "Security group ID attached to the ALB."
  value       = aws_security_group.alb.id
}

output "endpoint_security_group_id" {
  description = "Security group ID attached to the S3 interface VPC endpoint."
  value       = aws_security_group.endpoint.id
}
