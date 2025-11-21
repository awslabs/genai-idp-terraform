# GenAI IDP Core Tables Example

This example demonstrates how to use the core table modules from the GenAI IDP Accelerator. It creates the three fundamental DynamoDB tables needed for the document processing solution:

- **Concurrency Table**: For managing concurrent document processing tasks
- **Configuration Table**: For storing system configuration settings
- **Tracking Table**: For tracking document processing status and results

## Usage

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Clean up when done
terraform destroy
```

## Customization

You can customize the deployment by creating a `terraform.tfvars` file:

```hcl
region = "us-west-2"
prefix = "my-idp"
billing_mode = "PAY_PER_REQUEST"
point_in_time_recovery_enabled = true
deletion_protection_enabled = true

tags = {
  Environment = "production"
  Project     = "GenAI-IDP"
  Owner       = "Data Processing Team"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| prefix | Prefix to add to resource names | `string` | `"idp"` | no |
| billing_mode | Controls how you are charged for read and write throughput | `string` | `"PROVISIONED"` | no |
| read_capacity | The read capacity for the tables | `number` | `5` | no |
| write_capacity | The write capacity for the tables | `number` | `5` | no |
| point_in_time_recovery_enabled | Whether point-in-time recovery is enabled | `bool` | `false` | no |
| deletion_protection_enabled | Enables deletion protection for the tables | `bool` | `false` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{...}` | no |

## Outputs

| Name | Description |
|------|-------------|
| concurrency_table_name | The name of the concurrency table |
| concurrency_table_arn | The ARN of the concurrency table |
| configuration_table_name | The name of the configuration table |
| configuration_table_arn | The ARN of the configuration table |
| tracking_table_name | The name of the tracking table |
| tracking_table_arn | The ARN of the tracking table |
