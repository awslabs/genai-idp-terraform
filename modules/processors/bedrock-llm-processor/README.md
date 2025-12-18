<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.4.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_processor_configuration"></a> [processor\_configuration](#module\_processor\_configuration) | ../../processor-configuration | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.assessment_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.extraction_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.ocr_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.summarization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assessment_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.extraction_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ocr_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.summarization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.assessment_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.assessment_lambda_appsync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.assessment_lambda_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.extraction_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ocr_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.summarization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.assessment_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.assessment_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.classification_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.classification_lambda_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.classification_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.extraction_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.extraction_lambda_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.extraction_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ocr_lambda_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ocr_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ocr_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_results_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_results_lambda_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_results_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.summarization_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.summarization_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.summarization_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.assessment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.classification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.extraction](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.ocr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.process_results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.summarization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_sfn_state_machine.document_processing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [archive_file.assessment_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.classification_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.extraction_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.ocr_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.process_results_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.summarization_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_arn"></a> [api\_arn](#input\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_graphql_url"></a> [api\_graphql\_url](#input\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_assessment_guardrail"></a> [assessment\_guardrail](#input\_assessment\_guardrail) | Optional Bedrock guardrail configuration for assessment model interactions | <pre>object({<br/>    guardrail_id      = string<br/>    guardrail_version = string<br/>  })</pre> | `null` | no |
| <a name="input_assessment_model_id"></a> [assessment\_model\_id](#input\_assessment\_model\_id) | The Bedrock model ID to use for assessment (when assessment is enabled) | `string` | `null` | no |
| <a name="input_classification_guardrail"></a> [classification\_guardrail](#input\_classification\_guardrail) | Optional Bedrock guardrail to apply to classification model interactions | <pre>object({<br/>    guardrail_id  = string<br/>    guardrail_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_classification_max_workers"></a> [classification\_max\_workers](#input\_classification\_max\_workers) | The maximum number of concurrent workers for document classification | `number` | `20` | no |
| <a name="input_classification_model_id"></a> [classification\_model\_id](#input\_classification\_model\_id) | Optional model ID for document classification. If not provided, the model from config.yaml will be used. | `string` | `null` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing | `string` | n/a | yes |
| <a name="input_config"></a> [config](#input\_config) | Optional configuration values to override defaults from config.yaml | `any` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings | `string` | n/a | yes |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Whether the API is enabled | `bool` | `false` | no |
| <a name="input_enable_assessment"></a> [enable\_assessment](#input\_enable\_assessment) | Whether to enable the assessment function for document quality assessment | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources | `string` | `null` | no |
| <a name="input_evaluation_enabled"></a> [evaluation\_enabled](#input\_evaluation\_enabled) | Controls whether extraction results are evaluated for accuracy | `bool` | `false` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | Optional model ID for evaluating extraction results. If not provided, the model from config.yaml will be used. | `string` | `null` | no |
| <a name="input_extraction_guardrail"></a> [extraction\_guardrail](#input\_extraction\_guardrail) | Optional Bedrock guardrail to apply to extraction model interactions | <pre>object({<br/>    guardrail_id  = string<br/>    guardrail_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_extraction_model_id"></a> [extraction\_model\_id](#input\_extraction\_model\_id) | Optional model ID for information extraction. If not provided, the model from config.yaml will be used. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer containing shared utilities | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_is_summarization_enabled"></a> [is\_summarization\_enabled](#input\_is\_summarization\_enabled) | Controls whether document summarization is enabled | `bool` | `false` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for document processing components | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by document processing components | `number` | `7` | no |
| <a name="input_max_pages_for_classification"></a> [max\_pages\_for\_classification](#input\_max\_pages\_for\_classification) | Maximum number of pages to use for classification. Set to 'ALL' to use all pages, or a numeric value to limit. | `string` | `"ALL"` | no |
| <a name="input_max_processing_concurrency"></a> [max\_processing\_concurrency](#input\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks | `number` | `100` | no |
| <a name="input_metric_namespace"></a> [metric\_namespace](#input\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the Bedrock LLM processor resources | `string` | `"bedrock-llm-processor"` | no |
| <a name="input_ocr_max_workers"></a> [ocr\_max\_workers](#input\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing | `number` | `20` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored | `string` | n/a | yes |
| <a name="input_summarization_guardrail"></a> [summarization\_guardrail](#input\_summarization\_guardrail) | Optional Bedrock guardrail to apply to summarization model interactions | <pre>object({<br/>    guardrail_id  = string<br/>    guardrail_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Optional model ID for document summarization. If not provided, the model from config.yaml will be used. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table that tracks document processing status and metadata | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for VPC configuration | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for VPC configuration | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket used for temporary processing files | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_classification_max_workers"></a> [classification\_max\_workers](#output\_classification\_max\_workers) | The maximum number of concurrent workers for document classification |
| <a name="output_classification_model"></a> [classification\_model](#output\_classification\_model) | The classification model being used (from variable override or config.yaml) |
| <a name="output_configuration"></a> [configuration](#output\_configuration) | Configuration for the Bedrock LLM processor |
| <a name="output_evaluation_enabled"></a> [evaluation\_enabled](#output\_evaluation\_enabled) | Whether extraction results evaluation is enabled |
| <a name="output_evaluation_model"></a> [evaluation\_model](#output\_evaluation\_model) | The evaluation model being used (from variable override or config.yaml) |
| <a name="output_extraction_model"></a> [extraction\_model](#output\_extraction\_model) | The extraction model being used (from variable override or config.yaml) |
| <a name="output_is_summarization_enabled"></a> [is\_summarization\_enabled](#output\_is\_summarization\_enabled) | Whether document summarization is enabled |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Lambda functions used by the Bedrock LLM processor |
| <a name="output_max_processing_concurrency"></a> [max\_processing\_concurrency](#output\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks |
| <a name="output_model_permission_debug"></a> [model\_permission\_debug](#output\_model\_permission\_debug) | Debug information for model permissions |
| <a name="output_ocr_max_workers"></a> [ocr\_max\_workers](#output\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing |
| <a name="output_schema_definition"></a> [schema\_definition](#output\_schema\_definition) | The JSON Schema definition for Bedrock LLM processor configuration |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_state_machine_name"></a> [state\_machine\_name](#output\_state\_machine\_name) | Name of the Step Functions state machine for document processing |
| <a name="output_summarization_model"></a> [summarization\_model](#output\_summarization\_model) | The summarization model being used (from variable override or config.yaml) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
