# User Identity Standalone Example

This example demonstrates how to use the User Identity module independently to create Cognito resources for user authentication and authorization.

## What This Example Creates

- **Cognito User Pool**: For user registration and authentication
- **User Pool Client**: For web application OAuth flows
- **Identity Pool**: For providing temporary AWS credentials
- **IAM Roles**: For authenticated (and optionally unauthenticated) users
- **Admin User**: Optional admin user with elevated privileges
- **Admin Group**: Admin group with highest precedence

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. Valid email address for admin user

## Required AWS Permissions

The deploying user/role needs permissions for:

- Cognito User Pool and Identity Pool management
- IAM role and policy management
- CloudWatch Logs (for Terraform state)

## Usage

1. **Copy the example configuration:**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars:**

   ```hcl
   # Required
   admin_email = "your-admin@example.com"
   
   # Optional
   region = "us-east-1"
   prefix = "my-idp-user-identity"
   allowed_signup_email_domain = "example.com"
   ```

3. **Initialize and deploy:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access the resources:**
   - Check the Cognito console: `terraform output -raw usage_instructions`
   - Note the User Pool ID, Client ID, and Identity Pool ID for integration

## Configuration Options

### Basic Configuration

- `region`: AWS region for deployment
- `prefix`: Prefix for resource names

### User Management

- `admin_email`: Email for admin user (required)
- `allowed_signup_email_domain`: Domains allowed for self-service signup
- `allow_unauthenticated_identities`: Allow unauthenticated access (not recommended)

### Security

- `deletion_protection`: Prevent accidental User Pool deletion (recommended)

## Outputs

The example provides several output formats:

### IUserIdentity Interface (for module integration)

```bash
terraform output user_identity
```

### Individual Components

```bash
terraform output user_pool
terraform output user_pool_client
terraform output identity_pool
```

### Legacy Format (backward compatibility)

```bash
terraform output user_pool_id
terraform output user_pool_client_id
terraform output identity_pool_id
```

### Usage Instructions

```bash
terraform output usage_instructions
```

## Integration with Other Modules

Use the outputs to integrate with other modules:

```hcl
module "web_ui" {
  source = "../../modules/web-ui"
  
  user_identity = module.user_identity.user_identity
  # ... other configuration
}
```

## Admin User Management

If you provide an `admin_email`, the module will:

1. Create an admin user with that email
2. Create an "Admin" group with highest precedence
3. Add the admin user to the admin group
4. Send a temporary password via email

The admin user will need to:

1. Check their email for the temporary password
2. Sign in and set a permanent password
3. Complete any required profile information

## Security Considerations

- **Strong Password Policy**: Enforced by default (8+ chars, mixed case, numbers, symbols)
- **Email Verification**: Required for account activation
- **Deletion Protection**: Enabled by default to prevent accidental deletion
- **Token Security**: Short-lived access tokens with secure refresh mechanism
- **IAM Roles**: Follow principle of least privilege

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Note**: If deletion protection is enabled, you may need to disable it first or use the AWS console to delete the User Pool.

## Troubleshooting

### Common Issues

1. **Admin user creation fails**
   - Verify the email address is valid
   - Check AWS SES limits in your region
   - Ensure the email domain accepts AWS emails

2. **Permission errors**
   - Verify your AWS credentials have Cognito permissions
   - Check IAM policies for required actions

3. **Deletion protection prevents cleanup**
   - Set `deletion_protection = false` and re-apply
   - Or manually delete the User Pool from AWS console

### Getting Help

Check the module documentation at `../../modules/user-identity/README.md` for detailed configuration options and troubleshooting guidance.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_user_identity"></a> [user\_identity](#module\_user\_identity) | ../../modules/user-identity | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cognito_user.admin_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user) | resource |
| [aws_cognito_user_group.admin_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_in_group.admin_user_in_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_in_group) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Email address for the admin user | `string` | n/a | yes |
| <a name="input_allow_unauthenticated_identities"></a> [allow\_unauthenticated\_identities](#input\_allow\_unauthenticated\_identities) | Allow unauthenticated identities in the Identity Pool | `bool` | `false` | no |
| <a name="input_allowed_signup_email_domain"></a> [allowed\_signup\_email\_domain](#input\_allowed\_signup\_email\_domain) | Optional comma-separated list of allowed email domains for self-service signup | `string` | `""` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection for the User Pool | `bool` | `true` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for resource names | `string` | `"idp-user-identity"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deployment | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | <pre>{<br/>  "Environment": "Development",<br/>  "ManagedBy": "Terraform",<br/>  "Project": "GenAI-IDP-Accelerator"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_user"></a> [admin\_user](#output\_admin\_user) | Admin user details (if created) |
| <a name="output_authenticated_role_arn"></a> [authenticated\_role\_arn](#output\_authenticated\_role\_arn) | ARN of the authenticated IAM role |
| <a name="output_identity_pool"></a> [identity\_pool](#output\_identity\_pool) | Cognito Identity Pool details |
| <a name="output_identity_pool_id"></a> [identity\_pool\_id](#output\_identity\_pool\_id) | ID of the Cognito Identity Pool |
| <a name="output_usage_instructions"></a> [usage\_instructions](#output\_usage\_instructions) | Instructions for using the User Identity resources |
| <a name="output_user_identity"></a> [user\_identity](#output\_user\_identity) | Complete user identity details following IUserIdentity interface |
| <a name="output_user_pool"></a> [user\_pool](#output\_user\_pool) | Cognito User Pool details |
| <a name="output_user_pool_client"></a> [user\_pool\_client](#output\_user\_pool\_client) | Cognito User Pool Client details |
| <a name="output_user_pool_client_id"></a> [user\_pool\_client\_id](#output\_user\_pool\_client\_id) | ID of the Cognito User Pool Client |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | ID of the Cognito User Pool |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
