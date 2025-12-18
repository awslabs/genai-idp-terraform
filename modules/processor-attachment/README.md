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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.evaluation_function_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.s3_event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.workflow_state_change_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.evaluation_function_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.s3_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.workflow_state_change_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.evaluation_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.queue_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.evaluation_function_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.queue_processor_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.queue_processor_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.evaluation_function_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.queue_processor_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.evaluation_function_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_function_custom_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_function_vpc_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_processor_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_processor_custom_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_processor_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.queue_processor_vpc_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.queue_processor_event_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.evaluation_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.queue_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_eventbridge_to_invoke_evaluation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.allow_eventbridge_to_invoke_queue_sender](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.allow_eventbridge_to_invoke_workflow_tracker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.evaluation_function_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.queue_processor_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_arn"></a> [api\_arn](#input\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_graphql_url"></a> [api\_graphql\_url](#input\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing | `string` | n/a | yes |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings | `string` | n/a | yes |
| <a name="input_document_queue_arn"></a> [document\_queue\_arn](#input\_document\_queue\_arn) | ARN of the SQS queue that holds documents waiting to be processed | `string` | n/a | yes |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Use this instead of checking encryption\_key\_arn != null to avoid unknown value issues in for\_each/count. | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources in the document processing workflow | `string` | `null` | no |
| <a name="input_evaluation_options"></a> [evaluation\_options](#input\_evaluation\_options) | Optional evaluation configuration | <pre>object({<br/>    baseline_bucket_arn = string<br/>    model_id            = string<br/>  })</pre> | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer to use for functions that require idp\_common | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for document processing components | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by document processing components | `number` | `7` | no |
| <a name="input_metric_namespace"></a> [metric\_namespace](#input\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for resources | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored | `string` | n/a | yes |
| <a name="input_processor"></a> [processor](#input\_processor) | Processor configuration | <pre>object({<br/>    state_machine_arn          = string<br/>    max_processing_concurrency = number<br/>  })</pre> | n/a | yes |
| <a name="input_queue_sender_function_arn"></a> [queue\_sender\_function\_arn](#input\_queue\_sender\_function\_arn) | ARN of the Lambda function that sends documents to the processing queue | `string` | n/a | yes |
| <a name="input_queue_sender_function_name"></a> [queue\_sender\_function\_name](#input\_queue\_sender\_function\_name) | Name of the Lambda function that sends documents to the processing queue | `string` | n/a | yes |
| <a name="input_s3_prefix"></a> [s3\_prefix](#input\_s3\_prefix) | Optional S3 prefix to filter documents for processing | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table that tracks document processing status and metadata | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions to run in | `list(string)` | `[]` | no |
| <a name="input_workflow_tracker_function_arn"></a> [workflow\_tracker\_function\_arn](#input\_workflow\_tracker\_function\_arn) | ARN of the Lambda function that tracks workflow execution status | `string` | n/a | yes |
| <a name="input_workflow_tracker_function_name"></a> [workflow\_tracker\_function\_name](#input\_workflow\_tracker\_function\_name) | Name of the Lambda function that tracks workflow execution status | `string` | n/a | yes |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket used for storing intermediate processing artifacts | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_evaluation_function"></a> [evaluation\_function](#output\_evaluation\_function) | The Lambda function that evaluates document extraction results (if enabled) |
| <a name="output_evaluation_rule"></a> [evaluation\_rule](#output\_evaluation\_rule) | The EventBridge rule for evaluation function (if enabled) |
| <a name="output_queue_processor"></a> [queue\_processor](#output\_queue\_processor) | The Lambda function that processes documents from the queue |
| <a name="output_s3_event_rule"></a> [s3\_event\_rule](#output\_s3\_event\_rule) | The EventBridge rule for S3 events |
| <a name="output_workflow_state_change_rule"></a> [workflow\_state\_change\_rule](#output\_workflow\_state\_change\_rule) | The EventBridge rule for Step Functions state changes |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
