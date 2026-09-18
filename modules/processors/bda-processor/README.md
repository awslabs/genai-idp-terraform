## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_engine"></a> [engine](#module\_engine) | ../unified-processor | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_arn.data_automation_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/arn) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_configurations"></a> [additional\_configurations](#input\_additional\_configurations) | Extra non-active, editable configuration versions seeded alongside the default (version\_name => config object). Shown in the UI version dropdown. | `any` | `{}` | no |
| <a name="input_allowed_bedrock_model_ids"></a> [allowed\_bedrock\_model\_ids](#input\_allowed\_bedrock\_model\_ids) | Bedrock model IDs every processing step is allowed to invoke, on top of the models resolved from the seeded configs. Set this for models operators will select in the UI later, which Terraform cannot see. Use ["*"] to allow any Bedrock model. Empty (default) grants only the resolved models. | `list(string)` | `[]` | no |
| <a name="input_api_arn"></a> [api\_arn](#input\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_graphql_url"></a> [api\_graphql\_url](#input\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the shared base Lambda layer (idp\_common with docs\_service extras, v0.4.11+). | `string` | `null` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing | `string` | n/a | yes |
| <a name="input_config"></a> [config](#input\_config) | Configuration values from config\_library YAML files | `any` | n/a | yes |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings | `string` | n/a | yes |
| <a name="input_data_automation_project_arn"></a> [data\_automation\_project\_arn](#input\_data\_automation\_project\_arn) | The ARN of the Bedrock Data Automation Project used for document processing. Consumer-supplied; the project id is exposed as an output and the ARN is used to link configuration versions to the BDA branch via seeding (not a deploy-time engine input). | `string` | n/a | yes |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Whether the API is enabled. Use this instead of checking api\_id != null to avoid unknown value issues in count. | `bool` | `false` | no |
| <a name="input_enable_bda_ocr_backend"></a> [enable\_bda\_ocr\_backend](#input\_enable\_bda\_ocr\_backend) | Provision the deployment-scoped Bedrock Data Automation OCR project required by the IDP v0.6 `ocr.backend: bda` configuration setting. Off by default: BDA is not available in every region, and an unconditional control-plane create would fail apply there. Forwarded to the unified-processor engine. | `bool` | `false` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Use this instead of checking encryption\_key\_arn != null to avoid unknown value issues in count. | `bool` | `false` | no |
| <a name="input_enable_rule_validation"></a> [enable\_rule\_validation](#input\_enable\_rule\_validation) | Enable rule validation Lambda functions for compliance assessment (v0.4.13+) | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources in the document processing workflow | `string` | `null` | no |
| <a name="input_evaluation_baseline_bucket_name"></a> [evaluation\_baseline\_bucket\_name](#input\_evaluation\_baseline\_bucket\_name) | Name of the S3 bucket containing baseline documents for evaluation. Leave empty to skip evaluation. | `string` | `""` | no |
| <a name="input_evaluation_layer_arn"></a> [evaluation\_layer\_arn](#input\_evaluation\_layer\_arn) | ARN of the dedicated evaluation Lambda layer (idp\_common with evaluation extras). Forwarded to the engine; required by the engine when evaluation is enabled. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer containing shared utilities | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64), forwarded to the shared engine so function architectures match the idp\_common layers. | `string` | `"arm64"` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for storing Lambda layers (retained for root-call compatibility; unused by the façade — the shared engine packages Lambdas from zip archives). | `string` | `""` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for document processing components | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by document processing components | `number` | `7` | no |
| <a name="input_max_processing_concurrency"></a> [max\_processing\_concurrency](#input\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks | `number` | `100` | no |
| <a name="input_metric_namespace"></a> [metric\_namespace](#input\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the BDA processor resources | `string` | `"bda-processor"` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored | `string` | n/a | yes |
| <a name="input_reporting_bucket_name"></a> [reporting\_bucket\_name](#input\_reporting\_bucket\_name) | Name of the reporting bucket the evaluation function forwards accuracy results to. Leave null to disable the evaluation reporting fan-out. | `string` | `null` | no |
| <a name="input_save_reporting_function_arn"></a> [save\_reporting\_function\_arn](#input\_save\_reporting\_function\_arn) | ARN of the save\_reporting\_data Lambda, used to scope the evaluation function's invoke grant. | `string` | `null` | no |
| <a name="input_save_reporting_function_name"></a> [save\_reporting\_function\_name](#input\_save\_reporting\_function\_name) | Name of the save\_reporting\_data Lambda the evaluation function invokes to persist accuracy results. Leave null to disable the evaluation reporting fan-out. | `string` | `null` | no |
| <a name="input_seed_managed_configs"></a> [seed\_managed\_configs](#input\_seed\_managed\_configs) | Seed the managed baseline configuration versions as non-active reference rows. | `bool` | `true` | no |
| <a name="input_summarization_guardrail"></a> [summarization\_guardrail](#input\_summarization\_guardrail) | Optional Bedrock guardrail to apply to summarization model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table that tracks document processing status and metadata | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions to run in | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket used for storing intermediate processing artifacts | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configuration"></a> [configuration](#output\_configuration) | Effective configuration for the BDA processor (from the shared engine) |
| <a name="output_data_automation_project"></a> [data\_automation\_project](#output\_data\_automation\_project) | Information about the Bedrock Data Automation Project |
| <a name="output_data_automation_project_arn"></a> [data\_automation\_project\_arn](#output\_data\_automation\_project\_arn) | ARN of the BDA Data Automation Project (consumed by processing-environment-api for BDA sync resolver) |
| <a name="output_evaluation_function_arn"></a> [evaluation\_function\_arn](#output\_evaluation\_function\_arn) | ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled) |
| <a name="output_evaluation_model"></a> [evaluation\_model](#output\_evaluation\_model) | The model used for evaluating extraction results |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Lambda functions used by the BDA processor (from the shared engine) |
| <a name="output_max_processing_concurrency"></a> [max\_processing\_concurrency](#output\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_state_machine_name"></a> [state\_machine\_name](#output\_state\_machine\_name) | Name of the Step Functions state machine for document processing |
| <a name="output_summarization_model"></a> [summarization\_model](#output\_summarization\_model) | The model used for document summarization |
