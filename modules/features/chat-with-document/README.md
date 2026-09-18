## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.chat_document_sessions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.chat_processor_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.chat_resolver_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.chat_processor](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.chat_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_bedrock_model_ids"></a> [allowed\_bedrock\_model\_ids](#input\_allowed\_bedrock\_model\_ids) | Extra Bedrock model IDs the chat Lambdas may invoke, for chat models set in<br>the config after apply. Mirrors `processor.allowed_bedrock_model_ids`; use<br>`["*"]` to grant the account's whole model space. | `list(string)` | `[]` | no |
| <a name="input_appsync_graphql_url"></a> [appsync\_graphql\_url](#input\_appsync\_graphql\_url) | Legacy AppSync endpoint URL, passed to the processor Lambda as<br>`APPSYNC_API_URL`.<br><br>Retained ONLY because the vendored upstream processor code still reads that<br>env var. IDP v0.6.4 expects it to be the empty string, which selects the<br>DynamoDB-direct write path (`idp_common.docs_service` always resolves to<br>DynamoDB in v0.6); the root passes "". Do not set it to a real URL — there is<br>no AppSync API to publish to. | `string` | `""` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the base Lambda layer (idp\_common). Attached to the chat processor per conventions. | `string` | `null` | no |
| <a name="input_config"></a> [config](#input\_config) | Document configuration object. The effective chat<br>configuration resolves to the top-level `chat:` block when present, else<br>falls back to `summarization.*`; when no chat model is specified the default<br>is `us.anthropic.claude-opus-4-7:1m` (v0.5.12 default). Only the chat-relevant<br>keys are read here; the full config is otherwise opaque to this submodule. | `any` | `{}` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB configuration table the chat processor reads chat/summarization config from. | `string` | n/a | yes |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB configuration table (env wiring for the chat processor). | `string` | n/a | yes |
| <a name="input_data_retention_days"></a> [data\_retention\_days](#input\_data\_retention\_days) | Retention (days) for ephemeral chat-session ownership records and logs. | `number` | `1` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used to encrypt chat resources/logs. Optional. | `string` | `null` | no |
| <a name="input_guardrail_id_and_version"></a> [guardrail\_id\_and\_version](#input\_guardrail\_id\_and\_version) | Bedrock Guardrail ID and version in `id:version` form. Optional. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the idp\_common Lambda layer, when supplied separately from the base layer. | `string` | `null` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). Must match the architecture the idp\_common layers were built for; mismatches break native deps (e.g. pydantic\_core). | `string` | `"arm64"` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for the chat Lambdas. Valid values: Active, PassThrough. | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for the chat Lambdas. | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days for the chat Lambdas. | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names created by this submodule. | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the output S3 bucket the chat processor reads document artifacts from. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB tracking table the chat processor reads document metadata from. | `string` | n/a | yes |
| <a name="input_tracking_table_name"></a> [tracking\_table\_name](#input\_tracking\_table\_name) | Name of the DynamoDB tracking table (env wiring for the chat processor). | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | Security group IDs for the chat Lambdas (VPC mode). | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | Subnet IDs for the chat Lambdas (VPC mode). Empty disables VPC config. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_chat_document_sessions_table_name"></a> [chat\_document\_sessions\_table\_name](#output\_chat\_document\_sessions\_table\_name) | Name of the Chat-with-Document session-ownership DynamoDB table. |
| <a name="output_chat_processor_function_arn"></a> [chat\_processor\_function\_arn](#output\_chat\_processor\_function\_arn) | ARN of the long-running Chat-with-Document processor Lambda. |
| <a name="output_chat_resolver_function_arn"></a> [chat\_resolver\_function\_arn](#output\_chat\_resolver\_function\_arn) | ARN of the lightweight sendChatDocumentMessage resolver Lambda. |
| <a name="output_contract"></a> [contract](#output\_contract) | Feature-plugin contract consumed by `processing-environment-api` via its<br>`enabled_feature_contracts` input (mirrors the CDK `api.enable(feature)`<br>mechanism). The Chat-with-Document submodule owns its Lambdas, execution<br>roles, and session table, so the contract contributes only transport wiring.<br>`iam_statements` and `environment` are empty because the submodule is fully<br>self-contained.<br><br>IDP v0.6.4: `resolvers` (AppSync) is replaced by `field_functions` — the<br>field -> Lambda ARN map the REST dispatcher routes on. Only<br>`sendChatDocumentMessage` appears. The `onChatDocumentMessageUpdate`<br>subscription is gone: API Gateway REST has no GraphQL subscriptions, and<br>upstream replaced that fan-out with the streaming Lambda Function URL plus<br>polling. |
| <a name="output_effective_chat_config"></a> [effective\_chat\_config](#output\_effective\_chat\_config) | The resolved chat configuration: the top-level<br>`chat:` block when present, otherwise the `summarization.*` fallback, with<br>the model defaulting to `us.anthropic.claude-opus-4-7:1m` when unspecified.<br>`source` reports which block the values came from ("chat" or "summarization"). |
