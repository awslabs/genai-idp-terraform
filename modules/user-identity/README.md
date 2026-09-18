## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cognito_identity_pool.identity_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool) | resource |
| [aws_cognito_identity_pool_roles_attachment.identity_pool_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool_roles_attachment) | resource |
| [aws_cognito_user_pool.user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.user_pool_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.hosted_ui](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |
| [aws_iam_policy.authenticated_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.unauthenticated_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.authenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.unauthenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.authenticated_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.unauthenticated_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_wafv2_web_acl.cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_callback_urls"></a> [additional\_callback\_urls](#input\_additional\_callback\_urls) | Extra OAuth callback URLs to allow on the user pool client (in addition to the localhost dev URL). Used to register the Web UI custom domain URL. Mirrors upstream CustomDomainUrl callback wiring. | `list(string)` | `[]` | no |
| <a name="input_additional_identity_providers"></a> [additional\_identity\_providers](#input\_additional\_identity\_providers) | External identity provider names to append to the user pool client's supported\_identity\_providers. COGNITO is always retained. Wired from the idp-federation feature's supported\_identity\_providers\_contribution output. | `list(string)` | `[]` | no |
| <a name="input_additional_logout_urls"></a> [additional\_logout\_urls](#input\_additional\_logout\_urls) | Extra OAuth logout URLs to allow on the user pool client (in addition to the localhost dev URL). Used to register the Web UI custom domain URL. | `list(string)` | `[]` | no |
| <a name="input_allowed_signup_email_domain"></a> [allowed\_signup\_email\_domain](#input\_allowed\_signup\_email\_domain) | Optional comma-separated list of allowed email domains for self-service signup | `string` | `""` | no |
| <a name="input_create_hosted_ui_domain"></a> [create\_hosted\_ui\_domain](#input\_create\_hosted\_ui\_domain) | Create a Cognito hosted UI domain for the user pool. Required for external-IdP (SAML/OIDC) sign-in, which redirects through the hosted UI. | `bool` | `false` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection for the User Pool | `bool` | `true` | no |
| <a name="input_enable_cognito_waf"></a> [enable\_cognito\_waf](#input\_enable\_cognito\_waf) | Attach a REGIONAL WAFv2 Web ACL (AWS managed common rule set) to the Cognito user pool (Wiz IDP-007). | `bool` | `true` | no |
| <a name="input_enable_idp_groups_attribute"></a> [enable\_idp\_groups\_attribute](#input\_enable\_idp\_groups\_attribute) | Add the custom `idp_groups` attribute to the user pool schema, required for external IdP group mapping. One-way: Cognito can add a schema attribute in place but can never remove one, so confirm your plan shows no pool replacement before enabling. | `bool` | `false` | no |
| <a name="input_hosted_ui_domain_prefix"></a> [hosted\_ui\_domain\_prefix](#input\_hosted\_ui\_domain\_prefix) | Domain prefix for the Cognito hosted UI. Must be globally unique across all AWS accounts. Defaults to a sanitized name\_prefix. | `string` | `null` | no |
| <a name="input_identity_pool_options"></a> [identity\_pool\_options](#input\_identity\_pool\_options) | Configuration for the Identity Pool | <pre>object({<br>    identity_pool_name               = optional(string)<br>    allow_unauthenticated_identities = optional(bool, false)<br>    allow_classic_flow               = optional(bool, false)<br>  })</pre> | `{}` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource naming | `string` | n/a | yes |
| <a name="input_pre_token_generation_function_arn"></a> [pre\_token\_generation\_function\_arn](#input\_pre\_token\_generation\_function\_arn) | ARN of a Lambda to attach as the user pool's PreTokenGeneration (V2\_0) trigger. Used to map external IdP groups onto Cognito groups. When null, no trigger is attached. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_user_pool"></a> [user\_pool](#input\_user\_pool) | Optional pre-existing Cognito User Pool to use for authentication. When not provided, a new User Pool will be created with standard settings. | <pre>object({<br>    user_pool_id  = string<br>    user_pool_arn = string<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_authenticated_role_arn"></a> [authenticated\_role\_arn](#output\_authenticated\_role\_arn) | ARN of the authenticated IAM role |
| <a name="output_hosted_ui_domain"></a> [hosted\_ui\_domain](#output\_hosted\_ui\_domain) | Fully qualified Cognito hosted UI domain, or null when no domain was created |
| <a name="output_hosted_ui_domain_prefix"></a> [hosted\_ui\_domain\_prefix](#output\_hosted\_ui\_domain\_prefix) | Domain prefix of the Cognito hosted UI, or null when no domain was created |
| <a name="output_identity_pool"></a> [identity\_pool](#output\_identity\_pool) | The Cognito Identity Pool that provides temporary AWS credentials |
| <a name="output_identity_pool_id"></a> [identity\_pool\_id](#output\_identity\_pool\_id) | ID of the Cognito Identity Pool |
| <a name="output_unauthenticated_role_arn"></a> [unauthenticated\_role\_arn](#output\_unauthenticated\_role\_arn) | ARN of the unauthenticated IAM role (if enabled) |
| <a name="output_user_pool"></a> [user\_pool](#output\_user\_pool) | The Cognito UserPool that stores user identities and credentials |
| <a name="output_user_pool_arn"></a> [user\_pool\_arn](#output\_user\_pool\_arn) | ARN of the Cognito User Pool |
| <a name="output_user_pool_client"></a> [user\_pool\_client](#output\_user\_pool\_client) | The Cognito UserPool Client used by the web application for OAuth flows |
| <a name="output_user_pool_client_id"></a> [user\_pool\_client\_id](#output\_user\_pool\_client\_id) | ID of the Cognito User Pool Client |
| <a name="output_user_pool_endpoint"></a> [user\_pool\_endpoint](#output\_user\_pool\_endpoint) | Endpoint of the Cognito User Pool |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | ID of the Cognito User Pool |
