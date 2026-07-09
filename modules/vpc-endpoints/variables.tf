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
  description = "List of security group IDs to associate with the interface endpoints. Typically a single SG allowing HTTPS (443) from the VPC."
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
    appsync-api           = true
    codebuild             = true
    lambda                = true
    events                = true
    textract              = true
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
