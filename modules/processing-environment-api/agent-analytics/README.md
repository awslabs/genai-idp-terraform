# Agent Analytics Module

This module creates the infrastructure for the Agent Analytics feature, which enables natural language querying of processed document data. The Agent Analytics module converts natural language questions to SQL queries, executes them against Amazon Athena, and generates interactive visualizations.

## Features

- Natural language to SQL query conversion using Amazon Bedrock
- Interactive visualization generation (charts, tables, text)
- DynamoDB-based job tracking with TTL for automatic cleanup
- AppSync integration for real-time status updates
- Support for multiple agent types via agent factory pattern
- Bedrock AgentCore sandbox execution for Python code

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│   AppSync API   │────▶│ Agent Request Handler│────▶│   Agent Processor   │
└─────────────────┘     └──────────────────────┘     └─────────────────────┘
                                   │                           │
                                   ▼                           ▼
                        ┌──────────────────┐         ┌─────────────────┐
                        │  DynamoDB Table  │         │  Amazon Bedrock │
                        │   (Job Tracking) │         │   (Analytics)   │
                        └──────────────────┘         └─────────────────┘
                                                              │
                                                              ▼
                                                     ┌─────────────────┐
                                                     │  Amazon Athena  │
                                                     │   (Queries)     │
                                                     └─────────────────┘
```

## Usage

```hcl
module "agent_analytics" {
  source = "./modules/agent-analytics"

  name_prefix               = "my-idp"
  reporting_database_name   = module.reporting.database_name
  athena_results_bucket_arn = module.reporting.athena_results_bucket_arn
  reporting_bucket_arn      = module.reporting.reporting_bucket_arn
  appsync_api_url           = module.processing_environment_api.appsync_api_url
  appsync_api_id            = module.processing_environment_api.appsync_api_id
  idp_common_layer_arn      = module.idp_common_layer.layer_arn

  # Optional
  bedrock_model_id    = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  log_level           = "INFO"
  log_retention_days  = 7
  data_retention_days = 30
  encryption_key_arn  = aws_kms_key.main.arn

  tags = {
    Environment = "production"
  }
}
```

## Lambda Functions

### Agent Request Handler

Handles incoming agent query requests from AppSync:

- Validates user identity and query parameters
- Creates job records in DynamoDB
- Invokes the Agent Processor asynchronously
- Returns job ID for status tracking

### Agent Processor

Processes agent queries using Strands agents:

- Loads analytics configuration
- Creates appropriate agent (single or orchestrator)
- Executes natural language queries
- Updates job status via AppSync mutations
- Handles retries and error recovery

### List Available Agents

Returns metadata about available agents:

- Agent IDs and names
- Agent descriptions
- Sample queries for each agent

## Security Considerations

- All Lambda functions use IAM roles with least-privilege permissions
- DynamoDB table supports server-side encryption with customer-managed KMS keys
- VPC deployment is supported for network isolation
- Job data is automatically cleaned up via DynamoDB TTL
- User identity is validated from Cognito tokens

## License

Apache-2.0
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
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
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.26.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.agent_processor_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agent_request_handler_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.list_available_agents_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.agent_jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.agent_processor_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
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
| [aws_iam_role_policy_attachment.agent_processor_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
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
| [aws_lambda_permission.appsync_agent_request_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.appsync_list_available_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
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
| <a name="input_appsync_api_id"></a> [appsync\_api\_id](#input\_appsync\_api\_id) | ID of the AppSync GraphQL API | `string` | n/a | yes |
| <a name="input_appsync_api_url"></a> [appsync\_api\_url](#input\_appsync\_api\_url) | URL of the AppSync GraphQL API for status updates | `string` | n/a | yes |
| <a name="input_athena_results_bucket_arn"></a> [athena\_results\_bucket\_arn](#input\_athena\_results\_bucket\_arn) | ARN of the S3 bucket for Athena query results | `string` | n/a | yes |
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | Bedrock model ID for the analytics agent | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_data_retention_days"></a> [data\_retention\_days](#input\_data\_retention\_days) | Number of days to retain agent job data in DynamoDB | `number` | `30` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Enable point-in-time recovery for DynamoDB tables | `bool` | `true` | no |
| <a name="input_reporting_bucket_arn"></a> [reporting\_bucket\_arn](#input\_reporting\_bucket\_arn) | ARN of the S3 bucket containing reporting data | `string` | n/a | yes |
| <a name="input_reporting_database_name"></a> [reporting\_database\_name](#input\_reporting\_database\_name) | Name of the Glue database for reporting | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
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
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
