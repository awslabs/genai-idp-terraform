# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# ALB hosting for the Web UI. An internal Application Load Balancer fronts the
# Web UI S3 bucket through an S3 interface VPC endpoint, for private-network
# deployments (WebUIHosting=ALB). Mirrors upstream IDP nested/alb-hosting.

variable "name_prefix" {
  description = "Prefix for resource names (stack name)."
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy the ALB and S3 interface endpoint into."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the ALB and the S3 interface VPC endpoint (one ENI per subnet is registered as an ALB target)."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS (443) listener."
  type        = string
}

variable "alb_scheme" {
  description = "ALB scheme: internal (default, private) or internet-facing."
  type        = string
  default     = "internal"
  validation {
    condition     = contains(["internal", "internet-facing"], var.alb_scheme)
    error_message = "alb_scheme must be internal or internet-facing."
  }
}

variable "alb_allowed_cidrs" {
  description = "CIDR blocks permitted inbound HTTPS (443) to the ALB."
  type        = list(string)
  default     = []
}

variable "web_ui_bucket_name" {
  description = "Web UI S3 bucket name the ALB serves (via host-header rewrite to its S3 vhost)."
  type        = string
}

variable "logging_bucket_name" {
  description = "S3 bucket for ALB access logs. When null, ALB access logging is disabled."
  type        = string
  default     = null
}

variable "lambda_security_group_id" {
  description = "Optional app-Lambda security group id; when set, allowed 443 to the S3 VPC endpoint so presigner/host Lambdas can reach S3 via the VPCE."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
