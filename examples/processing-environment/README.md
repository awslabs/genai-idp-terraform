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


## Notes

- The IDP common layer build may take several minutes due to Python package compilation
- The layer is automatically rebuilt when source code or requirements change
- Use `force_layer_rebuild = true` during development to force rebuilds
- The same layer can be reused across multiple processing environments or other Lambda functions

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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_idp_common_layer"></a> [idp\_common\_layer](#module\_idp\_common\_layer) | ../../modules/idp-common-layer | n/a |
| <a name="module_processing_environment"></a> [processing\_environment](#module\_processing\_environment) | ../../modules/processing-environment | n/a |
| <a name="module_reporting_environment"></a> [reporting\_environment](#module\_reporting\_environment) | ../../modules/reporting | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_glue_catalog_database.reporting_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_kms_alias.encryption_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.evaluation_baseline_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.reporting_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.reporting_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.evaluation_baseline_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.reporting_bucket_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.reporting_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.kms_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | The retention period for document tracking data in days | `number` | `365` | no |
| <a name="input_enable_evaluation"></a> [enable\_evaluation](#input\_enable\_evaluation) | Enable evaluation functionality with baseline comparison | `bool` | `false` | no |
| <a name="input_enable_reporting"></a> [enable\_reporting](#input\_enable\_reporting) | Enable analytics and reporting environment | `bool` | `false` | no |
| <a name="input_evaluation_model_id"></a> [evaluation\_model\_id](#input\_evaluation\_model\_id) | The Bedrock model ID to use for evaluation (when evaluation is enabled) | `string` | `"anthropic.claude-3-haiku-20240307-v1:0"` | no |
| <a name="input_force_layer_rebuild"></a> [force\_layer\_rebuild](#input\_force\_layer\_rebuild) | Force rebuild of the IDP common layer regardless of changes | `bool` | `false` | no |
| <a name="input_idp_common_layer_extras"></a> [idp\_common\_layer\_extras](#input\_idp\_common\_layer\_extras) | List of extra dependencies to include in the IDP common layer | `list(string)` | <pre>[<br/>  "appsync",<br/>  "evaluation"<br/>]</pre> | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for the document processing components | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by the document processing components in days | `number` | `7` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | <pre>{<br/>  "Environment": "development",<br/>  "Project": "GenAI-IDP"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_concurrency_table_name"></a> [concurrency\_table\_name](#output\_concurrency\_table\_name) | The name of the concurrency table |
| <a name="output_configuration_table_name"></a> [configuration\_table\_name](#output\_configuration\_table\_name) | The name of the configuration table |
| <a name="output_document_queue_url"></a> [document\_queue\_url](#output\_document\_queue\_url) | The URL of the document queue |
| <a name="output_encryption_key_alias"></a> [encryption\_key\_alias](#output\_encryption\_key\_alias) | The alias of the KMS key used for encryption |
| <a name="output_encryption_key_id"></a> [encryption\_key\_id](#output\_encryption\_key\_id) | The ID of the KMS key used for encryption |
| <a name="output_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#output\_idp\_common\_layer\_arn) | The ARN of the IDP common Lambda layer |
| <a name="output_input_bucket_name"></a> [input\_bucket\_name](#output\_input\_bucket\_name) | The name of the input bucket |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Information about the Lambda functions created |
| <a name="output_output_bucket_name"></a> [output\_bucket\_name](#output\_output\_bucket\_name) | The name of the output bucket |
| <a name="output_tracking_table_name"></a> [tracking\_table\_name](#output\_tracking\_table\_name) | The name of the tracking table |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
