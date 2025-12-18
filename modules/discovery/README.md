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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.discovery_processor_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.discovery_state_machine_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.discovery_upload_resolver_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.discovery_tracking](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.discovery_processor_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_processor_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_processor_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_processor_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_state_machine_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_upload_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_upload_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_upload_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.discovery_processor_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.discovery_state_machine_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.discovery_upload_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_state_machine_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_upload_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_upload_resolver_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_upload_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.discovery_processor_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.discovery_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.discovery_upload_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_sfn_state_machine.discovery_workflow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_sqs_queue.discovery_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.discovery_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_redrive_policy.discovery_queue_redrive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_policy) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.processor_build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.upload_resolver_build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.discovery_processor_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.discovery_upload_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_appsync_api_url"></a> [appsync\_api\_url](#input\_appsync\_api\_url) | URL of the AppSync GraphQL API for status updates | `string` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB configuration table | `string` | n/a | yes |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB configuration table | `string` | n/a | yes |
| <a name="input_discovery_bucket_arn"></a> [discovery\_bucket\_arn](#input\_discovery\_bucket\_arn) | ARN of the S3 bucket for discovery document uploads | `string` | n/a | yes |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_patterns_supported"></a> [patterns\_supported](#input\_patterns\_supported) | List of processing patterns supported by discovery | `list(string)` | <pre>[<br/>  "pattern-1",<br/>  "pattern-2",<br/>  "pattern-3"<br/>]</pre> | no |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Enable point-in-time recovery for DynamoDB tables | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 working bucket for document processing | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_discovery_dlq_arn"></a> [discovery\_dlq\_arn](#output\_discovery\_dlq\_arn) | ARN of the SQS dead letter queue for failed discovery jobs |
| <a name="output_discovery_dlq_url"></a> [discovery\_dlq\_url](#output\_discovery\_dlq\_url) | URL of the SQS dead letter queue for failed discovery jobs |
| <a name="output_discovery_processor_function_arn"></a> [discovery\_processor\_function\_arn](#output\_discovery\_processor\_function\_arn) | ARN of the Discovery Processor Lambda function |
| <a name="output_discovery_processor_function_name"></a> [discovery\_processor\_function\_name](#output\_discovery\_processor\_function\_name) | Name of the Discovery Processor Lambda function |
| <a name="output_discovery_processor_invoke_arn"></a> [discovery\_processor\_invoke\_arn](#output\_discovery\_processor\_invoke\_arn) | Invoke ARN of the Discovery Processor Lambda function |
| <a name="output_discovery_processor_role_arn"></a> [discovery\_processor\_role\_arn](#output\_discovery\_processor\_role\_arn) | ARN of the IAM role for Discovery Processor Lambda |
| <a name="output_discovery_queue_arn"></a> [discovery\_queue\_arn](#output\_discovery\_queue\_arn) | ARN of the SQS queue for discovery job processing |
| <a name="output_discovery_queue_url"></a> [discovery\_queue\_url](#output\_discovery\_queue\_url) | URL of the SQS queue for discovery job processing |
| <a name="output_discovery_state_machine_arn"></a> [discovery\_state\_machine\_arn](#output\_discovery\_state\_machine\_arn) | ARN of the Discovery Step Functions state machine |
| <a name="output_discovery_state_machine_name"></a> [discovery\_state\_machine\_name](#output\_discovery\_state\_machine\_name) | Name of the Discovery Step Functions state machine |
| <a name="output_discovery_tracking_table_arn"></a> [discovery\_tracking\_table\_arn](#output\_discovery\_tracking\_table\_arn) | ARN of the DynamoDB table for discovery job tracking |
| <a name="output_discovery_tracking_table_name"></a> [discovery\_tracking\_table\_name](#output\_discovery\_tracking\_table\_name) | Name of the DynamoDB table for discovery job tracking |
| <a name="output_discovery_upload_resolver_function_arn"></a> [discovery\_upload\_resolver\_function\_arn](#output\_discovery\_upload\_resolver\_function\_arn) | ARN of the Discovery Upload Resolver Lambda function |
| <a name="output_discovery_upload_resolver_function_name"></a> [discovery\_upload\_resolver\_function\_name](#output\_discovery\_upload\_resolver\_function\_name) | Name of the Discovery Upload Resolver Lambda function |
| <a name="output_discovery_upload_resolver_invoke_arn"></a> [discovery\_upload\_resolver\_invoke\_arn](#output\_discovery\_upload\_resolver\_invoke\_arn) | Invoke ARN of the Discovery Upload Resolver Lambda function |
| <a name="output_discovery_upload_resolver_role_arn"></a> [discovery\_upload\_resolver\_role\_arn](#output\_discovery\_upload\_resolver\_role\_arn) | ARN of the IAM role for Discovery Upload Resolver Lambda |
| <a name="output_patterns_supported"></a> [patterns\_supported](#output\_patterns\_supported) | List of processing patterns supported by discovery |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
