## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.user_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cognito_user_group.rbac](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_dynamodb_table.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.user_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.user_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.user_management_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.user_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.user_management](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_signup_email_domains"></a> [allowed\_signup\_email\_domains](#input\_allowed\_signup\_email\_domains) | Comma-separated list of email domains the user-management Lambda permits when<br>creating users (e.g. `example.com,corp.example.com`). Empty (the default)<br>disables domain restriction — any valid email is accepted. Wired into the<br>Lambda as `ALLOWED_SIGNUP_EMAIL_DOMAINS` (the exact env key read by<br>`sources/src/lambda/user_management/index.py`). | `string` | `""` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the base Lambda layer (idp\_common shared deps). Attached to the user-management Lambda via compact([...]). | `string` | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB configuration table the config-access resolvers read for `allowedConfigVersions` scoping (subtask 6.4). | `string` | `null` | no |
| <a name="input_configuration_table_name"></a> [configuration\_table\_name](#input\_configuration\_table\_name) | Name of the DynamoDB configuration table (env wiring for the config-access scoping path, subtask 6.4). | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the RBAC feature is enabled. The root forwards `var.rbac.enabled`<br>here. The root instantiates this submodule with `count`, so when RBAC is<br>disabled the submodule is not instantiated at all (default-off, Req 1.6);<br>this flag is also surfaced on the emitted contract's `enabled` field. | `bool` | `true` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the project KMS key used for server-side encryption of the Users table and the user-management Lambda log group (Req 2.2). | `string` | `null` | no |
| <a name="input_group_names"></a> [group\_names](#input\_group\_names) | Optional overrides for the four RBAC Cognito group names. Each key defaults<br>to its canonical name (`Admin`/`Author`/`Reviewer`/`Viewer`) so overriding<br>one or more does not change the default-on behavior of the four roles<br>(Req 1.5). Exactly four groups are always created. | <pre>object({<br>    admin    = optional(string, "Admin")<br>    author   = optional(string, "Author")<br>    reviewer = optional(string, "Reviewer")<br>    viewer   = optional(string, "Viewer")<br>  })</pre> | `{}` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the idp\_common Lambda layer, when supplied separately from the base layer. | `string` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for the RBAC Lambdas. | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days for the RBAC Lambdas. | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names created by this submodule (Users table, user-management Lambda, roles). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to all RBAC resources. | `map(string)` | `{}` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB tracking table the document-list filtering path reads for Reviewer document filtering (subtask 6.4). | `string` | `null` | no |
| <a name="input_tracking_table_name"></a> [tracking\_table\_name](#input\_tracking\_table\_name) | Name of the DynamoDB tracking table (env wiring for the document-list filtering path, subtask 6.4). | `string` | `null` | no |
| <a name="input_user_pool_arn"></a> [user\_pool\_arn](#input\_user\_pool\_arn) | ARN of the Cognito user pool. Used to scope the user-management Lambda's<br>Cognito admin permissions (group membership management) to exactly this pool<br>and no broader (Req 2.4). | `string` | `null` | no |
| <a name="input_user_pool_id"></a> [user\_pool\_id](#input\_user\_pool\_id) | ID of the Cognito user pool the four RBAC groups are created on and the<br>user-management Lambda administers. RBAC requires Cognito; the root enforces<br>this with a plan-time `check {}` (Req 4.4) mirroring the CDK `UserManagement`<br>constructor guard. | `string` | n/a | yes |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Optional VPC configuration for the user-management Lambda. When null, the Lambda is not placed in a VPC. | <pre>object({<br>    subnet_ids         = list(string)<br>    security_group_ids = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contract"></a> [contract](#output\_contract) | Feature-plugin contract consumed by `processing-environment-api` via its<br>`enabled_feature_contracts` input, mirroring the CDK<br>`api.enable(userManagement)` / `enableInApi()` mechanism.<br><br>Carries the Round 1 contract shape<br>`{ enabled, resolvers, iam_statements, environment, schema_additions }`:<br><br>  * `resolvers` — the five user-management operations<br>    (createUser/deleteUser/updateUser Mutations + listUsers/getMyProfile<br>    Queries), each pointing at the single user-management Lambda data source<br>    (named `user_management_data_source_name`). The API module creates that<br>    data source from `user_management_function_arn` and attaches these<br>    resolvers with the default Lambda Invoke/passthrough templates.<br>  * `iam_statements` — the least-privilege `Users`-table read path<br>    (GetItem/Query on the table + `EmailIndex`, plus conditional KMS) merged<br>    onto the AppSync resolver Lambda role so the document-list and<br>    configuration resolvers can apply Reviewer filtering and<br>    `allowedConfigVersions` scoping server-side.<br>  * `environment` — `{ USERS_TABLE_NAME }` merged onto the core/config<br>    resolver Lambdas so they resolve the `Users` table at runtime.<br>  * `schema_additions = null` — the `@aws_auth` directives and `User` types<br>    already ship in the read-only v0.5.12 schema; no SDL injection needed. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether the RBAC feature is enabled (mirrors var.enabled). |
| <a name="output_group_names"></a> [group\_names](#output\_group\_names) | The resolved RBAC Cognito group names keyed by canonical role<br>(`Admin`/`Author`/`Reviewer`/`Viewer`), reflecting any overrides. Consumed by<br>the IdP-federation submodule's group-mapping Lambda so federated users land<br>in the correct RBAC roles (Req 6.3). |
| <a name="output_reviewer_filtering_environment"></a> [reviewer\_filtering\_environment](#output\_reviewer\_filtering\_environment) | Environment-map fragment for the core/configuration AppSync resolver Lambdas<br>so they resolve the `Users` table at runtime. Carries `USERS_TABLE_NAME` —<br>the exact env key the shipped document-list and configuration resolvers read<br>(`sources/nested/appsync/src/lambda/{list_documents_gsi_resolver,<br>list_documents_range_resolver,configuration_resolver}/index.py`) to apply<br>Reviewer document filtering and `allowedConfigVersions` scoping server-side<br>(Req 3.1, 3.2, 3.3). Merged into the feature-plugin contract's `environment`<br>by subtask 6.5. |
| <a name="output_reviewer_filtering_iam_statements"></a> [reviewer\_filtering\_iam\_statements](#output\_reviewer\_filtering\_iam\_statements) | IAM statement fragments granting the AppSync resolver Lambda role the<br>least-privilege read path to the `Users` table required for Reviewer<br>filtering and `allowedConfigVersions` scoping: `dynamodb:GetItem`/`Query` on<br>the table and its `EmailIndex` GSI (the resolvers query by email via<br>`IndexName="EmailIndex"`), plus `kms:Decrypt`/`DescribeKey` scoped to the<br>encryption key when the table is encrypted. Merged into the feature-plugin<br>contract's `iam_statements` by subtask 6.5. |
| <a name="output_user_management_data_source_name"></a> [user\_management\_data\_source\_name](#output\_user\_management\_data\_source\_name) | Deterministic AppSync Lambda data-source name the API module's<br>`feature-plugins.tf` creates from `user_management_function_arn` and that<br>every user-management resolver in the contract references. Exposed<br>separately so the API module can name the `aws_appsync_datasource` it<br>creates to match the contract's resolver `data_source` references. |
| <a name="output_user_management_function_arn"></a> [user\_management\_function\_arn](#output\_user\_management\_function\_arn) | ARN of the user-management Lambda. Consumed by the API module's<br>`feature-plugins.tf` (via the Round 1 contract, subtask 6.5) to create the<br>`aws_appsync_datasource` + the createUser/updateUser/deleteUser/listUsers/<br>getMyProfile resolvers (mirrors CDK `enableInApi()`). |
| <a name="output_user_management_function_name"></a> [user\_management\_function\_name](#output\_user\_management\_function\_name) | Name of the user-management Lambda function. |
| <a name="output_users_table_arn"></a> [users\_table\_arn](#output\_users\_table\_arn) | ARN of the `Users` DynamoDB table. Used to scope the user-management Lambda's<br>least-privilege DynamoDB access to exactly this table (subtask 6.3, Req 2.4)<br>and contributed to the AppSync Lambda role's read path via the feature-plugin<br>contract (subtask 6.5). |
| <a name="output_users_table_name"></a> [users\_table\_name](#output\_users\_table\_name) | Name of the `Users` DynamoDB table. Consumed by the user-management Lambda<br>(subtask 6.3, `USERS_TABLE_NAME`) and threaded onto the AppSync resolver<br>Lambdas via the feature-plugin contract (subtask 6.5) so the document-list<br>and config-access resolvers can apply Reviewer filtering and<br>`allowedConfigVersions` scoping (subtask 6.4). |
