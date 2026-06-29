## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_pattern2_hitl_process_function"></a> [pattern2\_hitl\_process\_function](#module\_pattern2\_hitl\_process\_function) | ./functions/pattern2-hitl-process | n/a |
| <a name="module_pattern2_hitl_status_update_function"></a> [pattern2\_hitl\_status\_update\_function](#module\_pattern2\_hitl\_status\_update\_function) | ./functions/pattern2-hitl-status-update | n/a |
| <a name="module_pattern2_hitl_wait_function"></a> [pattern2\_hitl\_wait\_function](#module\_pattern2\_hitl\_wait\_function) | ./functions/pattern2-hitl-wait | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_pattern2_hitl"></a> [enable\_pattern2\_hitl](#input\_enable\_pattern2\_hitl) | Enable HITL support for Pattern-2 workflows | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_hitl_confidence_threshold"></a> [hitl\_confidence\_threshold](#input\_hitl\_confidence\_threshold) | Confidence threshold below which HITL review is triggered (0-100) | `number` | `80` | no |
| <a name="input_hitl_status_update_image_uri"></a> [hitl\_status\_update\_image\_uri](#input\_hitl\_status\_update\_image\_uri) | ECR image URI for the HITL status update Lambda function (Docker deployment). If null, falls back to zip deployment. | `string` | `null` | no |
| <a name="input_hitl_wait_image_uri"></a> [hitl\_wait\_image\_uri](#input\_hitl\_wait\_image\_uri) | ECR image URI for the HITL wait Lambda function (Docker deployment). If null, falls back to zip deployment. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket for output storage | `string` | n/a | yes |
| <a name="input_state_machine_arn"></a> [state\_machine\_arn](#input\_state\_machine\_arn) | ARN of the Step Functions state machine for Pattern-2 workflow | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB tracking table for HITL tokens | `string` | `""` | no |
| <a name="input_tracking_table_name"></a> [tracking\_table\_name](#input\_tracking\_table\_name) | Name of the DynamoDB tracking table for HITL tokens | `string` | `""` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions | `list(string)` | `[]` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 working bucket for document processing | `string` | `""` | no |
| <a name="input_working_bucket_name"></a> [working\_bucket\_name](#input\_working\_bucket\_name) | Name of the S3 working bucket for document processing | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pattern2_hitl_confidence_threshold"></a> [pattern2\_hitl\_confidence\_threshold](#output\_pattern2\_hitl\_confidence\_threshold) | Confidence threshold for Pattern-2 HITL triggering |
| <a name="output_pattern2_hitl_enabled"></a> [pattern2\_hitl\_enabled](#output\_pattern2\_hitl\_enabled) | Whether Pattern-2 HITL is enabled |
| <a name="output_pattern2_hitl_process_function_arn"></a> [pattern2\_hitl\_process\_function\_arn](#output\_pattern2\_hitl\_process\_function\_arn) | ARN of the Pattern-2 HITL Process Lambda function |
| <a name="output_pattern2_hitl_process_function_name"></a> [pattern2\_hitl\_process\_function\_name](#output\_pattern2\_hitl\_process\_function\_name) | Name of the Pattern-2 HITL Process Lambda function |
| <a name="output_pattern2_hitl_status_update_function_arn"></a> [pattern2\_hitl\_status\_update\_function\_arn](#output\_pattern2\_hitl\_status\_update\_function\_arn) | ARN of the Pattern-2 HITL Status Update Lambda function |
| <a name="output_pattern2_hitl_status_update_function_name"></a> [pattern2\_hitl\_status\_update\_function\_name](#output\_pattern2\_hitl\_status\_update\_function\_name) | Name of the Pattern-2 HITL Status Update Lambda function |
| <a name="output_pattern2_hitl_wait_function_arn"></a> [pattern2\_hitl\_wait\_function\_arn](#output\_pattern2\_hitl\_wait\_function\_arn) | ARN of the Pattern-2 HITL Wait Lambda function |
| <a name="output_pattern2_hitl_wait_function_name"></a> [pattern2\_hitl\_wait\_function\_name](#output\_pattern2\_hitl\_wait\_function\_name) | Name of the Pattern-2 HITL Wait Lambda function |
