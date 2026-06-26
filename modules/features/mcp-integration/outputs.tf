# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "contract" {
  description = <<-EOT
    Feature-plugin contract consumed by `processing-environment-api` via its
    `enabled_feature_contracts` input, mirroring the CDK `api.enable(feature)`
    mechanism.

    MCP is largely self-contained — it owns its Lambdas, roles, AgentCore
    Gateway, and Cognito OAuth resources — so it contributes no AppSync
    resolvers and adds nothing to the shared AppSync Lambda role. The contract
    therefore carries empty `resolvers`/`iam_statements`/`environment` maps and
    serves as the composition signal (`enabled = true`) for the API module.
    `enabled` is false when the GovCloud guard disables MCP, so the API module
    composes nothing in that case.
  EOT
  value = {
    enabled          = local.enable_mcp_effective
    resolvers        = {}
    iam_statements   = []
    environment      = {}
    schema_additions = null
  }
}

output "enabled" {
  description = "Whether MCP integration is effectively enabled (false in GovCloud or when disabled)."
  value       = local.enable_mcp_effective
}

output "mcp_handler_function_arn" {
  description = "ARN of the agentcore_mcp_handler Lambda."
  value       = local.enable_mcp_effective ? aws_lambda_function.agentcore_mcp_handler[0].arn : null
}

output "mcp_handler_function_name" {
  description = "Function name of the agentcore_mcp_handler Lambda."
  value       = local.enable_mcp_effective ? aws_lambda_function.agentcore_mcp_handler[0].function_name : null
}

output "mcp_gateway_endpoint" {
  description = "MCP server endpoint URL (AgentCore Gateway endpoint)."
  value       = local.enable_mcp_effective ? try(aws_cloudformation_stack.agentcore_gateway[0].outputs["GatewayEndpoint"], null) : null
}

output "mcp_gateway_id" {
  description = "AgentCore Gateway ID."
  value       = local.enable_mcp_effective ? try(aws_cloudformation_stack.agentcore_gateway[0].outputs["GatewayId"], null) : null
}

output "mcp_oauth_client_id" {
  description = "Cognito app client ID for MCP OAuth 2.0 authentication."
  value       = local.enable_mcp_effective && var.user_pool_id != null ? try(aws_cognito_user_pool_client.mcp_client[0].id, null) : null
}

output "mcp_oauth_client_secret" {
  description = "Cognito app client secret for MCP OAuth 2.0 authentication."
  value       = local.enable_mcp_effective && var.user_pool_id != null ? try(aws_cognito_user_pool_client.mcp_client[0].client_secret, null) : null
  sensitive   = true
}

output "mcp_connector_client_id" {
  description = "Cognito connector client ID (client_credentials flow) for the OAuth resource server."
  value       = local.enable_mcp_effective && var.user_pool_id != null ? try(aws_cognito_user_pool_client.mcp_connector[0].id, null) : null
}

output "mcp_resource_server_identifier" {
  description = "Identifier of the Cognito OAuth resource server (idp-mcp-connector)."
  value       = local.enable_mcp_effective && var.user_pool_id != null ? try(aws_cognito_resource_server.mcp[0].identifier, null) : null
}
