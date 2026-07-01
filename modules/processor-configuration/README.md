## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.49.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.dynamodb_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.lambda_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.dynamodb_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_vpc_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.configuration_seeder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.seed_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.seed_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.seed_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.seed_schema](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_configurations"></a> [additional\_configurations](#input\_additional\_configurations) | Extra non-active, editable configuration versions seeded as Config#<name> rows (version\_name => config object). Unlike managed baselines these are Managed=false, so they remain editable in the UI. A top-level `bda_project_arn` key on an entry is lifted out of the config body and used to link that version to a Bedrock Data Automation project (it is never seeded as config data). | `any` | `{}` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the IDPCommonBaseLayer Lambda layer. The seeder Lambda needs<br>`idp_common` available so it can call `merge_config_with_defaults`<br>when storing a `Default` configuration. Without this layer attached<br>the seeder still functions, but it skips the merge step and the<br>runtime classification/extraction Lambdas will fail with<br>`No system_prompt found in classification configuration`. | `string` | `null` | no |
| <a name="input_configuration"></a> [configuration](#input\_configuration) | JSON configuration object to store under 'Default' key | `any` | n/a | yes |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB table to store configuration | `string` | n/a | yes |
| <a name="input_default_bda_project_arn"></a> [default\_bda\_project\_arn](#input\_default\_bda\_project\_arn) | Optional Bedrock Data Automation project ARN used to LINK the `default`<br>configuration version to a BDA project during seeding. When set, it is<br>passed as the seeder's `BdaProjectArn` for the `default` version so that<br>version routes to BDA out of the box (used by the `bda-processor` façade).<br>It also acts as the last-resort fallback `BdaProjectArn` for any<br>`additional_configurations` version that sets `use_bda: true` without its<br>own top-level `bda_project_arn` and when no `fallback_bda_project_arn` is<br>set. Leave null (the default) to seed no default project link — pipeline<br>façades keep their default pipeline (R5.6). | `string` | `null` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting DynamoDB table | `string` | `null` | no |
| <a name="input_fallback_bda_project_arn"></a> [fallback\_bda\_project\_arn](#input\_fallback\_bda\_project\_arn) | Optional Bedrock Data Automation project ARN used ONLY as the fallback<br>`BdaProjectArn` for `additional_configurations` versions that set<br>`use_bda: true` but do not carry their own top-level `bda_project_arn`.<br>Unlike `default_bda_project_arn`, this does NOT link the `default`<br>configuration version, so pipeline façades (`bedrock-llm`,<br>`sagemaker-udop`) can supply a fallback project for extra BDA-linked<br>versions while keeping their default pipeline (R5.6). Resolution precedence<br>per additional version: per-version `bda_project_arn` > this fallback ><br>`default_bda_project_arn` > none (route to pipeline at runtime). | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer (full processor-extras flavor). Optional — `base_layer_arn` alone is enough for the seeder. | `string` | `null` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_schema"></a> [schema](#input\_schema) | JSON schema object to store under 'Schema' key | `any` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | VPC configuration for Lambda function | <pre>object({<br>    subnet_ids         = list(string)<br>    security_group_ids = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_default_seeded"></a> [default\_seeded](#output\_default\_seeded) | Result of seeding the Default configuration |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the configuration seeder Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the configuration seeder Lambda function |
| <a name="output_managed_versions_seeded"></a> [managed\_versions\_seeded](#output\_managed\_versions\_seeded) | Names of the managed baseline configuration versions seeded with Managed = true. |
| <a name="output_schema_seeded"></a> [schema\_seeded](#output\_schema\_seeded) | Result of seeding the Schema |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.49.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.dynamodb_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.lambda_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.dynamodb_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_vpc_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.configuration_seeder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.seed_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.seed_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.seed_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.seed_schema](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_configurations"></a> [additional\_configurations](#input\_additional\_configurations) | Extra non-active, editable configuration versions seeded as Config#<name> rows (version\_name => config object), Managed=false so they stay editable in the UI. A top-level `bda_project_arn` key on an entry is lifted out of the config body to link that version to a BDA project (never seeded as config data). | `any` | `{}` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the IDPCommonBaseLayer Lambda layer. The seeder Lambda needs<br>`idp_common` available so it can call `merge_config_with_defaults`<br>when storing a `Default` configuration. Without this layer attached<br>the seeder still functions, but it skips the merge step and the<br>runtime classification/extraction Lambdas will fail with<br>`No system_prompt found in classification configuration`. | `string` | `null` | no |
| <a name="input_configuration"></a> [configuration](#input\_configuration) | JSON configuration object to store under 'Default' key | `any` | n/a | yes |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB table to store configuration | `string` | n/a | yes |
| <a name="input_default_bda_project_arn"></a> [default\_bda\_project\_arn](#input\_default\_bda\_project\_arn) | Optional BDA project ARN that links the `default` config version to a BDA<br>project at seed time (set by the bda-processor façade). Also the last-resort<br>fallback for use\_bda:true additional versions. Null (default) links no default<br>project, so pipeline façades keep their default pipeline. | `string` | `null` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting DynamoDB table | `string` | `null` | no |
| <a name="input_fallback_bda_project_arn"></a> [fallback\_bda\_project\_arn](#input\_fallback\_bda\_project\_arn) | Optional BDA project ARN used only as the fallback for use\_bda:true additional<br>versions that omit their own `bda_project_arn`. Does not link the `default`<br>version, so pipeline façades can link extra BDA versions while keeping their<br>default pipeline. Precedence per version: per-version bda\_project\_arn ><br>this fallback > default\_bda\_project\_arn > none. | `string` | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP common Lambda layer (full processor-extras flavor). Optional — `base_layer_arn` alone is enough for the seeder. | `string` | `null` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_schema"></a> [schema](#input\_schema) | JSON schema object to store under 'Schema' key | `any` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | VPC configuration for Lambda function | <pre>object({<br>    subnet_ids         = list(string)<br>    security_group_ids = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_default_seeded"></a> [default\_seeded](#output\_default\_seeded) | Result of seeding the Default configuration |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the configuration seeder Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the configuration seeder Lambda function |
| <a name="output_managed_versions_seeded"></a> [managed\_versions\_seeded](#output\_managed\_versions\_seeded) | Names of the managed baseline configuration versions seeded with Managed = true. |
| <a name="output_schema_seeded"></a> [schema\_seeded](#output\_schema\_seeded) | Result of seeding the Schema |
<!-- END_TF_DOCS -->