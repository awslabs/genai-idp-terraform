<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.26.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_concurrency_table"></a> [concurrency\_table](#module\_concurrency\_table) | ../concurrency-table | n/a |
| <a name="module_configuration_table"></a> [configuration\_table](#module\_configuration\_table) | ../configuration-table | n/a |
| <a name="module_lambda_layers"></a> [lambda\_layers](#module\_lambda\_layers) | ../lambda-layer-codebuild | n/a |
| <a name="module_tracking_table"></a> [tracking\_table](#module\_tracking\_table) | ../tracking-table | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.evaluation_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.lookup_function_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.queue_sender_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.save_reporting_data_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.update_configuration_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.workflow_tracker_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.evaluation_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.evaluation_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.evaluation_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lambda_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lookup_function_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lookup_function_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.queue_sender_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.queue_sender_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.queue_sender_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.save_reporting_data_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.save_reporting_data_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.update_configuration_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.update_configuration_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.workflow_tracker_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.workflow_tracker_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.workflow_tracker_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.evaluation_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lookup_function_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.queue_sender_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.save_reporting_data_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.update_configuration_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.workflow_tracker_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.evaluation_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lookup_function_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lookup_function_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lookup_function_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_sender_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_sender_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_sender_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_sender_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.save_reporting_data_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.save_reporting_data_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.save_reporting_data_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.update_configuration_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.update_configuration_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.update_configuration_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.workflow_tracker_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.workflow_tracker_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.workflow_tracker_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.workflow_tracker_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.evaluation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.lookup_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.queue_sender](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.save_reporting_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.update_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.workflow_tracker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_sqs_queue.document_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.document_queue_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.evaluation_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.queue_sender_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.workflow_tracker_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.evaluation_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.lookup_function_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.queue_sender_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.save_reporting_data_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.update_configuration_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.workflow_tracker_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api"></a> [api](#input\_api) | Optional GraphQL API that is used to track processing status and results of documents | <pre>object({<br/>    api_id           = string<br/>    api_name         = optional(string)<br/>    api_arn          = string<br/>    graphql_url      = string<br/>    realtime_url     = optional(string)<br/>    api_key          = optional(string)<br/>    lambda_functions = optional(any)<br/>  })</pre> | `null` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the table that manages concurrency limits for document processing | `string` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the optional DynamoDB table for storing configuration settings | `string` | `null` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | The retention period for document tracking data in days | `number` | `365` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Use this instead of checking encryption\_key\_arn != null to avoid unknown value issues in for\_each/count. | `bool` | `false` | no |
| <a name="input_enable_reporting"></a> [enable\_reporting](#input\_enable\_reporting) | Whether to enable the reporting environment for analytics and evaluation capabilities | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources in the document processing workflow | `string` | `null` | no |
| <a name="input_evaluation_config"></a> [evaluation\_config](#input\_evaluation\_config) | Optional evaluation configuration for document processing quality assessment | <pre>object({<br/>    baseline_bucket_arn  = string<br/>    evaluation_model_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer to use for functions that require idp\_common | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for storing Lambda layers. If not provided, a new bucket will be created. | `string` | `""` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for the document processing components | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by the document processing components in days | `number` | `7` | no |
| <a name="input_metric_namespace"></a> [metric\_namespace](#input\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results will be stored | `string` | n/a | yes |
| <a name="input_reporting_bucket_arn"></a> [reporting\_bucket\_arn](#input\_reporting\_bucket\_arn) | ARN of the S3 bucket for reporting data (required when enable\_reporting is true) | `string` | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for Lambda functions to run in | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the optional document tracking table | `string` | `null` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket used for temporary storage during document processing | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_arn"></a> [api\_arn](#output\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata (if provided) |
| <a name="output_api_graphql_url"></a> [api\_graphql\_url](#output\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata (if provided) |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata (if provided) |
| <a name="output_concurrency_table_arn"></a> [concurrency\_table\_arn](#output\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing |
| <a name="output_concurrency_table_name"></a> [concurrency\_table\_name](#output\_concurrency\_table\_name) | Name of the DynamoDB table that manages concurrency limits for document processing |
| <a name="output_configuration_table_arn"></a> [configuration\_table\_arn](#output\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings |
| <a name="output_configuration_table_name"></a> [configuration\_table\_name](#output\_configuration\_table\_name) | Name of the DynamoDB table that stores configuration settings |
| <a name="output_document_queue_arn"></a> [document\_queue\_arn](#output\_document\_queue\_arn) | ARN of the SQS queue that holds documents waiting to be processed |
| <a name="output_document_queue_url"></a> [document\_queue\_url](#output\_document\_queue\_url) | URL of the SQS queue that holds documents waiting to be processed |
| <a name="output_encryption_key_arn"></a> [encryption\_key\_arn](#output\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources (if provided) |
| <a name="output_encryption_key_id"></a> [encryption\_key\_id](#output\_encryption\_key\_id) | ID of the KMS key used for encrypting resources (if provided) |
| <a name="output_input_bucket_arn"></a> [input\_bucket\_arn](#output\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored |
| <a name="output_input_bucket_name"></a> [input\_bucket\_name](#output\_input\_bucket\_name) | Name of the S3 bucket where source documents to be processed are stored |
| <a name="output_log_level"></a> [log\_level](#output\_log\_level) | The log level for document processing components |
| <a name="output_log_retention_days"></a> [log\_retention\_days](#output\_log\_retention\_days) | The retention period for CloudWatch logs generated by document processing components |
| <a name="output_lookup_function_arn"></a> [lookup\_function\_arn](#output\_lookup\_function\_arn) | ARN of the Lambda function that looks up document information from the tracking table |
| <a name="output_lookup_function_name"></a> [lookup\_function\_name](#output\_lookup\_function\_name) | Name of the Lambda function that looks up document information from the tracking table |
| <a name="output_metric_namespace"></a> [metric\_namespace](#output\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system |
| <a name="output_output_bucket_arn"></a> [output\_bucket\_arn](#output\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored |
| <a name="output_output_bucket_name"></a> [output\_bucket\_name](#output\_output\_bucket\_name) | Name of the S3 bucket where processed documents and extraction results are stored |
| <a name="output_queue_sender_function_arn"></a> [queue\_sender\_function\_arn](#output\_queue\_sender\_function\_arn) | ARN of the Lambda function that sends documents to the processing queue |
| <a name="output_queue_sender_function_name"></a> [queue\_sender\_function\_name](#output\_queue\_sender\_function\_name) | Name of the Lambda function that sends documents to the processing queue |
| <a name="output_save_reporting_data_function_arn"></a> [save\_reporting\_data\_function\_arn](#output\_save\_reporting\_data\_function\_arn) | ARN of the Lambda function that saves reporting data to the reporting bucket (when reporting is enabled) |
| <a name="output_save_reporting_data_function_name"></a> [save\_reporting\_data\_function\_name](#output\_save\_reporting\_data\_function\_name) | Name of the Lambda function that saves reporting data to the reporting bucket (when reporting is enabled) |
| <a name="output_tracking_table_arn"></a> [tracking\_table\_arn](#output\_tracking\_table\_arn) | ARN of the DynamoDB table that tracks document processing status and metadata |
| <a name="output_tracking_table_name"></a> [tracking\_table\_name](#output\_tracking\_table\_name) | Name of the DynamoDB table that tracks document processing status and metadata |
| <a name="output_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#output\_vpc\_security\_group\_ids) | List of security group IDs for VPC configuration (if provided) |
| <a name="output_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#output\_vpc\_subnet\_ids) | List of subnet IDs for VPC configuration (if provided) |
| <a name="output_workflow_tracker_function_arn"></a> [workflow\_tracker\_function\_arn](#output\_workflow\_tracker\_function\_arn) | ARN of the Lambda function that tracks workflow execution status |
| <a name="output_workflow_tracker_function_name"></a> [workflow\_tracker\_function\_name](#output\_workflow\_tracker\_function\_name) | Name of the Lambda function that tracks workflow execution status |
| <a name="output_working_bucket_arn"></a> [working\_bucket\_arn](#output\_working\_bucket\_arn) | ARN of the S3 bucket used for working files during document processing |
| <a name="output_working_bucket_name"></a> [working\_bucket\_name](#output\_working\_bucket\_name) | Name of the S3 bucket used for working files during document processing |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
