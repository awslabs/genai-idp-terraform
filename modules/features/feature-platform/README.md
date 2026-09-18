## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.feature](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.installed_features](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.feature](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_ssm_parameter.webui_bucket_policy_statement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [archive_file.feature](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_group_name"></a> [admin\_group\_name](#input\_admin\_group\_name) | Cognito admin group permitted to call privileged feature mutations. | `string` | `"Admin"` | no |
| <a name="input_artifact_region"></a> [artifact\_region](#input\_artifact\_region) | Region for the OSS feature template artifacts bucket. | `string` | `""` | no |
| <a name="input_catalog_key"></a> [catalog\_key](#input\_catalog\_key) | S3 key of the feature catalog manifest. | `string` | `"feature-platform/catalog.json"` | no |
| <a name="input_configuration_bucket_name"></a> [configuration\_bucket\_name](#input\_configuration\_bucket\_name) | Configuration bucket holding the feature catalog (catalog.json). | `string` | `""` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ConfigurationTable ARN. | `string` | n/a | yes |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | ConfigurationTable name (for hook registration and config presets). | `string` | n/a | yes |
| <a name="input_default_buyer_account_id"></a> [default\_buyer\_account\_id](#input\_default\_buyer\_account\_id) | Default buyer AWS account id for deterministic GetEntitlements filtering. | `string` | `""` | no |
| <a name="input_default_customer_identifier"></a> [default\_customer\_identifier](#input\_default\_customer\_identifier) | Default Marketplace customer identifier. | `string` | `""` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | Customer-managed KMS key ARN (optional). | `string` | `null` | no |
| <a name="input_feature_offer_id_map"></a> [feature\_offer\_id\_map](#input\_feature\_offer\_id\_map) | JSON map of feature id -> Marketplace offer id. | `string` | `"{}"` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). Must match the architecture the idp\_common layers were built for; mismatches break native deps (e.g. pydantic\_core). | `string` | `"arm64"` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | Lambda X-Ray tracing mode. | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Lambda log level. | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days. | `number` | `30` | no |
| <a name="input_main_stack_name"></a> [main\_stack\_name](#input\_main\_stack\_name) | Logical stack/deployment name; used to scope feature stack ARNs (<name>-feature-*). | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names. | `string` | n/a | yes |
| <a name="input_seller_bucket_object_arns"></a> [seller\_bucket\_object\_arns](#input\_seller\_bucket\_object\_arns) | Seller bucket object ARNs the platform may GetObject (marketplace features). | `list(string)` | `[]` | no |
| <a name="input_simulator_entitlement_endpoint"></a> [simulator\_entitlement\_endpoint](#input\_simulator\_entitlement\_endpoint) | Marketplace simulator entitlement endpoint (empty for real Marketplace / auto-subscribe). | `string` | `""` | no |
| <a name="input_subscription_mode"></a> [subscription\_mode](#input\_subscription\_mode) | Subscription mode / simulator source tag (e.g. auto-subscribe). | `string` | `"auto-subscribe"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_field_functions"></a> [field\_functions](#output\_field\_functions) | API field name -> backing Lambda ARN, for the REST dispatcher's<br>field-function map (IDP v0.6.4).<br><br>Replaces the AppSync data sources and per-field resolvers this module used to<br>create. The API module merges this into `local.field_function_map` in<br>dispatcher.tf; the dispatcher then invokes the mapped Lambda with an<br>AppSync-shaped event, so the Lambdas themselves are unchanged.<br><br>Keys are the field names exactly as the client sends them to<br>`POST /op/{field}`. They must NOT be pre-collapsed onto a canonical key:<br>the dispatcher's FIELD\_ALIASES table has no entries for feature-platform<br>fields, so every field resolves 1:1. Several fields intentionally share one<br>ARN (e.g. registerFeature / unregisterFeature both hit register\_feature),<br>which is fine — the dispatcher's invoke grant de-duplicates by ARN. |
| <a name="output_function_arns"></a> [function\_arns](#output\_function\_arns) | Map of feature-platform Lambda function name -> ARN. |
| <a name="output_installed_features_table_arn"></a> [installed\_features\_table\_arn](#output\_installed\_features\_table\_arn) | ARN of the InstalledFeatures registry table. |
| <a name="output_installed_features_table_name"></a> [installed\_features\_table\_name](#output\_installed\_features\_table\_name) | Name of the InstalledFeatures registry table. |
