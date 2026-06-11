## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.49.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudformation_stack.agentcore_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_cloudwatch_log_group.agentcore_gateway_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agentcore_mcp_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cognito_resource_server.mcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_resource_server) | resource |
| [aws_cognito_user_pool_client.mcp_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_client.mcp_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_iam_role.agentcore_gateway_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agentcore_gateway_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agentcore_mcp_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.agentcore_gateway_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agentcore_gateway_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agentcore_mcp_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.agentcore_mcp_handler_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agentcore_mcp_handler_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.agentcore_gateway_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.agentcore_mcp_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [null_resource.build_agentcore_gateway_manager](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [archive_file.agentcore_gateway_manager](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.agentcore_mcp_handler](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the base Lambda layer (shared Python deps). Attached to the MCP handler via compact([...]). | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether MCP integration is requested. The root forwards<br>`var.api.enable_mcp` here. Even when true, the GovCloud guard disables all<br>resources in `us-gov-*` regions (AgentCore is unavailable there). | `bool` | `true` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encrypting MCP log groups and used by the gateway manager. Optional. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP Common Lambda layer. Attached to the MCP handler via compact([...]). | `string` | `null` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for the MCP Lambda functions. Valid values: Active, PassThrough. | `string` | `"Active"` | no |
| <a name="input_lambda_vpc_access_policy_arn"></a> [lambda\_vpc\_access\_policy\_arn](#input\_lambda\_vpc\_access\_policy\_arn) | ARN of the managed policy granting Lambda VPC/ENI access, attached to the<br>MCP handler role only when `vpc_config` is set. Defaults to the AWS-managed<br>`AWSLambdaVPCAccessExecutionRole` for the current partition. | `string` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for the MCP Lambda functions. | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention (days) for MCP log groups. | `number` | `7` | no |
| <a name="input_mcp_callback_urls"></a> [mcp\_callback\_urls](#input\_mcp\_callback\_urls) | Optional OAuth 2.0 callback URLs for the MCP external app client. Required by<br>Cognito when the `code` flow is enabled, but unused by AgentCore Gateway<br>(which uses JWT validation). When empty, falls back to a Cognito-hosted UI<br>placeholder. Wire to the CloudFront distribution URL for cleanest behaviour. | `list(string)` | `[]` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for MCP resources (Lambdas, roles, gateway). Mirrors the<br>`processing-environment-api` API name so resource names match the historical<br>`<api_name>-agentcore-*` shape and `moved {}` blocks can preserve identity. | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the output S3 bucket the MCP handler reads/writes for Athena results and reporting data. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all MCP resources. | `map(string)` | `{}` | no |
| <a name="input_user_pool_id"></a> [user\_pool\_id](#input\_user\_pool\_id) | Cognito User Pool ID used for the MCP OAuth 2.0 external app client, resource server, and connector client. | `string` | `null` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Optional VPC configuration for the MCP handler Lambda. The gateway-manager<br>Lambda is intentionally never placed in a VPC (the AgentCore control plane<br>does not support PrivateLink). | <pre>object({<br>    subnet_ids         = list(string)<br>    security_group_ids = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contract"></a> [contract](#output\_contract) | Feature-plugin contract consumed by `processing-environment-api` via its<br>`enabled_feature_contracts` input, mirroring the CDK `api.enable(feature)`<br>mechanism.<br><br>MCP is largely self-contained — it owns its Lambdas, roles, AgentCore<br>Gateway, and Cognito OAuth resources — so it contributes no AppSync<br>resolvers and adds nothing to the shared AppSync Lambda role. The contract<br>therefore carries empty `resolvers`/`iam_statements`/`environment` maps and<br>serves as the composition signal (`enabled = true`) for the API module.<br>`enabled` is false when the GovCloud guard disables MCP, so the API module<br>composes nothing in that case. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether MCP integration is effectively enabled (false in GovCloud or when disabled). |
| <a name="output_mcp_connector_client_id"></a> [mcp\_connector\_client\_id](#output\_mcp\_connector\_client\_id) | Cognito connector client ID (client\_credentials flow) for the OAuth resource server. |
| <a name="output_mcp_gateway_endpoint"></a> [mcp\_gateway\_endpoint](#output\_mcp\_gateway\_endpoint) | MCP server endpoint URL (AgentCore Gateway endpoint). |
| <a name="output_mcp_gateway_id"></a> [mcp\_gateway\_id](#output\_mcp\_gateway\_id) | AgentCore Gateway ID. |
| <a name="output_mcp_handler_function_arn"></a> [mcp\_handler\_function\_arn](#output\_mcp\_handler\_function\_arn) | ARN of the renamed agentcore\_mcp\_handler Lambda (v0.5.3 rename of agentcore\_analytics\_processor). |
| <a name="output_mcp_handler_function_name"></a> [mcp\_handler\_function\_name](#output\_mcp\_handler\_function\_name) | Function name of the agentcore\_mcp\_handler Lambda (preserved across the rename for state continuity). |
| <a name="output_mcp_oauth_client_id"></a> [mcp\_oauth\_client\_id](#output\_mcp\_oauth\_client\_id) | Cognito app client ID for MCP OAuth 2.0 authentication. |
| <a name="output_mcp_oauth_client_secret"></a> [mcp\_oauth\_client\_secret](#output\_mcp\_oauth\_client\_secret) | Cognito app client secret for MCP OAuth 2.0 authentication. |
| <a name="output_mcp_resource_server_identifier"></a> [mcp\_resource\_server\_identifier](#output\_mcp\_resource\_server\_identifier) | Identifier of the Cognito OAuth resource server (idp-mcp-connector). |
