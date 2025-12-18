<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.1 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.6.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.codebuild_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.codebuild_trigger_lambda_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_codebuild_project.lambda_layers_build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_iam_role.codebuild_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.codebuild_trigger_lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codebuild_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.codebuild_trigger_lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.codebuild_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.trigger_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_layer_version.layers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [aws_s3_object.requirements_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [local_file.requirements_files](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.cleanup_after_build](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cleanup_build_artifacts](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cleanup_on_destroy](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.create_lambda_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.test_iam_permissions](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.layer_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [terraform_data.copy_idp_common_source](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.codebuild_trigger_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.requirements_source](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_force_rebuild"></a> [force\_rebuild](#input\_force\_rebuild) | Force rebuild of layers regardless of content changes | `bool` | `false` | no |
| <a name="input_function_layer_config"></a> [function\_layer\_config](#input\_function\_layer\_config) | Optional configuration for creating function-specific layers.<br/>Map of function names to their required idp\_common extras.<br/>If provided, creates separate optimized layers for each function type.<br/><br/>Example:<br/>{<br/>  "ocr-function" = ["ocr", "docs\_service"]<br/>  "classification-function" = ["classification", "docs\_service"] <br/>  "assessment-function" = ["assessment", "docs\_service"]<br/>  "evaluation-function" = ["evaluation"]<br/>  "basic-function" = ["core"]<br/>}<br/><br/>If not provided, creates a single layer with the extras specified in idp\_common\_extras. | `map(list(string))` | `{}` | no |
| <a name="input_idp_common_extras"></a> [idp\_common\_extras](#input\_idp\_common\_extras) | List of extras to install for idp\_common package. Available extras:<br/>- core: Base functionality only (minimal dependencies)<br/>- image: Image handling dependencies (Pillow)<br/>- ocr: OCR module dependencies (Pillow, PyMuPDF, textractor, numpy, pandas, etc.)<br/>- classification: Classification module dependencies<br/>- extraction: Extraction module dependencies<br/>- assessment: Assessment module dependencies<br/>- evaluation: Evaluation module dependencies (munkres, numpy)<br/>- criteria\_validation: Criteria validation dependencies (s3fs)<br/>- reporting: Reporting module dependencies (pyarrow)<br/>- appsync: AppSync module dependencies (requests)<br/>- docs\_service: Document service factory dependencies (requests for appsync support)<br/>- test: Testing dependencies<br/>- all: All available dependencies<br/><br/>Example function-specific combinations:<br/>- OCR functions: ["ocr", "docs\_service"]<br/>- Classification functions: ["classification", "docs\_service"]<br/>- Assessment functions: ["assessment", "docs\_service"]<br/>- Evaluation functions: ["evaluation"]<br/>- Reporting functions: ["reporting"]<br/>- Basic processing: ["core"] or [] | `list(string)` | <pre>[<br/>  "core"<br/>]</pre> | no |
| <a name="input_idp_common_source_path"></a> [idp\_common\_source\_path](#input\_idp\_common\_source\_path) | Path to the idp\_common source code directory | `string` | `""` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for storing Lambda layers. This is required and should be provided by the assets-bucket module. | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_layer_prefix"></a> [layer\_prefix](#input\_layer\_prefix) | Prefix for layer names | `string` | n/a | yes |
| <a name="input_requirements_files"></a> [requirements\_files](#input\_requirements\_files) | Map of requirements files content for different layer types | `map(string)` | n/a | yes |
| <a name="input_requirements_hash"></a> [requirements\_hash](#input\_requirements\_hash) | Hash of requirements to trigger rebuilds. If empty, will be calculated from requirements\_files. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_build_result"></a> [build\_result](#output\_build\_result) | Result of the most recent build operation |
| <a name="output_build_trigger_lambda"></a> [build\_trigger\_lambda](#output\_build\_trigger\_lambda) | Lambda function used to trigger CodeBuild (replaces null\_resource) |
| <a name="output_codebuild_project"></a> [codebuild\_project](#output\_codebuild\_project) | CodeBuild project information |
| <a name="output_function_layer_arns"></a> [function\_layer\_arns](#output\_function\_layer\_arns) | Function-specific layer ARNs for optimized layer assignment.<br/>Use this to assign the most appropriate layer to each Lambda function.<br/><br/>Example usage:<br/>layers = [module.idp\_layers.function\_layer\_arns["ocr-function"]] |
| <a name="output_layer_arn"></a> [layer\_arn](#output\_layer\_arn) | ARN of the main idp-common layer (for backward compatibility) |
| <a name="output_layer_arns"></a> [layer\_arns](#output\_layer\_arns) | ARNs of the created Lambda layers |
| <a name="output_layer_configuration_summary"></a> [layer\_configuration\_summary](#output\_layer\_configuration\_summary) | Summary of layer configuration for documentation and debugging |
| <a name="output_layer_version"></a> [layer\_version](#output\_layer\_version) | Version of the main idp-common layer (for backward compatibility) |
| <a name="output_layer_versions"></a> [layer\_versions](#output\_layer\_versions) | Version numbers of the created Lambda layers |
| <a name="output_s3_bucket"></a> [s3\_bucket](#output\_s3\_bucket) | S3 bucket used for layer storage |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
