## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.process_changes_resolver_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.process_changes_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.process_changes_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.process_changes_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.process_changes_resolver_build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.process_changes_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_data_retention_days"></a> [data\_retention\_days](#input\_data\_retention\_days) | Data retention period in days | `number` | `365` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS encryption key | `string` | n/a | yes |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the input S3 bucket | `string` | n/a | yes |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). Must match the architecture the idp\_common layers were built for; mismatches break native deps (e.g. pydantic\_core). | `string` | `"arm64"` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | Lambda tracing mode | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the output S3 bucket | `string` | n/a | yes |
| <a name="input_queue_arn"></a> [queue\_arn](#input\_queue\_arn) | ARN of the SQS queue for document processing | `string` | n/a | yes |
| <a name="input_queue_url"></a> [queue\_url](#input\_queue\_url) | URL of the SQS queue for document processing | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB tracking table | `string` | n/a | yes |
| <a name="input_tracking_table_name"></a> [tracking\_table\_name](#input\_tracking\_table\_name) | Name of the DynamoDB tracking table | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of VPC security group IDs for Lambda function (optional) | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of VPC subnet IDs for Lambda function (optional) | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the working S3 bucket | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_process_changes_resolver_function_arn"></a> [process\_changes\_resolver\_function\_arn](#output\_process\_changes\_resolver\_function\_arn) | ARN of the Process Changes Resolver Lambda function |
| <a name="output_process_changes_resolver_function_name"></a> [process\_changes\_resolver\_function\_name](#output\_process\_changes\_resolver\_function\_name) | Name of the Process Changes Resolver Lambda function |
| <a name="output_process_changes_resolver_invoke_arn"></a> [process\_changes\_resolver\_invoke\_arn](#output\_process\_changes\_resolver\_invoke\_arn) | Invoke ARN of the Process Changes Resolver Lambda function |
| <a name="output_process_changes_resolver_role_arn"></a> [process\_changes\_resolver\_role\_arn](#output\_process\_changes\_resolver\_role\_arn) | ARN of the Process Changes Resolver IAM role |
| <a name="output_process_changes_resolver_role_name"></a> [process\_changes\_resolver\_role\_name](#output\_process\_changes\_resolver\_role\_name) | Name of the Process Changes Resolver IAM role |
