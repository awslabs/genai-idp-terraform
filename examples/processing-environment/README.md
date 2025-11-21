# Processing Environment Example

This example demonstrates how to use the Processing Environment module from the GenAI IDP Accelerator. It creates all the necessary resources including S3 buckets, KMS key, IDP common layer, and the processing environment.

## Architecture

This example creates:

1. **KMS Key**: For encrypting all resources in the document processing workflow
2. **S3 Buckets**:
   - Input Bucket: For storing source documents
   - Output Bucket: For storing processed document outputs
3. **IDP Common Layer**: Lambda layer containing the `idp_common` library with configurable extras
4. **Processing Environment**: The core infrastructure for document processing, including:
   - Configuration Bucket: For storing configuration files
   - DynamoDB Tables: For tracking, configuration, and concurrency management
   - SQS Queues: For document processing
   - Lambda Functions: For workflow orchestration (with IDP common layer attached)
   - GraphQL API: For client interactions

## IDP Common Layer Integration

The example demonstrates the new architecture where:

- The IDP common layer is created as a separate module
- The processing environment depends on the external layer ARN
- Lambda functions that use `idp_common` automatically get the layer attached:
  - ✅ **queue_sender**: Uses `idp_common[appsync]` for AppSync integration
  - ✅ **workflow_tracker**: Uses `idp_common[appsync]` for AppSync integration
  - ❌ **lookup_function**: No idp_common dependency
  - ❌ **update_configuration**: Uses PyYAML/cfnresponse only

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
log_level = "DEBUG"
log_retention_days = 14
data_tracking_retention_days = 180

# IDP Common Layer configuration
idp_common_layer_extras = ["appsync", "evaluation", "ocr"]
force_layer_rebuild = false
layer_build_wait_time = 900

tags = {
  Environment = "production"
  Project     = "GenAI-IDP"
  Owner       = "Data Processing Team"
}
```

### Available IDP Common Layer Extras

You can configure which dependencies to include in the layer:

- `"core"` - Only core dependencies (boto3)
- `"image"` - Image handling (Pillow)
- `"ocr"` - OCR capabilities (Pillow, PyMuPDF, amazon-textract-textractor)
- `"classification"` - Document classification (Pillow)
- `"extraction"` - Data extraction (Pillow)
- `"evaluation"` - Evaluation utilities (munkres, numpy)
- `"appsync"` - AppSync integration (requests)
- `"all"` - All available dependencies

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| prefix | Prefix to add to resource names | `string` | `"idp"` | no |
| log_level | The log level for the document processing components | `string` | `"INFO"` | no |
| log_retention_days | The retention period for CloudWatch logs in days | `number` | `7` | no |
| data_tracking_retention_days | The retention period for document tracking data in days | `number` | `365` | no |
| idp_common_layer_extras | List of extra dependencies to include in the IDP common layer | `list(string)` | `["appsync", "evaluation"]` | no |
| force_layer_rebuild | Force rebuild of the IDP common layer regardless of changes | `bool` | `false` | no |
| layer_build_wait_time | Time to wait for the IDP common layer build to complete (in seconds) | `number` | `600` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{...}` | no |

## Outputs

| Name | Description |
|------|-------------|
| api_url | The URL endpoint for the GraphQL API |
| input_bucket_name | The name of the input bucket |
| output_bucket_name | The name of the output bucket |
| configuration_bucket_name | The name of the configuration bucket |
| tracking_table_name | The name of the tracking table |
| configuration_table_name | The name of the configuration table |
| concurrency_table_name | The name of the concurrency table |
| document_queue_url | The URL of the document queue |
| encryption_key_id | The ID of the KMS key used for encryption |
| encryption_key_alias | The alias of the KMS key used for encryption |
| idp_common_layer_arn | The ARN of the IDP common Lambda layer |
| lambda_functions | Information about the Lambda functions created |

## Notes

- The IDP common layer build may take several minutes due to Python package compilation
- The layer is automatically rebuilt when source code or requirements change
- Use `force_layer_rebuild = true` during development to force rebuilds
- The same layer can be reused across multiple processing environments or other Lambda functions
