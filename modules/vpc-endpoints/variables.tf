# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "vpc_id" {
  description = "ID of the VPC in which to create the endpoints."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs in which to place the interface endpoint ENIs. Use the private subnets of the deployment."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = <<-EOT
    List of security group IDs to associate with the interface endpoints. This module does
    not manage the security group; the caller owns it. The SG MUST allow inbound HTTPS (TCP
    443) from the VPC CIDR, not just from the Lambda SG. In-VPC browser clients (WorkSpaces,
    VPN, bastion) send REST API requests directly to the `execute-api` interface endpoint,
    so an SG that only permits 443 from the Lambda SG leaves the UI hanging when
    `api.api_gateway_visibility = "PRIVATE"` (this is the upstream IDP 0.5.15 "VpcCidr"
    fix, carried forward to the v0.6.4 REST transport). See
    `examples/bedrock-llm-processor-vpc` for a reference SG that opens 443 from the VPC
    CIDR.
  EOT
  type        = list(string)
  default     = []
}

variable "private_dns_enabled" {
  description = "Whether to enable private DNS for the interface endpoints. Enabled by default; supported by all services in the default endpoint set."
  type        = bool
  default     = true
}

variable "enabled_interface_endpoints" {
  description = <<-EOT
    Map of interface endpoint service keys to a boolean enabling each one. The key is the
    AWS service suffix as it appears in the PrivateLink service name
    (`com.amazonaws.<region>.<key>`), so it is partition-portable. Set a key to `false`
    (or omit it) to skip provisioning that endpoint. The default covers the full set IDP
    can require; consumers typically narrow it to the services their enabled processors
    and features actually use.
  EOT
  type        = map(bool)
  default = {
    ssm                   = true
    ssmmessages           = true
    ec2messages           = true
    logs                  = true
    monitoring            = true
    kms                   = true
    sts                   = true
    sqs                   = true
    states                = true
    bedrock               = true
    bedrock-runtime       = true
    bedrock-agent-runtime = true
    # execute-api: reaches the API Gateway REST transport when it is PRIVATE
    # (v0.6.4 — replaced appsync-api when upstream removed AppSync).
    execute-api = true
    codebuild   = true
    lambda      = true
    events      = true
    textract    = true
  }
}

variable "enable_s3_gateway" {
  description = "Whether to create the S3 gateway endpoint."
  type        = bool
  default     = true
}

variable "enable_dynamodb_gateway" {
  description = "Whether to create the DynamoDB gateway endpoint."
  type        = bool
  default     = true
}

variable "route_table_ids" {
  description = "List of route table IDs to associate with the S3 and DynamoDB gateway endpoints. Required when either gateway endpoint is enabled."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
