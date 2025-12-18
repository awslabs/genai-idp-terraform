# Processing Environment API Example

This example demonstrates how to use the Processing Environment API module from the GenAI IDP Accelerator. It creates all the necessary resources including DynamoDB tables, S3 buckets, and the GraphQL API.

## Architecture

This example creates:

1. Three DynamoDB tables:
   - Tracking Table: For tracking document processing status
   - Configuration Table: For storing configuration settings
   - Concurrency Table: For managing concurrent document processing

2. Four S3 buckets:
   - Input Bucket: For storing source documents
   - Output Bucket: For storing processed document outputs
   - Configuration Bucket: For storing configuration files
   - Evaluation Baseline Bucket: For storing evaluation baseline documents

3. An AppSync GraphQL API with resolvers for:
   - Document tracking and management
   - Configuration management
   - File content retrieval
   - Document operations (delete, reprocess, upload)
   - Copying documents to baseline

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
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_concurrency_table"></a> [concurrency\_table](#module\_concurrency\_table) | ../../modules/concurrency-table | n/a |
| <a name="module_configuration_table"></a> [configuration\_table](#module\_configuration\_table) | ../../modules/configuration-table | n/a |
| <a name="module_processing_environment_api"></a> [processing\_environment\_api](#module\_processing\_environment\_api) | ../../modules/processing-environment-api | n/a |
| <a name="module_tracking_table"></a> [tracking\_table](#module\_tracking\_table) | ../../modules/tracking-table | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.evaluation_baseline_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | Controls how you are charged for read and write throughput and how you manage capacity | `string` | `"PROVISIONED"` | no |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Whether point-in-time recovery is enabled | `bool` | `false` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp"` | no |
| <a name="input_read_capacity"></a> [read\_capacity](#input\_read\_capacity) | The read capacity for the tables | `number` | `5` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | <pre>{<br/>  "Environment": "development",<br/>  "Project": "GenAI-IDP"<br/>}</pre> | no |
| <a name="input_write_capacity"></a> [write\_capacity](#input\_write\_capacity) | The write capacity for the tables | `number` | `5` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | The ID of the AppSync GraphQL API |
| <a name="output_api_key"></a> [api\_key](#output\_api\_key) | The API key for the GraphQL API (if API key authentication is enabled) |
| <a name="output_concurrency_table_name"></a> [concurrency\_table\_name](#output\_concurrency\_table\_name) | The name of the concurrency table |
| <a name="output_configuration_table_name"></a> [configuration\_table\_name](#output\_configuration\_table\_name) | The name of the configuration table |
| <a name="output_evaluation_baseline_bucket_name"></a> [evaluation\_baseline\_bucket\_name](#output\_evaluation\_baseline\_bucket\_name) | The name of the evaluation baseline bucket |
| <a name="output_graphql_url"></a> [graphql\_url](#output\_graphql\_url) | The URL endpoint for the GraphQL API |
| <a name="output_input_bucket_name"></a> [input\_bucket\_name](#output\_input\_bucket\_name) | The name of the input bucket |
| <a name="output_output_bucket_name"></a> [output\_bucket\_name](#output\_output\_bucket\_name) | The name of the output bucket |
| <a name="output_tracking_table_name"></a> [tracking\_table\_name](#output\_tracking\_table\_name) | The name of the tracking table |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
