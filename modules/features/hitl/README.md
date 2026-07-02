## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_data_source_name"></a> [data\_source\_name](#input\_data\_source\_name) | Name of the AppSync data source that fronts the `complete_section_review`<br>Lambda. The API module creates this data source (it owns the inline HITL<br>Lambda); the contract references it by name so the composed resolvers attach<br>to it. Defaults to the name used by `processing-environment-api`. | `string` | `"CompleteSectionReviewDS"` | no |
| <a name="input_document_queue_arn"></a> [document\_queue\_arn](#input\_document\_queue\_arn) | ARN of the document SQS queue used to trigger reprocessing after review. Optional. | `string` | `null` | no |
| <a name="input_document_queue_url"></a> [document\_queue\_url](#input\_document\_queue\_url) | URL of the document SQS queue (env wiring). Optional. | `string` | `null` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used to encrypt HITL resources. Optional. | `string` | `null` | no |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the input S3 bucket the HITL review Lambda reads. | `string` | `null` | no |
| <a name="input_input_bucket_name"></a> [input\_bucket\_name](#input\_input\_bucket\_name) | Name of the input S3 bucket (env wiring). | `string` | `null` | no |
| <a name="input_lambda_function_arn"></a> [lambda\_function\_arn](#input\_lambda\_function\_arn) | ARN of the `complete_section_review` Lambda. Used to scope the<br>`lambda:InvokeFunction` statement the AppSync/API role needs to invoke the<br>HITL resolvers. When null, the invoke statement is omitted from the<br>contract (caller wires the permission directly). | `string` | `null` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the output S3 bucket the HITL review Lambda reads/writes. | `string` | `null` | no |
| <a name="input_output_bucket_name"></a> [output\_bucket\_name](#input\_output\_bucket\_name) | Name of the output S3 bucket (env wiring). | `string` | `null` | no |
| <a name="input_partition"></a> [partition](#input\_partition) | AWS partition (e.g. aws, aws-us-gov). Used to render IAM resource ARNs. | `string` | `"aws"` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the document tracking DynamoDB table the HITL review Lambda reads/writes. | `string` | `null` | no |
| <a name="input_tracking_table_name"></a> [tracking\_table\_name](#input\_tracking\_table\_name) | Name of the document tracking DynamoDB table (env wiring for the HITL review Lambda). | `string` | `null` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the working S3 bucket the HITL review Lambda reads/writes. Optional. | `string` | `null` | no |
| <a name="input_working_bucket_name"></a> [working\_bucket\_name](#input\_working\_bucket\_name) | Name of the working S3 bucket (env wiring). Optional. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contract"></a> [contract](#output\_contract) | Feature-plugin contract consumed by `processing-environment-api` via its<br>`enabled_feature_contracts` input. Mirrors the CDK `api.enable(feature)`<br>mechanism: resolver definitions, IAM statement fragments, and environment<br>wiring for the inline-HITL `complete_section_review` operations. |
