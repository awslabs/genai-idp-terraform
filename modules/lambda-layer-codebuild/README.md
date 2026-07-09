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
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_local_build"></a> [local\_build](#module\_local\_build) | ../lambda-layer-local-build | n/a |

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
| [local_file.requirements_dir_placeholder](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.requirements_files](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.cleanup_build_artifacts](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cleanup_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.create_lambda_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.test_iam_permissions](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.layer_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_for_s3_consistency](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.codebuild_trigger_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.requirements_source](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Container runtime for local builds (auto\|docker\|podman\|finch). Ignored when lambda\_local = false. | `string` | `"auto"` | no |
| <a name="input_force_rebuild"></a> [force\_rebuild](#input\_force\_rebuild) | Force rebuild of lambda layers regardless of requirements changes | `bool` | `false` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). Sets compatible\_architectures on the produced aws\_lambda\_layer\_version regardless of build path. | `string` | `"x86_64"` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for storing Lambda layers. This is required and should be provided by the assets-bucket module. | `string` | n/a | yes |
| <a name="input_lambda_local"></a> [lambda\_local](#input\_lambda\_local) | When true, build the Lambda layer locally on the deploy host instead of via AWS CodeBuild. See modules/lambda-layer-local-build. | `bool` | `false` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource naming and lambda layers | `string` | n/a | yes |
| <a name="input_requirements_files"></a> [requirements\_files](#input\_requirements\_files) | Map of function names to requirements file contents | `map(string)` | n/a | yes |
| <a name="input_requirements_hash"></a> [requirements\_hash](#input\_requirements\_hash) | Hash of the requirements files to trigger rebuilds only when they change | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_created_by_module"></a> [bucket\_created\_by\_module](#output\_bucket\_created\_by\_module) | Whether the S3 bucket was created by this module (always false -- bucket is always external). |
| <a name="output_build_mode"></a> [build\_mode](#output\_build\_mode) | Active build path: "codebuild" or "local". |
| <a name="output_build_result"></a> [build\_result](#output\_build\_result) | Parsed CodeBuild invocation result; null when lambda\_local = true. |
| <a name="output_build_success"></a> [build\_success](#output\_build\_success) | Whether the CodeBuild invocation succeeded; null when lambda\_local = true. |
| <a name="output_codebuild_project_name"></a> [codebuild\_project\_name](#output\_codebuild\_project\_name) | CodeBuild project name; null when lambda\_local = true. |
| <a name="output_codebuild_trigger_lambda_function_name"></a> [codebuild\_trigger\_lambda\_function\_name](#output\_codebuild\_trigger\_lambda\_function\_name) | CodeBuild trigger Lambda function name; null when lambda\_local = true. |
| <a name="output_layer_arns"></a> [layer\_arns](#output\_layer\_arns) | Map of layer name to Lambda layer ARN. |
| <a name="output_layer_suffix"></a> [layer\_suffix](#output\_layer\_suffix) | Random suffix used in resource names. |
| <a name="output_layer_versions"></a> [layer\_versions](#output\_layer\_versions) | Map of layer name to Lambda layer version number. |
| <a name="output_s3_bucket"></a> [s3\_bucket](#output\_s3\_bucket) | S3 bucket used for layer storage. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket used for layer storage. |
