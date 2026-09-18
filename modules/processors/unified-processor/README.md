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
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_processor_configuration"></a> [processor\_configuration](#module\_processor\_configuration) | ../../processor-configuration | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.bda_completion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.bda_completion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.assessment_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.bda_completion_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.bda_invoke_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.bda_ocr_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.bda_process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.evaluation_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.extraction_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.ocr_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.pipeline_hooks_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.rule_validation_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.rule_validation_orchestration_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.rule_validation_policy_classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.summarization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assessment_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.bda_completion_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.bda_invoke_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.bda_ocr_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.bda_process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.evaluation_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.extraction_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ocr_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.pipeline_hooks_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rule_validation_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.summarization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.assessment_bedrock_hub_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.assessment_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.assessment_lambda_appsync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.assessment_lambda_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.bda_completion_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.bda_invoke_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.bda_ocr_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.bda_process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.classification_bedrock_hub_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.classification_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.classification_lambda_sagemaker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.evaluation_bedrock_hub_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.evaluation_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.evaluation_lambda_appsync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.extraction_bedrock_hub_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.extraction_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_hook_inference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ocr_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ocr_lambda_bda_ocr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.pipeline_hooks_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.process_results_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.rule_validation_bedrock_hub_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.rule_validation_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.rule_validation_orchestration_extras](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.rule_validation_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.state_machine_hook_inference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.summarization_bedrock_hub_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.summarization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.assessment_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.assessment_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_completion_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_completion_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_invoke_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_invoke_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_ocr_project_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_ocr_project_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_process_results_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bda_process_results_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.classification_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.classification_lambda_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.classification_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_lambda_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.evaluation_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.extraction_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.extraction_lambda_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.extraction_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ocr_lambda_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ocr_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ocr_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.pipeline_hooks_dispatcher_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.pipeline_hooks_dispatcher_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_results_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_results_lambda_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_results_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rule_validation_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.summarization_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.summarization_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.summarization_lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.assessment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.bda_completion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.bda_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.bda_ocr_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.bda_process_results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.classification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.evaluation_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.extraction](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.ocr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.pipeline_hooks_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.process_results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.rule_validation_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.rule_validation_orchestration_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.rule_validation_policy_classification_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.summarization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.bda_ocr_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_permission.bda_completion_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sfn_state_machine.document_processing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_sqs_queue.bda_completion_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.bda_completion_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [terraform_data.bedrock_model_id_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_sleep.wait_for_bda_ocr_project_iam](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.assessment_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.bda_completion_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.bda_invoke_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.bda_ocr_project](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.bda_process_results_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.classification_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.evaluation_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.extraction_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.ocr_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.pipeline_hooks_dispatcher](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.process_results_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.rule_validation_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.rule_validation_orchestration_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.rule_validation_policy_classification_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.summarization_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_configurations"></a> [additional\_configurations](#input\_additional\_configurations) | Extra non-active, editable configuration versions seeded alongside the default (version\_name => config object). Shown in the UI version dropdown. | `any` | `{}` | no |
| <a name="input_allowed_bedrock_model_ids"></a> [allowed\_bedrock\_model\_ids](#input\_allowed\_bedrock\_model\_ids) | Bedrock model IDs every processing step is allowed to invoke, on top of the models resolved from the seeded configs. Set this for models operators will select in the UI later, which Terraform cannot see. Use ["*"] to allow any Bedrock model. Empty (default) grants only the resolved models. | `list(string)` | `[]` | no |
| <a name="input_api_arn"></a> [api\_arn](#input\_api\_arn) | ARN of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_graphql_url"></a> [api\_graphql\_url](#input\_api\_graphql\_url) | GraphQL URL of the API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the GraphQL API that provides interfaces for querying document status and metadata | `string` | `null` | no |
| <a name="input_assessment_guardrail"></a> [assessment\_guardrail](#input\_assessment\_guardrail) | Optional Bedrock guardrail configuration for assessment model interactions | <pre>object({<br>    guardrail_id      = string<br>    guardrail_version = string<br>  })</pre> | `null` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the shared base Lambda layer (idp\_common with docs\_service extras, v0.4.11+) | `string` | `null` | no |
| <a name="input_bda_project_arn"></a> [bda\_project\_arn](#input\_bda\_project\_arn) | Optional BDA project ARN used only as the fallback link for use\_bda:true<br>additional versions that omit their own per-version `bda_project_arn`<br>(threaded to processor-configuration as fallback\_bda\_project\_arn). Does not<br>relink the `default` version. Seeding fallback only — both branches are<br>always deployed regardless of this value. | `string` | `null` | no |
| <a name="input_bedrock_assume_role_external_id"></a> [bedrock\_assume\_role\_external\_id](#input\_bedrock\_assume\_role\_external\_id) | Optional ExternalId passed to sts:AssumeRole when assuming var.bedrock\_hub\_role\_arn (rendered as BEDROCK\_ASSUME\_ROLE\_EXTERNAL\_ID). Only used when bedrock\_hub\_role\_arn is set. Common requirement for cross-account trust policies. | `string` | `""` | no |
| <a name="input_bedrock_hub_role_arn"></a> [bedrock\_hub\_role\_arn](#input\_bedrock\_hub\_role\_arn) | Optional ARN of a centralized 'hub' account role that owns Bedrock access (BedrockHubRoleArn, v0.5.12). When non-empty, the Bedrock-calling processing Lambdas are granted sts:AssumeRole scoped to exactly this ARN and receive BEDROCK\_ASSUME\_ROLE\_ARN in their environment so they assume it for Bedrock calls. When empty (default), processors use same-account Bedrock access unchanged (fully additive). | `string` | `""` | no |
| <a name="input_classification_backend"></a> [classification\_backend](#input\_classification\_backend) | Classification backend: 'bedrock' (default) uses the vendored Bedrock classification function; 'sagemaker' uses idp\_common's native SageMaker UDOP path (classify\_page\_sagemaker) against classification\_sagemaker\_endpoint\_arn. | `string` | `"bedrock"` | no |
| <a name="input_classification_guardrail"></a> [classification\_guardrail](#input\_classification\_guardrail) | Optional Bedrock guardrail to apply to classification model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_classification_max_workers"></a> [classification\_max\_workers](#input\_classification\_max\_workers) | The maximum number of concurrent workers for document classification | `number` | `20` | no |
| <a name="input_classification_sagemaker_endpoint_arn"></a> [classification\_sagemaker\_endpoint\_arn](#input\_classification\_sagemaker\_endpoint\_arn) | ARN of the SageMaker endpoint used for classification when classification\_backend = 'sagemaker'. The classification Lambda is granted sagemaker:InvokeEndpoint on it and receives its name via SAGEMAKER\_ENDPOINT\_NAME. | `string` | `null` | no |
| <a name="input_concurrency_table_arn"></a> [concurrency\_table\_arn](#input\_concurrency\_table\_arn) | ARN of the DynamoDB table that manages concurrency limits for document processing | `string` | n/a | yes |
| <a name="input_config"></a> [config](#input\_config) | Optional configuration values to override defaults from config.yaml | `any` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration settings | `string` | n/a | yes |
| <a name="input_default_bda_project_arn"></a> [default\_bda\_project\_arn](#input\_default\_bda\_project\_arn) | Optional BDA project ARN that links the `default` config version to a BDA<br>project at seed time (set by the bda-processor façade so BDA works out of the<br>box). Also the last-resort fallback for that façade's use\_bda:true additional<br>versions. Pipeline façades leave this null so their default stays pipeline.<br>Seeding input only — it does not gate whether the BDA branch is deployed. | `string` | `null` | no |
| <a name="input_enable_agentic_extraction"></a> [enable\_agentic\_extraction](#input\_enable\_agentic\_extraction) | Whether to enable agentic extraction using Strands agent framework | `bool` | `false` | no |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | Whether the API is enabled | `bool` | `false` | no |
| <a name="input_enable_bda_ocr_backend"></a> [enable\_bda\_ocr\_backend](#input\_enable\_bda\_ocr\_backend) | Provision the deployment-scoped Bedrock Data Automation OCR project required<br>by the IDP v0.6 `ocr.backend: bda` configuration setting, which runs a BDA<br>standard-output SYNC project as a pure OCR engine in place of Textract.<br><br>Set this to true only if a config version selects `ocr.backend: bda`, and only<br>in a region where Bedrock Data Automation is available. Upstream provisions<br>the project unconditionally; it is gated here because an unconditional<br>control-plane create fails `apply` in regions without BDA. Left false, the OCR<br>function receives an empty BDA\_OCR\_PROJECT\_ARN and the `bda` backend errors<br>clearly — the same behaviour upstream documents for unsupported regions.<br><br>Independent of the BDA *processing* branch (`use_bda` on a config version),<br>which uses async invocation against a customer-supplied BDA project. | `bool` | `false` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Use this instead of checking encryption\_key\_arn != null to avoid unknown value issues in for\_each/count. | `bool` | `false` | no |
| <a name="input_enable_hitl"></a> [enable\_hitl](#input\_enable\_hitl) | Whether to enable Human-in-the-Loop (HITL) functionality for document review | `bool` | `false` | no |
| <a name="input_enable_hook_inference"></a> [enable\_hook\_inference](#input\_enable\_hook\_inference) | Whether any Lambda hook is wired. Gates the hook-inference IAM policy on a plan-time-known value (the hook function names can be derived from random\_string and thus unknown at plan). | `bool` | `false` | no |
| <a name="input_enable_rule_validation"></a> [enable\_rule\_validation](#input\_enable\_rule\_validation) | Enable rule validation Lambda functions for compliance assessment (v0.4.13+) | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources | `string` | `null` | no |
| <a name="input_evaluation_baseline_bucket_arn"></a> [evaluation\_baseline\_bucket\_arn](#input\_evaluation\_baseline\_bucket\_arn) | ARN of the S3 bucket containing baseline documents for evaluation. Required when evaluation\_enabled is true. | `string` | `null` | no |
| <a name="input_evaluation_enabled"></a> [evaluation\_enabled](#input\_evaluation\_enabled) | Controls whether extraction results are evaluated for accuracy | `bool` | `false` | no |
| <a name="input_evaluation_layer_arn"></a> [evaluation\_layer\_arn](#input\_evaluation\_layer\_arn) | ARN of the dedicated evaluation Lambda layer (idp\_common with evaluation+docs\_service extras, includes munkres/numpy). Required when evaluation\_enabled=true. | `string` | `null` | no |
| <a name="input_extraction_guardrail"></a> [extraction\_guardrail](#input\_extraction\_guardrail) | Optional Bedrock guardrail to apply to extraction model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer containing shared utilities | `string` | n/a | yes |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_is_summarization_enabled"></a> [is\_summarization\_enabled](#input\_is\_summarization\_enabled) | Controls whether document summarization is enabled | `bool` | `false` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). Must match the architecture the idp\_common layers were built for; mismatches break native deps (e.g. pydantic\_core). | `string` | `"arm64"` | no |
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
| <a name="input_name"></a> [name](#input\_name) | Name for the unified processor engine resources | `string` | `"unified-processor"` | no |
| <a name="input_ocr_max_workers"></a> [ocr\_max\_workers](#input\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing | `number` | `20` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results are stored | `string` | n/a | yes |
| <a name="input_reporting_bucket_name"></a> [reporting\_bucket\_name](#input\_reporting\_bucket\_name) | Name of the reporting bucket the evaluation function forwards accuracy results to. Leave null to disable the evaluation reporting fan-out. | `string` | `null` | no |
| <a name="input_review_agent_model"></a> [review\_agent\_model](#input\_review\_agent\_model) | Bedrock model ID for the review agent. If empty, uses the extraction model. | `string` | `""` | no |
| <a name="input_save_reporting_function_arn"></a> [save\_reporting\_function\_arn](#input\_save\_reporting\_function\_arn) | ARN of the save\_reporting\_data Lambda, used to scope the evaluation function's invoke grant. | `string` | `null` | no |
| <a name="input_save_reporting_function_name"></a> [save\_reporting\_function\_name](#input\_save\_reporting\_function\_name) | Name of the save\_reporting\_data Lambda the evaluation function invokes to persist accuracy results. Leave null to disable the evaluation reporting fan-out. | `string` | `null` | no |
| <a name="input_section_splitting_strategy"></a> [section\_splitting\_strategy](#input\_section\_splitting\_strategy) | Strategy for splitting documents into sections before extraction. Valid values: disabled, page, llm\_determined | `string` | `"disabled"` | no |
| <a name="input_seed_managed_configs"></a> [seed\_managed\_configs](#input\_seed\_managed\_configs) | Seed the managed baseline configuration versions as non-active reference rows. | `bool` | `true` | no |
| <a name="input_summarization_guardrail"></a> [summarization\_guardrail](#input\_summarization\_guardrail) | Optional Bedrock guardrail to apply to summarization model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table that tracks document processing status and metadata | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for VPC configuration | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for VPC configuration | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket used for temporary processing files | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_classification_max_workers"></a> [classification\_max\_workers](#output\_classification\_max\_workers) | The maximum number of concurrent workers for document classification |
| <a name="output_classification_model"></a> [classification\_model](#output\_classification\_model) | The classification model the runtime will invoke (resolved: per-step variable > config YAML > system default > model\_id). This is the model the Bedrock IAM grant is scoped to. |
| <a name="output_configuration"></a> [configuration](#output\_configuration) | Configuration for the unified processor engine |
| <a name="output_evaluation_enabled"></a> [evaluation\_enabled](#output\_evaluation\_enabled) | Whether extraction results evaluation is enabled |
| <a name="output_evaluation_function_arn"></a> [evaluation\_function\_arn](#output\_evaluation\_function\_arn) | ARN of the evaluation Lambda function (used by the Step Functions state machine when evaluation is enabled). Null when evaluation is disabled. |
| <a name="output_evaluation_model"></a> [evaluation\_model](#output\_evaluation\_model) | The evaluation model the runtime will invoke (resolved: per-step variable > config YAML > system default > model\_id), or null when evaluation is off. |
| <a name="output_extraction_model"></a> [extraction\_model](#output\_extraction\_model) | The extraction model the runtime will invoke (resolved: per-step variable > config YAML > system default > model\_id). This is the model the Bedrock IAM grant is scoped to. |
| <a name="output_is_summarization_enabled"></a> [is\_summarization\_enabled](#output\_is\_summarization\_enabled) | Whether document summarization is enabled |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Lambda functions used by the unified processor engine |
| <a name="output_max_processing_concurrency"></a> [max\_processing\_concurrency](#output\_max\_processing\_concurrency) | Maximum number of concurrent document processing tasks |
| <a name="output_model_permission_debug"></a> [model\_permission\_debug](#output\_model\_permission\_debug) | Debug information for model permissions |
| <a name="output_ocr_max_workers"></a> [ocr\_max\_workers](#output\_ocr\_max\_workers) | The maximum number of concurrent workers for OCR processing |
| <a name="output_schema_definition"></a> [schema\_definition](#output\_schema\_definition) | The JSON Schema definition for unified processor engine configuration |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | ARN of the Step Functions state machine for document processing |
| <a name="output_state_machine_name"></a> [state\_machine\_name](#output\_state\_machine\_name) | Name of the Step Functions state machine for document processing |
| <a name="output_state_machine_start_at"></a> [state\_machine\_start\_at](#output\_state\_machine\_start\_at) | The StartAt state of the document-processing state machine. Always 'PreprocessingHook' (IDP v0.6): the preprocessing extension point runs before the BDA/pipeline routing decision, so it fires in both modes. Documents then route at runtime by their config version's use\_bda flag. |
| <a name="output_state_machine_state_names"></a> [state\_machine\_state\_names](#output\_state\_machine\_state\_names) | The set of state names in the document-processing state machine definition (both BDA-branch and pipeline-branch states). |
| <a name="output_state_machine_transition_targets"></a> [state\_machine\_transition\_targets](#output\_state\_machine\_transition\_targets) | Every state name referenced as a transition target by a top-level state (Next / Choices[*].Next / Catch[*].Next / Default). Exposed for graph-closure assertions in terraform test. |
| <a name="output_summarization_model"></a> [summarization\_model](#output\_summarization\_model) | The summarization model the runtime will invoke (resolved: per-step variable > config YAML > system default > model\_id), or null when summarization is off. |
