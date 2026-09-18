## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.discovery_processor_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.discovery_upload_resolver_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.discovery_tracking](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.discovery_processor_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_processor_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_processor_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_upload_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_upload_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.discovery_upload_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.discovery_processor_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.discovery_upload_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_processor_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_upload_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_upload_resolver_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.discovery_upload_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.discovery_processor_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.discovery_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.discovery_upload_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_s3_bucket.discovery_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.discovery_bucket_cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.discovery_bucket_lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_notification.discovery_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_policy.discovery_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.discovery_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.discovery_bucket_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.discovery_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_sqs_queue.discovery_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.discovery_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
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
| <a name="input_allowed_cors_origins"></a> [allowed\_cors\_origins](#input\_allowed\_cors\_origins) | Allowed CORS origins for the discovery bucket (the web-UI / CloudFront app origin). Empty list falls back to ["*"] for backward compatibility (Wiz S3-036). | `list(string)` | `[]` | no |
| <a name="input_appsync_api_url"></a> [appsync\_api\_url](#input\_appsync\_api\_url) | URL of the AppSync GraphQL API for status updates | `string` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB configuration table | `string` | n/a | yes |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB configuration table (read by the discovery processor) | `string` | `null` | no |
| <a name="input_data_retention_days"></a> [data\_retention\_days](#input\_data\_retention\_days) | Number of days to retain discovery documents | `number` | `365` | no |
| <a name="input_discovery_bucket_arn"></a> [discovery\_bucket\_arn](#input\_discovery\_bucket\_arn) | ARN of the dedicated discovery S3 bucket | `string` | `null` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket for discovery document uploads | `string` | n/a | yes |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). Must match the architecture the idp\_common layers were built for; mismatches break native deps (e.g. pydantic\_core). | `string` | `"arm64"` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Enable point-in-time recovery for DynamoDB tables | `bool` | `true` | no |
| <a name="input_s3_endpoint_url"></a> [s3\_endpoint\_url](#input\_s3\_endpoint\_url) | Optional S3 endpoint URL (VPC interface endpoint) for the discovery upload presigner. When set, presigned URLs target the VPCE via virtual-host addressing. Null (default) uses the global regional S3 endpoint. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_discovery_bucket_arn"></a> [discovery\_bucket\_arn](#output\_discovery\_bucket\_arn) | ARN of the discovery S3 bucket |
| <a name="output_discovery_bucket_domain_name"></a> [discovery\_bucket\_domain\_name](#output\_discovery\_bucket\_domain\_name) | Domain name of the discovery S3 bucket |
| <a name="output_discovery_bucket_name"></a> [discovery\_bucket\_name](#output\_discovery\_bucket\_name) | Name of the discovery S3 bucket |
| <a name="output_discovery_dlq_arn"></a> [discovery\_dlq\_arn](#output\_discovery\_dlq\_arn) | ARN of the SQS dead letter queue for failed discovery jobs |
| <a name="output_discovery_dlq_url"></a> [discovery\_dlq\_url](#output\_discovery\_dlq\_url) | URL of the SQS dead letter queue for failed discovery jobs |
| <a name="output_discovery_processor_function_arn"></a> [discovery\_processor\_function\_arn](#output\_discovery\_processor\_function\_arn) | ARN of the Discovery Processor Lambda function |
| <a name="output_discovery_processor_function_name"></a> [discovery\_processor\_function\_name](#output\_discovery\_processor\_function\_name) | Name of the Discovery Processor Lambda function |
| <a name="output_discovery_processor_invoke_arn"></a> [discovery\_processor\_invoke\_arn](#output\_discovery\_processor\_invoke\_arn) | Invoke ARN of the Discovery Processor Lambda function |
| <a name="output_discovery_queue_arn"></a> [discovery\_queue\_arn](#output\_discovery\_queue\_arn) | ARN of the SQS queue for discovery job processing |
| <a name="output_discovery_queue_url"></a> [discovery\_queue\_url](#output\_discovery\_queue\_url) | URL of the SQS queue for discovery job processing |
| <a name="output_discovery_tracking_table_arn"></a> [discovery\_tracking\_table\_arn](#output\_discovery\_tracking\_table\_arn) | ARN of the DynamoDB table for discovery job tracking |
| <a name="output_discovery_tracking_table_name"></a> [discovery\_tracking\_table\_name](#output\_discovery\_tracking\_table\_name) | Name of the DynamoDB table for discovery job tracking |
| <a name="output_discovery_upload_resolver_function_arn"></a> [discovery\_upload\_resolver\_function\_arn](#output\_discovery\_upload\_resolver\_function\_arn) | ARN of the Discovery Upload Resolver Lambda function |
| <a name="output_discovery_upload_resolver_function_name"></a> [discovery\_upload\_resolver\_function\_name](#output\_discovery\_upload\_resolver\_function\_name) | Name of the Discovery Upload Resolver Lambda function |
| <a name="output_discovery_upload_resolver_invoke_arn"></a> [discovery\_upload\_resolver\_invoke\_arn](#output\_discovery\_upload\_resolver\_invoke\_arn) | Invoke ARN of the Discovery Upload Resolver Lambda function |
