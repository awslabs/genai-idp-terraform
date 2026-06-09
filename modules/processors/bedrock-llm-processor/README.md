## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_engine"></a> [engine](#module\_engine) | ../unified-processor | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_arn"></a> [api\_arn](#input\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_graphql_url"></a> [api\_graphql\_url](#input\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_assessment_guardrail"></a> [assessment\_guardrail](#input\_assessment\_guardrail) | Optional Bedrock guardrail configuration for assessment model interactions | <pre>object({<br>    guardrail_id      = string<br>    guardrail_version = string<br>  })</pre> | `null` | no |
| <a name="input_assessment_model_id"></a> [assessment\_model\_id](#input\_assessment\_model\_id) | The Bedrock model ID to use for assessment (when assessment is enabled) | `string` | `null` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the shared base Lambda layer (idp\_common with docs\_service extras, v0.4.11+) | `string` | `null` | no |
| <a name="input_classification_guardrail"></a> [classification\_guardrail](#input\_classification\_guardrail) | Optional Bedrock guardrail to apply to classification model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_classification_max_workers"></a> [classification\_max\_workers](#input\_classification\_max\_workers) | The maximum number of concurrent workers for document classification | `number` | `20` | no |
| <a name="input_classification_model_id"></a> [classification\_model\_id](#input\_classification\_model\_id) | Optional model ID for document classification. Overrides model\_id for this step. If not provided, model\_id is used. | `string` | `null` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing | `string` | n/a | yes |
| <a name="input_config"></a> [config](#input\_config) | Optional configuration values to override defaults from config.yaml | `any` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings | `string` | n/a | yes |
| <a name="input_enable_agentic_extraction"></a> [enable\_agentic\_extraction](#input\_enable\_agentic\_extraction) | Whether to enable agentic extraction using Strands agent framework | `bool` | `false` | no |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Whether the API is enabled | `bool` | `false` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Use this instead of checking encryption\_key\_arn != null to avoid unknown value issues in for\_each/count. | `bool` | `false` | no |
| <a name="input_enable_hitl"></a> [enable\_hitl](#input\_enable\_hitl) | Whether to enable Human-in-the-Loop (HITL) functionality for document review | `bool` | `false` | no |
| <a name="input_enable_rule_validation"></a> [enable\_rule\_validation](#input\_enable\_rule\_validation) | Enable rule validation Lambda functions for compliance assessment (v0.4.13+) | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources | `string` | `null` | no |
| <a name="input_evaluation_baseline_bucket_arn"></a> [evaluation\_baseline\_bucket\_arn](#input\_evaluation\_baseline\_bucket\_arn) | ARN of the S3 bucket containing baseline documents for evaluation. Required when evaluation\_enabled is true. | `string` | `null` | no |
| <a name="input_evaluation_enabled"></a> [evaluation\_enabled](#input\_evaluation\_enabled) | Controls whether extraction results are evaluated for accuracy | `bool` | `false` | no |
| <a name="input_evaluation_layer_arn"></a> [evaluation\_layer\_arn](#input\_evaluation\_layer\_arn) | ARN of the dedicated evaluation Lambda layer (idp\_common with evaluation+docs\_service extras, includes munkres/numpy). Required when evaluation\_enabled=true. | `string` | `null` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | Optional model ID for evaluating extraction results. Overrides model\_id for this step. If not provided, model\_id is used. | `string` | `null` | no |
| <a name="input_extraction_guardrail"></a> [extraction\_guardrail](#input\_extraction\_guardrail) | Optional Bedrock guardrail to apply to extraction model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_extraction_model_id"></a> [extraction\_model\_id](#input\_extraction\_model\_id) | Optional model ID for information extraction. Overrides model\_id for this step. If not provided, model\_id is used. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer containing shared utilities | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_is_summarization_enabled"></a> [is\_summarization\_enabled](#input\_is\_summarization\_enabled) | Controls whether document summarization is enabled | `bool` | `false` | no |
| <a name="input_lambda_hook_assessment"></a> [lambda\_hook\_assessment](#input\_lambda\_hook\_assessment) | ARN or name of custom Lambda for Assessment step hook inference. Must start with 'GENAIIDP-'. (v0.4.15+) | `string` | `""` | no |
| <a name="input_lambda_hook_classification"></a> [lambda\_hook\_classification](#input\_lambda\_hook\_classification) | ARN or name of custom Lambda for Classification step hook inference. Must start with 'GENAIIDP-'. (v0.4.15+) | `string` | `""` | no |
| <a name="input_lambda_hook_extraction"></a> [lambda\_hook\_extraction](#input\_lambda\_hook\_extraction) | ARN or name of custom Lambda for Extraction step hook inference. Must start with 'GENAIIDP-'. (v0.4.15+) | `string` | `""` | no |
| <a name="input_lambda_hook_ocr"></a> [lambda\_hook\_ocr](#input\_lambda\_hook\_ocr) | ARN or name of custom Lambda for OCR step hook inference. Must start with 'GENAIIDP-'. (v0.4.15+) | `string` | `""` | no |
| <a name="input_lambda_hook_summarization"></a> [lambda\_hook\_summarization](#input\_lambda\_hook\_summarization) | ARN or name of custom Lambda for Summarization step hook inference. Must start with 'GENAIIDP-'. (v0.4.15+) | `string` | `""` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for document processing components | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by document processing components | `number` | `7` | no |
| <a name="input_max_pages_for_classification"></a> [max\_pages\_for\_classification](#input\_max\_pages\_for\_classification) | Maximum number of pages to use for classification. Set to 'ALL' to use all pages, or a numeric value to limit. | `string` | `"ALL"` | no |
| <a name="input_max_processing_concurrency"></a> [max\_processing\_concurrency](#input\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks | `number` | `100` | no |
| <a name="input_metric_namespace"></a> [metric\_namespace](#input\_metric\_namespace) | The namespace for CloudWatch metrics emitted by the document processing system | `string` | n/a | yes |
| <a name="input_model_id"></a> [model\_id](#input\_model\_id) | Default Bedrock model ID for all processing steps. Supports global./ us. prefixes and :flex/:priority/:standard suffixes. (v0.4.12+) | `string` | `"us.amazon.nova-2-lite-v1:0"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the Bedrock LLM processor resources | `string` | `"bedrock-llm-processor"` | no |
| <a name="input_ocr_max_workers"></a> [ocr\_max\_workers](#input\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing | `number` | `20` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored | `string` | n/a | yes |
| <a name="input_review_agent_model"></a> [review\_agent\_model](#input\_review\_agent\_model) | Bedrock model ID for the review agent. If empty, uses the extraction model. | `string` | `""` | no |
| <a name="input_section_splitting_strategy"></a> [section\_splitting\_strategy](#input\_section\_splitting\_strategy) | Strategy for splitting documents into sections before extraction. Valid values: disabled, page, llm\_determined | `string` | `"disabled"` | no |
| <a name="input_summarization_guardrail"></a> [summarization\_guardrail](#input\_summarization\_guardrail) | Optional Bedrock guardrail to apply to summarization model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Optional model ID for document summarization. Overrides model\_id for this step. If not provided, model\_id is used. | `string` | `null` | no |
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
| <a name="output_evaluation_function_arn"></a> [evaluation\_function\_arn](#output\_evaluation\_function\_arn) | ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled). Null when evaluation is disabled. |
| <a name="output_evaluation_model"></a> [evaluation\_model](#output\_evaluation\_model) | The evaluation model being used (from variable override or config.yaml) |
| <a name="output_extraction_model"></a> [extraction\_model](#output\_extraction\_model) | The extraction model being used (from variable override or config.yaml) |
| <a name="output_is_summarization_enabled"></a> [is\_summarization\_enabled](#output\_is\_summarization\_enabled) | Whether document summarization is enabled |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Lambda functions used by the Bedrock LLM processor |
| <a name="output_max_processing_concurrency"></a> [max\_processing\_concurrency](#output\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks |
| <a name="output_ocr_max_workers"></a> [ocr\_max\_workers](#output\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing |
| <a name="output_schema_definition"></a> [schema\_definition](#output\_schema\_definition) | The JSON Schema definition for Bedrock LLM processor configuration |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_state_machine_name"></a> [state\_machine\_name](#output\_state\_machine\_name) | Name of the Step Functions state machine for document processing |
| <a name="output_summarization_model"></a> [summarization\_model](#output\_summarization\_model) | The summarization model being used (from variable override or config.yaml) |
