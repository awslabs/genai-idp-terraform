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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| prefix | Prefix to add to resource names | `string` | `"idp"` | no |
| billing_mode | Controls how you are charged for read and write throughput | `string` | `"PROVISIONED"` | no |
| read_capacity | The read capacity for the tables | `number` | `5` | no |
| write_capacity | The write capacity for the tables | `number` | `5` | no |
| point_in_time_recovery_enabled | Whether point-in-time recovery is enabled | `bool` | `false` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{...}` | no |

## Outputs

| Name | Description |
|------|-------------|
| api_id | The ID of the AppSync GraphQL API |
| graphql_url | The URL endpoint for the GraphQL API |
| api_key | The API key for the GraphQL API (if API key authentication is enabled) |
| tracking_table_name | The name of the tracking table |
| configuration_table_name | The name of the configuration table |
| concurrency_table_name | The name of the concurrency table |
| input_bucket_name | The name of the input bucket |
| output_bucket_name | The name of the output bucket |
| configuration_bucket_name | The name of the configuration bucket |
| evaluation_baseline_bucket_name | The name of the evaluation baseline bucket |
