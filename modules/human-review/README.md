<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cognito_updater_function"></a> [cognito\_updater\_function](#module\_cognito\_updater\_function) | ./functions/cognito-updater | n/a |
| <a name="module_create_a2i_resources_function"></a> [create\_a2i\_resources\_function](#module\_create\_a2i\_resources\_function) | ./functions/create-a2i-resources | n/a |
| <a name="module_get_workforce_url_function"></a> [get\_workforce\_url\_function](#module\_get\_workforce\_url\_function) | ./functions/get-workforce-url | n/a |
| <a name="module_pattern2_hitl_process_function"></a> [pattern2\_hitl\_process\_function](#module\_pattern2\_hitl\_process\_function) | ./functions/pattern2-hitl-process | n/a |
| <a name="module_pattern2_hitl_status_update_function"></a> [pattern2\_hitl\_status\_update\_function](#module\_pattern2\_hitl\_status\_update\_function) | ./functions/pattern2-hitl-status-update | n/a |
| <a name="module_pattern2_hitl_wait_function"></a> [pattern2\_hitl\_wait\_function](#module\_pattern2\_hitl\_wait\_function) | ./functions/pattern2-hitl-wait | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.pattern2_hitl_status_change](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.pattern2_hitl_process_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cognito_user_pool_client.a2i_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_iam_role.a2i_flow_definition_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.a2i_flow_definition_sagemaker_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_permission.pattern2_hitl_process_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sagemaker_flow_definition.pattern2_hitl_flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_flow_definition) | resource |
| [aws_sagemaker_human_task_ui.pattern2_hitl_ui](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_human_task_ui) | resource |
| [aws_ssm_parameter.labeling_console_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.pattern2_flow_definition_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.pattern2_hitl_confidence_threshold](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.workforce_portal_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [null_resource.a2i_resources_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cognito_updater_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.get_workforce_url_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_pattern2_hitl"></a> [enable\_pattern2\_hitl](#input\_enable\_pattern2\_hitl) | Enable HITL support for Pattern-2 workflows | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_hitl_confidence_threshold"></a> [hitl\_confidence\_threshold](#input\_hitl\_confidence\_threshold) | Confidence threshold below which HITL review is triggered (0-100) | `number` | `80` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket for output storage | `string` | n/a | yes |
| <a name="input_private_workforce_arn"></a> [private\_workforce\_arn](#input\_private\_workforce\_arn) | ARN of the existing SageMaker private workforce | `string` | n/a | yes |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Name of the CloudFormation stack | `string` | n/a | yes |
| <a name="input_state_machine_arn"></a> [state\_machine\_arn](#input\_state\_machine\_arn) | ARN of the Step Functions state machine for Pattern-2 workflow | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB tracking table for HITL tokens | `string` | `""` | no |
| <a name="input_tracking_table_name"></a> [tracking\_table\_name](#input\_tracking\_table\_name) | Name of the DynamoDB tracking table for HITL tokens | `string` | `""` | no |
| <a name="input_user_pool_id"></a> [user\_pool\_id](#input\_user\_pool\_id) | ID of the Cognito User Pool | `string` | n/a | yes |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 working bucket for document processing | `string` | `""` | no |
| <a name="input_working_bucket_name"></a> [working\_bucket\_name](#input\_working\_bucket\_name) | Name of the S3 working bucket for document processing | `string` | `""` | no |
| <a name="input_workteam_name"></a> [workteam\_name](#input\_workteam\_name) | Name of the existing SageMaker workteam | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_definition_role_arn"></a> [flow\_definition\_role\_arn](#output\_flow\_definition\_role\_arn) | ARN of the IAM role for A2I Flow Definition |
| <a name="output_labeling_console_url_parameter"></a> [labeling\_console\_url\_parameter](#output\_labeling\_console\_url\_parameter) | SSM Parameter for labeling console URL |
| <a name="output_pattern2_flow_definition_arn"></a> [pattern2\_flow\_definition\_arn](#output\_pattern2\_flow\_definition\_arn) | ARN of the Pattern-2 A2I Flow Definition |
| <a name="output_pattern2_hitl_confidence_threshold"></a> [pattern2\_hitl\_confidence\_threshold](#output\_pattern2\_hitl\_confidence\_threshold) | Confidence threshold for Pattern-2 HITL triggering |
| <a name="output_pattern2_hitl_enabled"></a> [pattern2\_hitl\_enabled](#output\_pattern2\_hitl\_enabled) | Whether Pattern-2 HITL is enabled |
| <a name="output_pattern2_hitl_process_function_arn"></a> [pattern2\_hitl\_process\_function\_arn](#output\_pattern2\_hitl\_process\_function\_arn) | ARN of the Pattern-2 HITL Process Lambda function |
| <a name="output_pattern2_hitl_process_function_name"></a> [pattern2\_hitl\_process\_function\_name](#output\_pattern2\_hitl\_process\_function\_name) | Name of the Pattern-2 HITL Process Lambda function |
| <a name="output_pattern2_hitl_status_update_function_arn"></a> [pattern2\_hitl\_status\_update\_function\_arn](#output\_pattern2\_hitl\_status\_update\_function\_arn) | ARN of the Pattern-2 HITL Status Update Lambda function |
| <a name="output_pattern2_hitl_status_update_function_name"></a> [pattern2\_hitl\_status\_update\_function\_name](#output\_pattern2\_hitl\_status\_update\_function\_name) | Name of the Pattern-2 HITL Status Update Lambda function |
| <a name="output_pattern2_hitl_wait_function_arn"></a> [pattern2\_hitl\_wait\_function\_arn](#output\_pattern2\_hitl\_wait\_function\_arn) | ARN of the Pattern-2 HITL Wait Lambda function |
| <a name="output_pattern2_hitl_wait_function_name"></a> [pattern2\_hitl\_wait\_function\_name](#output\_pattern2\_hitl\_wait\_function\_name) | Name of the Pattern-2 HITL Wait Lambda function |
| <a name="output_pattern2_human_task_ui_arn"></a> [pattern2\_human\_task\_ui\_arn](#output\_pattern2\_human\_task\_ui\_arn) | ARN of the Pattern-2 A2I Human Task UI |
| <a name="output_user_pool_client_id"></a> [user\_pool\_client\_id](#output\_user\_pool\_client\_id) | ID of the Cognito User Pool Client for A2I |
| <a name="output_workforce_portal_url_parameter"></a> [workforce\_portal\_url\_parameter](#output\_workforce\_portal\_url\_parameter) | SSM Parameter for workforce portal URL |
| <a name="output_workteam_arn"></a> [workteam\_arn](#output\_workteam\_arn) | ARN of the SageMaker workteam (externally provided) |
| <a name="output_workteam_name"></a> [workteam\_name](#output\_workteam\_name) | Name of the SageMaker workteam (externally provided) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
