## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_agent_analytics_idp_layer"></a> [agent\_analytics\_idp\_layer](#module\_agent\_analytics\_idp\_layer) | ../../idp-common-layer | n/a |
| <a name="module_agent_dependencies_layer"></a> [agent\_dependencies\_layer](#module\_agent\_dependencies\_layer) | ../../lambda-layer-codebuild | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.agent_processor_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agent_request_handler_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.list_available_agents_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.agent_jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.agent_processor_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.agent_processor_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.agent_processor_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.agent_request_handler_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.agent_request_handler_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.agent_request_handler_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.list_available_agents_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.list_available_agents_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.list_available_agents_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.agent_processor_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agent_request_handler_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.list_available_agents_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.agent_processor_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_processor_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_processor_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_request_handler_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_request_handler_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_request_handler_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.list_available_agents_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.list_available_agents_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.list_available_agents_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.agent_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.agent_request_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.list_available_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.list_agents_build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.processor_build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.request_handler_build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.agent_processor_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.agent_request_handler_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.list_available_agents_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_bedrock_model_ids"></a> [allowed\_bedrock\_model\_ids](#input\_allowed\_bedrock\_model\_ids) | Extra Bedrock model IDs the analytics agents are allowed to invoke, for agent<br>models set in the config after apply (which Terraform cannot see). Mirrors<br>`processor.allowed_bedrock_model_ids`. Use `["*"]` to grant the account's<br>whole model space. | `list(string)` | `[]` | no |
| <a name="input_athena_results_bucket_arn"></a> [athena\_results\_bucket\_arn](#input\_athena\_results\_bucket\_arn) | ARN of the S3 bucket for Athena query results | `string` | n/a | yes |
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | Bedrock model ID for the analytics agent | `string` | `"us.anthropic.claude-sonnet-4-5-20250929-v1:0"` | no |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB configuration table | `string` | n/a | yes |
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Container runtime for local builds (auto\|docker\|podman\|finch). | `string` | `"auto"` | no |
| <a name="input_data_retention_days"></a> [data\_retention\_days](#input\_data\_retention\_days) | Number of days to retain agent job data in DynamoDB | `number` | `30` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Use this instead of checking encryption\_key\_arn != null to avoid unknown value issues in for\_each/count. | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). | `string` | `"arm64"` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for storing Lambda layers. If not provided, a new bucket will be created. | `string` | `null` | no |
| <a name="input_lambda_local"></a> [lambda\_local](#input\_lambda\_local) | When true, build Lambda layers locally using a container runtime instead of via AWS CodeBuild. | `bool` | `false` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Enable point-in-time recovery for DynamoDB tables | `bool` | `true` | no |
| <a name="input_reporting_bucket_arn"></a> [reporting\_bucket\_arn](#input\_reporting\_bucket\_arn) | ARN of the S3 bucket containing reporting data | `string` | n/a | yes |
| <a name="input_reporting_database_name"></a> [reporting\_database\_name](#input\_reporting\_database\_name) | Name of the Glue database for reporting | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC to place the agent-deps layer-build CodeBuild project in, alongside vpc\_subnet\_ids and vpc\_security\_group\_ids. Null builds outside a VPC. | `string` | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_processor_function_arn"></a> [agent\_processor\_function\_arn](#output\_agent\_processor\_function\_arn) | ARN of the Agent Processor Lambda function |
| <a name="output_agent_processor_function_name"></a> [agent\_processor\_function\_name](#output\_agent\_processor\_function\_name) | Name of the Agent Processor Lambda function |
| <a name="output_agent_processor_invoke_arn"></a> [agent\_processor\_invoke\_arn](#output\_agent\_processor\_invoke\_arn) | Invoke ARN of the Agent Processor Lambda function |
| <a name="output_agent_processor_role_arn"></a> [agent\_processor\_role\_arn](#output\_agent\_processor\_role\_arn) | ARN of the IAM role for Agent Processor Lambda |
| <a name="output_agent_request_handler_function_arn"></a> [agent\_request\_handler\_function\_arn](#output\_agent\_request\_handler\_function\_arn) | ARN of the Agent Request Handler Lambda function |
| <a name="output_agent_request_handler_function_name"></a> [agent\_request\_handler\_function\_name](#output\_agent\_request\_handler\_function\_name) | Name of the Agent Request Handler Lambda function |
| <a name="output_agent_request_handler_invoke_arn"></a> [agent\_request\_handler\_invoke\_arn](#output\_agent\_request\_handler\_invoke\_arn) | Invoke ARN of the Agent Request Handler Lambda function |
| <a name="output_agent_request_handler_role_arn"></a> [agent\_request\_handler\_role\_arn](#output\_agent\_request\_handler\_role\_arn) | ARN of the IAM role for Agent Request Handler Lambda |
| <a name="output_agent_table_arn"></a> [agent\_table\_arn](#output\_agent\_table\_arn) | ARN of the DynamoDB table for agent job tracking |
| <a name="output_agent_table_name"></a> [agent\_table\_name](#output\_agent\_table\_name) | Name of the DynamoDB table for agent job tracking |
| <a name="output_bedrock_model_id"></a> [bedrock\_model\_id](#output\_bedrock\_model\_id) | Bedrock model ID used for the analytics agent |
| <a name="output_list_available_agents_function_arn"></a> [list\_available\_agents\_function\_arn](#output\_list\_available\_agents\_function\_arn) | ARN of the List Available Agents Lambda function |
| <a name="output_list_available_agents_function_name"></a> [list\_available\_agents\_function\_name](#output\_list\_available\_agents\_function\_name) | Name of the List Available Agents Lambda function |
| <a name="output_list_available_agents_invoke_arn"></a> [list\_available\_agents\_invoke\_arn](#output\_list\_available\_agents\_invoke\_arn) | Invoke ARN of the List Available Agents Lambda function |
| <a name="output_list_available_agents_role_arn"></a> [list\_available\_agents\_role\_arn](#output\_list\_available\_agents\_role\_arn) | ARN of the IAM role for List Available Agents Lambda |
