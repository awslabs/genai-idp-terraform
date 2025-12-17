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
  athena_workgroup_name     = module.reporting.athena_workgroup_name
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

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| random | >= 3.0 |
| null | >= 3.0 |
| archive | >= 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for resource names | `string` | n/a | yes |
| reporting_database_name | Name of the Glue database for reporting | `string` | n/a | yes |
| athena_results_bucket_arn | ARN of the S3 bucket for Athena query results | `string` | n/a | yes |
| reporting_bucket_arn | ARN of the S3 bucket containing reporting data | `string` | n/a | yes |
| appsync_api_url | URL of the AppSync GraphQL API | `string` | n/a | yes |
| appsync_api_id | ID of the AppSync GraphQL API | `string` | n/a | yes |
| idp_common_layer_arn | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| athena_workgroup_name | Name of the Athena workgroup | `string` | `null` | no |
| bedrock_model_id | Bedrock model ID for analytics | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| log_level | Log level for Lambda functions | `string` | `"INFO"` | no |
| log_retention_days | CloudWatch log retention period | `number` | `7` | no |
| data_retention_days | Days to retain agent job data | `number` | `30` | no |
| encryption_key_arn | ARN of KMS key for encryption | `string` | `null` | no |
| vpc_subnet_ids | Subnet IDs for Lambda functions | `list(string)` | `[]` | no |
| vpc_security_group_ids | Security group IDs for Lambda | `list(string)` | `[]` | no |
| lambda_tracing_mode | X-Ray tracing mode | `string` | `"Active"` | no |
| point_in_time_recovery_enabled | Enable PITR for DynamoDB | `bool` | `true` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| agent_table_name | Name of the DynamoDB agent jobs table |
| agent_table_arn | ARN of the DynamoDB agent jobs table |
| agent_request_handler_function_name | Name of the request handler Lambda |
| agent_request_handler_function_arn | ARN of the request handler Lambda |
| agent_processor_function_name | Name of the processor Lambda |
| agent_processor_function_arn | ARN of the processor Lambda |
| list_available_agents_function_name | Name of the list agents Lambda |
| list_available_agents_function_arn | ARN of the list agents Lambda |
| bedrock_model_id | Bedrock model ID used for analytics |

## Security Considerations

- All Lambda functions use IAM roles with least-privilege permissions
- DynamoDB table supports server-side encryption with customer-managed KMS keys
- VPC deployment is supported for network isolation
- Job data is automatically cleaned up via DynamoDB TTL
- User identity is validated from Cognito tokens

## License

Apache-2.0
