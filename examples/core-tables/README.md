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

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_concurrency_table"></a> [concurrency\_table](#module\_concurrency\_table) | ../../modules/concurrency-table | n/a |
| <a name="module_configuration_table"></a> [configuration\_table](#module\_configuration\_table) | ../../modules/configuration-table | n/a |
| <a name="module_tracking_table"></a> [tracking\_table](#module\_tracking\_table) | ../../modules/tracking-table | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | Controls how you are charged for read and write throughput and how you manage capacity | `string` | `"PROVISIONED"` | no |
| <a name="input_deletion_protection_enabled"></a> [deletion\_protection\_enabled](#input\_deletion\_protection\_enabled) | Enables deletion protection for the tables | `bool` | `false` | no |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Whether point-in-time recovery is enabled | `bool` | `false` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp"` | no |
| <a name="input_read_capacity"></a> [read\_capacity](#input\_read\_capacity) | The read capacity for the tables | `number` | `5` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | <pre>{<br/>  "Environment": "development",<br/>  "Project": "GenAI-IDP"<br/>}</pre> | no |
| <a name="input_write_capacity"></a> [write\_capacity](#input\_write\_capacity) | The write capacity for the tables | `number` | `5` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_concurrency_table_arn"></a> [concurrency\_table\_arn](#output\_concurrency\_table\_arn) | The ARN of the concurrency table |
| <a name="output_concurrency_table_name"></a> [concurrency\_table\_name](#output\_concurrency\_table\_name) | The name of the concurrency table |
| <a name="output_configuration_table_arn"></a> [configuration\_table\_arn](#output\_configuration\_table\_arn) | The ARN of the configuration table |
| <a name="output_configuration_table_name"></a> [configuration\_table\_name](#output\_configuration\_table\_name) | The name of the configuration table |
| <a name="output_tracking_table_arn"></a> [tracking\_table\_arn](#output\_tracking\_table\_arn) | The ARN of the tracking table |
| <a name="output_tracking_table_name"></a> [tracking\_table\_name](#output\_tracking\_table\_name) | The name of the tracking table |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
