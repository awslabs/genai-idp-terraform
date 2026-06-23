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
| [aws_cloudwatch_log_group.group_mapping](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cognito_identity_provider.external](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_provider) | resource |
| [aws_iam_role.group_mapping](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.group_mapping_cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.group_mapping_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.group_mapping](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.group_mapping_cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.group_mapping](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret_version.oidc_client_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_ssm_parameter.oidc_client_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attribute_mapping"></a> [attribute\_mapping](#input\_attribute\_mapping) | Map of Cognito user-pool attribute name -> external IdP attribute/claim<br>name (the Cognito `AttributeMapping`). When empty, the module applies the<br>upstream defaults appropriate to the selected `provider_type` (SAML claim<br>URIs vs OIDC claim names) for `email`, `given_name`, and `family_name`. | `map(string)` | `{}` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the base Lambda layer (idp\_common). Attached to the group-mapping Lambda via compact([...]). | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether external IdP federation is requested. When false the submodule<br>provisions no Cognito identity provider and leaves the user pool configured<br>for direct Cognito authentication (default-off, Requirement 5.6). | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used to encrypt the group-mapping Lambda log group. Optional. | `string` | `null` | no |
| <a name="input_group_attribute_name"></a> [group\_attribute\_name](#input\_group\_attribute\_name) | The SAML attribute or OIDC claim name that carries group membership from the<br>external IdP (mapped into the Cognito `custom:idp_groups` attribute). For<br>SAML this is typically `http://schemas.xmlsoap.org/claims/Group` or<br>`memberOf`; for OIDC typically `groups`. Empty skips automatic group<br>mapping. Mirrors the upstream `ExternalIdPGroupAttributeName`. | `string` | `""` | no |
| <a name="input_group_mapping"></a> [group\_mapping](#input\_group\_mapping) | Map of external IdP group name -> IDP RBAC role (`Admin`/`Author`/<br>`Reviewer`/`Viewer`). Consumed by the group-mapping Lambda (task 7.3) to<br>place federated users into the four RBAC groups at sign-in. Mirrors the<br>upstream `ExternalIdP{Admin,Author,Reviewer,Viewer}GroupName` parameters. | `map(string)` | `{}` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the idp\_common Lambda layer, when supplied separately from the base layer. | `string` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for the group-mapping Lambda. | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days for the group-mapping Lambda. | `number` | `7` | no |
| <a name="input_oidc_authorize_scopes"></a> [oidc\_authorize\_scopes](#input\_oidc\_authorize\_scopes) | (OIDC) Space-delimited OAuth scopes requested from the OIDC provider. Mirrors the upstream default of `openid email profile`. | `string` | `"openid email profile"` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | (OIDC) The client ID registered with the OIDC identity provider. Mirrors the upstream `ExternalIdPOIDCClientId`. | `string` | `""` | no |
| <a name="input_oidc_client_secret_ref"></a> [oidc\_client\_secret\_ref](#input\_oidc\_client\_secret\_ref) | (OIDC) Reference to the OIDC client secret — an AWS Secrets Manager secret<br>ARN (or SSM parameter name) — NOT the raw secret value. The secret is<br>resolved at apply time (task 7.2) and passed only to the Cognito provider<br>details; the plaintext is never stored as a module input value or output.<br>Mirrors the upstream `ExternalIdPOIDCClientSecretArn`. | `string` | `""` | no |
| <a name="input_oidc_issuer"></a> [oidc\_issuer](#input\_oidc\_issuer) | (OIDC) The issuer URL from the OIDC identity provider, e.g.<br>`https://login.example.com` or `https://example.okta.com/oauth2/default`.<br>Mirrors the upstream `ExternalIdPOIDCIssuer`. | `string` | `""` | no |
| <a name="input_provider_name"></a> [provider\_name](#input\_provider\_name) | Display name for the external identity provider (e.g. PingOne, Okta,<br>AzureAD), surfaced on the Cognito hosted-UI sign-in button. Must start with<br>a letter and contain only alphanumeric characters and hyphens (max 32).<br>Mirrors the upstream `ExternalIdPName`. | `string` | `"ExternalIdP"` | no |
| <a name="input_provider_type"></a> [provider\_type](#input\_provider\_type) | Type of external identity provider to federate with the Cognito user pool.<br>`SAML` for providers like PingOne, Okta SAML, or ADFS; `OIDC` for providers<br>like Okta OIDC, Auth0, or Azure AD. Mirrors the upstream `ExternalIdPType`. | `string` | `"SAML"` | no |
| <a name="input_rbac_group_names"></a> [rbac\_group\_names](#input\_rbac\_group\_names) | Map of the four IDP RBAC role names (`Admin`/`Author`/`Reviewer`/`Viewer`)<br>to the concrete Cognito group names provisioned by the RBAC submodule. The<br>group-mapping Lambda (task 7.3) targets these so federated users land in the<br>same groups RBAC creates (Requirement 6.3). | `map(string)` | <pre>{<br>  "Admin": "Admin",<br>  "Author": "Author",<br>  "Reviewer": "Reviewer",<br>  "Viewer": "Viewer"<br>}</pre> | no |
| <a name="input_saml_metadata_file"></a> [saml\_metadata\_file](#input\_saml\_metadata\_file) | (SAML) The SAML metadata document contents, supplied inline as an<br>alternative to `saml_metadata_url` (Cognito `MetadataFile`). Empty when a<br>metadata URL is used instead. | `string` | `""` | no |
| <a name="input_saml_metadata_url"></a> [saml\_metadata\_url](#input\_saml\_metadata\_url) | (SAML) The SAML metadata document URL from the identity provider, e.g.<br>`https://idp.example.com/saml/metadata`. Mutually exclusive with<br>`saml_metadata_file`. Mirrors the upstream `ExternalIdPMetadataURL`. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all federation resources. | `map(string)` | `{}` | no |
| <a name="input_user_pool_client_id"></a> [user\_pool\_client\_id](#input\_user\_pool\_client\_id) | ID of the Cognito user-pool client whose `supported_identity_providers` is<br>additively updated to include the external provider (task 7.4), keeping the<br>`COGNITO` provider so direct sign-in continues to work (Requirement 5.5). | `string` | `null` | no |
| <a name="input_user_pool_id"></a> [user\_pool\_id](#input\_user\_pool\_id) | ID of the Cognito user pool the external identity provider is attached to. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contract"></a> [contract](#output\_contract) | Feature-plugin contract consumed by `processing-environment-api` via its<br>`enabled_feature_contracts` input (mirrors the CDK `api.enable(feature)`<br>mechanism). Always emitted (Requirement 6.2). Federation contributes no<br>AppSync resolvers, IAM statements, environment, or schema additions — its<br>integration is Cognito-side (identity provider + group-mapping trigger) —<br>so the core five fields are empty/null with `enabled` reflecting the toggle.<br>Federation-specific handles (group-mapping trigger ARN, identity-provider<br>contribution) are surfaced via dedicated outputs. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether external IdP federation is effectively enabled. |
| <a name="output_group_mapping_function_arn"></a> [group\_mapping\_function\_arn](#output\_group\_mapping\_function\_arn) | ARN of the group-mapping pre-token-generation trigger Lambda, for the pool owner to wire as the user pool's PreTokenGeneration trigger. Null when group mapping is not provisioned. |
| <a name="output_group_mapping_function_name"></a> [group\_mapping\_function\_name](#output\_group\_mapping\_function\_name) | Name of the group-mapping trigger Lambda. Null when group mapping is not provisioned. |
| <a name="output_provider_name"></a> [provider\_name](#output\_provider\_name) | Name of the external Cognito identity provider, when federation is enabled. |
| <a name="output_supported_identity_providers_contribution"></a> [supported\_identity\_providers\_contribution](#output\_supported\_identity\_providers\_contribution) | Identity-provider names to append to the externally-owned user-pool client's<br>`supported_identity_providers` (e.g. `["PingOne"]`), keeping the existing<br>`COGNITO` provider intact (Requirement 5.5). Empty when federation is<br>disabled. The root merges this with `COGNITO` rather than this module owning<br>the full client resource. |
