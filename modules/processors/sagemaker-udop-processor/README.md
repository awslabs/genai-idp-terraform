## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.49.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_engine"></a> [engine](#module\_engine) | ../unified-processor | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_arn"></a> [api\_arn](#input\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_graphql_url"></a> [api\_graphql\_url](#input\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the shared base Lambda layer (v0.4.11+), forwarded to the engine. | `string` | `null` | no |
| <a name="input_classification_endpoint_arn"></a> [classification\_endpoint\_arn](#input\_classification\_endpoint\_arn) | ARN of the consumer-supplied SageMaker endpoint used for document classification. The façade provisions NO SageMaker hosting/training; it grants the classification Lambda sagemaker:InvokeEndpoint on this endpoint and passes its name as SAGEMAKER\_ENDPOINT\_NAME. | `string` | n/a | yes |
| <a name="input_classification_max_workers"></a> [classification\_max\_workers](#input\_classification\_max\_workers) | Maximum number of concurrent workers for classification processing | `number` | `20` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing | `string` | n/a | yes |
| <a name="input_config"></a> [config](#input\_config) | Document processing configuration (from config\_library YAML), forwarded to the engine. | `any` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings | `string` | n/a | yes |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Whether the API is enabled | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources | `string` | `null` | no |
| <a name="input_evaluation_baseline_bucket_name"></a> [evaluation\_baseline\_bucket\_name](#input\_evaluation\_baseline\_bucket\_name) | Name of the S3 bucket containing baseline documents for evaluation. Leave empty to skip evaluation. | `string` | `""` | no |
| <a name="input_evaluation_layer_arn"></a> [evaluation\_layer\_arn](#input\_evaluation\_layer\_arn) | ARN of the dedicated evaluation Lambda layer (idp\_common with evaluation+docs\_service extras). Required when evaluation is enabled. | `string` | `null` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | Optional model ID for evaluating extraction results. If not provided, the model from config.yaml will be used. | `string` | `null` | no |
| <a name="input_extraction_model_id"></a> [extraction\_model\_id](#input\_extraction\_model\_id) | Optional model ID for information extraction. If not provided, the model from config.yaml will be used. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common layer | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | `null` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for document processing components | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by document processing components | `number` | `7` | no |
| <a name="input_max_processing_concurrency"></a> [max\_processing\_concurrency](#input\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks | `number` | `100` | no |
| <a name="input_metric_namespace"></a> [metric\_namespace](#input\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources | `string` | n/a | yes |
| <a name="input_ocr_max_workers"></a> [ocr\_max\_workers](#input\_ocr\_max\_workers) | Maximum number of concurrent workers for OCR processing | `number` | `20` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored | `string` | `null` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Optional model ID for document summarization. If not provided, summarization is disabled. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table that tracks document processing status and metadata | `string` | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket used for storing intermediate processing artifacts | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_classification_max_workers"></a> [classification\_max\_workers](#output\_classification\_max\_workers) | The maximum number of concurrent workers for document classification |
| <a name="output_classification_model"></a> [classification\_model](#output\_classification\_model) | The classification model being used (classification runs via the native SageMaker backend) |
| <a name="output_configuration"></a> [configuration](#output\_configuration) | Configuration for the SageMaker-UDOP processor |
| <a name="output_evaluation_enabled"></a> [evaluation\_enabled](#output\_evaluation\_enabled) | Whether extraction results evaluation is enabled |
| <a name="output_evaluation_function_arn"></a> [evaluation\_function\_arn](#output\_evaluation\_function\_arn) | ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled). Null when evaluation is disabled. |
| <a name="output_evaluation_model"></a> [evaluation\_model](#output\_evaluation\_model) | The evaluation model being used (from variable override or config.yaml) |
| <a name="output_extraction_model"></a> [extraction\_model](#output\_extraction\_model) | The extraction model being used (from variable override or config.yaml) |
| <a name="output_is_summarization_enabled"></a> [is\_summarization\_enabled](#output\_is\_summarization\_enabled) | Whether document summarization is enabled |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Lambda functions used by the processor (engine functions) |
| <a name="output_max_processing_concurrency"></a> [max\_processing\_concurrency](#output\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks |
| <a name="output_ocr_max_workers"></a> [ocr\_max\_workers](#output\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing |
| <a name="output_schema_definition"></a> [schema\_definition](#output\_schema\_definition) | The JSON Schema definition for the processor configuration |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_state_machine_name"></a> [state\_machine\_name](#output\_state\_machine\_name) | Name of the Step Functions state machine for document processing |
| <a name="output_summarization_model"></a> [summarization\_model](#output\_summarization\_model) | The summarization model being used (from variable override or config.yaml) |
