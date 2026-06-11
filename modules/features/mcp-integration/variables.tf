# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Inputs for the MCP-integration feature-plugin submodule.
#
# This submodule is a self-contained auxiliary feature (Requirement 3 / 8): it
# provisions the Bedrock AgentCore Gateway MCP stack — the renamed
# `agentcore_mcp_handler` Lambda (upstream v0.5.3 rename of
# `agentcore_analytics_processor`), the gateway-manager custom-resource Lambda,
# the gateway execution role, the AgentCore Gateway (via a CloudFormation
# custom resource), the Cognito OAuth external app client, and the OAuth
# resource server + connector client — then emits a feature-plugin `contract`
# that `processing-environment-api` composes.
#
# The submodule is only instantiated when MCP is enabled (default-off; the root
# count-gates it on the forwarded `var.api.enable_mcp` flag). A GovCloud guard
# disables every resource when the deployment region is `us-gov-*`, regardless
# of the enable flag.

variable "enabled" {
  description = <<-EOT
    Whether MCP integration is requested. The root forwards
    `var.api.enable_mcp` here. Even when true, the GovCloud guard disables all
    resources in `us-gov-*` regions (AgentCore is unavailable there).
  EOT
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = <<-EOT
    Name prefix for MCP resources (Lambdas, roles, gateway). Mirrors the
    `processing-environment-api` API name so resource names match the historical
    `<api_name>-agentcore-*` shape and `moved {}` blocks can preserve identity.
  EOT
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the output S3 bucket the MCP handler reads/writes for Athena results and reporting data."
  type        = string
}

variable "user_pool_id" {
  description = "Cognito User Pool ID used for the MCP OAuth 2.0 external app client, resource server, and connector client."
  type        = string
  default     = null
}

variable "mcp_callback_urls" {
  description = <<-EOT
    Optional OAuth 2.0 callback URLs for the MCP external app client. Required by
    Cognito when the `code` flow is enabled, but unused by AgentCore Gateway
    (which uses JWT validation). When empty, falls back to a Cognito-hosted UI
    placeholder. Wire to the CloudFront distribution URL for cleanest behaviour.
  EOT
  type        = list(string)
  default     = []
}

variable "base_layer_arn" {
  description = "ARN of the base Lambda layer (shared Python deps). Attached to the MCP handler via compact([...])."
  type        = string
  default     = null
}

variable "idp_common_layer_arn" {
  description = "ARN of the IDP Common Lambda layer. Attached to the MCP handler via compact([...])."
  type        = string
  default     = null
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encrypting MCP log groups and used by the gateway manager. Optional."
  type        = string
  default     = null
}

variable "log_level" {
  description = "Log level for the MCP Lambda functions."
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention (days) for MCP log groups."
  type        = number
  default     = 7
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for the MCP Lambda functions. Valid values: Active, PassThrough."
  type        = string
  default     = "Active"
}

variable "vpc_config" {
  description = <<-EOT
    Optional VPC configuration for the MCP handler Lambda. The gateway-manager
    Lambda is intentionally never placed in a VPC (the AgentCore control plane
    does not support PrivateLink).
  EOT
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "lambda_vpc_access_policy_arn" {
  description = <<-EOT
    ARN of the managed policy granting Lambda VPC/ENI access, attached to the
    MCP handler role only when `vpc_config` is set. Defaults to the AWS-managed
    `AWSLambdaVPCAccessExecutionRole` for the current partition.
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all MCP resources."
  type        = map(string)
  default     = {}
}
