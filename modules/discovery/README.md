# Discovery Module

This module creates the infrastructure for the Discovery feature, which enables automated configuration generation from document samples.

## Overview

The Discovery module analyzes documents to identify structure, field types, and organizational patterns, then generates configuration blueprints automatically. This enables rapid onboarding of new document types without manual configuration.

## Features

- **Document Analysis**: Analyzes uploaded documents to identify structure and field types
- **Configuration Blueprint Generation**: Automatically generates configuration blueprints based on document analysis
- **Pattern Support**: Supports Pattern-1 (BDA), Pattern-2 (Bedrock LLM), and Pattern-3 (SageMaker UDOP)
- **Zero-Touch BDA Blueprint**: Enables zero-touch BDA blueprint generation for Pattern-1
- **Ground Truth Support**: Optionally accepts ground truth files for improved accuracy

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Upload        │     │   SQS Queue     │     │   Processor     │
│   Resolver      │────▶│   (Discovery)   │────▶│   Lambda        │
│   Lambda        │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                               │
        │                                               │
        ▼                                               ▼
┌─────────────────┐                           ┌─────────────────┐
│   S3 Bucket     │                           │   Configuration │
│   (Discovery)   │                           │   Table         │
└─────────────────┘                           └─────────────────┘
        │                                               │
        │                                               │
        ▼                                               ▼
┌─────────────────┐                           ┌─────────────────┐
│   DynamoDB      │                           │   AppSync API   │
│   (Tracking)    │                           │   (Status)      │
└─────────────────┘                           └─────────────────┘
```

## Usage

```hcl
module "discovery" {
  source = "./modules/discovery"

  name_prefix              = "my-idp"
  discovery_bucket_arn     = aws_s3_bucket.discovery.arn
  configuration_table_name = module.configuration_table.table_name
  configuration_table_arn  = module.configuration_table.table_arn
  idp_common_layer_arn     = module.idp_common_layer.layer_arn

  # Optional
  appsync_api_url        = module.api.graphql_url
  encryption_key_arn     = aws_kms_key.main.arn
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  tags = var.tags
}
```

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
| discovery_bucket_arn | ARN of the S3 bucket for discovery document uploads | `string` | n/a | yes |
| configuration_table_name | Name of the DynamoDB configuration table | `string` | n/a | yes |
| configuration_table_arn | ARN of the DynamoDB configuration table | `string` | n/a | yes |
| idp_common_layer_arn | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| working_bucket_arn | ARN of the S3 working bucket for document processing | `string` | `null` | no |
| appsync_api_url | URL of the AppSync GraphQL API for status updates | `string` | `null` | no |
| log_level | Log level for Lambda functions | `string` | `"INFO"` | no |
| log_retention_days | CloudWatch log retention period in days | `number` | `7` | no |
| encryption_key_arn | ARN of the KMS key for encryption | `string` | `null` | no |
| vpc_subnet_ids | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |
| vpc_security_group_ids | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| lambda_tracing_mode | X-Ray tracing mode for Lambda functions | `string` | `"Active"` | no |
| point_in_time_recovery_enabled | Enable point-in-time recovery for DynamoDB tables | `bool` | `true` | no |
| patterns_supported | List of processing patterns supported by discovery | `list(string)` | `["pattern-1", "pattern-2", "pattern-3"]` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| discovery_tracking_table_name | Name of the DynamoDB table for discovery job tracking |
| discovery_tracking_table_arn | ARN of the DynamoDB table for discovery job tracking |
| discovery_queue_url | URL of the SQS queue for discovery job processing |
| discovery_queue_arn | ARN of the SQS queue for discovery job processing |
| discovery_dlq_url | URL of the SQS dead letter queue for failed discovery jobs |
| discovery_dlq_arn | ARN of the SQS dead letter queue for failed discovery jobs |
| discovery_upload_resolver_function_name | Name of the Discovery Upload Resolver Lambda function |
| discovery_upload_resolver_function_arn | ARN of the Discovery Upload Resolver Lambda function |
| discovery_processor_function_name | Name of the Discovery Processor Lambda function |
| discovery_processor_function_arn | ARN of the Discovery Processor Lambda function |
| discovery_state_machine_arn | ARN of the Discovery Step Functions state machine |
| discovery_state_machine_name | Name of the Discovery Step Functions state machine |
| patterns_supported | List of processing patterns supported by discovery |

## License

Apache-2.0
