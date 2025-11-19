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
