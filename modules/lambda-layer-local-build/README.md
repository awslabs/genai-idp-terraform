## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.1 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_object.layer_zip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [local_file.requirements](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.build_layer](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.layer_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Container runtime selector. Informational here; the docker daemon is invoked by terraform-aws-modules/lambda via local-exec respecting the host's docker CLI / DOCKER\_HOST. Kept on the signature for future use. | `string` | `"auto"` | no |
| <a name="input_docker_host"></a> [docker\_host](#input\_docker\_host) | DOCKER\_HOST value to export when invoking terraform-aws-modules/lambda's build script. Empty string keeps the platform default (the docker CLI's own default socket). Non-empty values are passed through verbatim (e.g. unix:///path/to/podman.sock). | `string` | `""` | no |
| <a name="input_force_rebuild"></a> [force\_rebuild](#input\_force\_rebuild) | Force rebuild of layers regardless of input changes. | `bool` | `false` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture. Drives both the SAM build image tag (latest-x86\_64 vs latest-arm64) and compatible\_architectures on the produced aws\_lambda\_layer\_version. | `string` | `"x86_64"` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket the produced layer zips are uploaded to. Same bucket the CodeBuild path uses, so consumers see no S3-bucket difference between modes. | `string` | n/a | yes |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | Kept for signature parity with lambda-layer-codebuild. Not used here (no Lambda functions are created). | `string` | `"Active"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource naming and lambda layers (mirrors lambda-layer-codebuild). | `string` | n/a | yes |
| <a name="input_requirements_files"></a> [requirements\_files](#input\_requirements\_files) | Map of logical layer name to requirements.txt contents. Empty values are skipped. | `map(string)` | n/a | yes |
| <a name="input_requirements_hash"></a> [requirements\_hash](#input\_requirements\_hash) | Optional pre-computed hash for change detection. Empty string lets the module hash the inputs itself. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the layer-version resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_all_requirements_hash"></a> [all\_requirements\_hash](#output\_all\_requirements\_hash) | Aggregate hash of all input requirements files. |
| <a name="output_build_mode"></a> [build\_mode](#output\_build\_mode) | Always "local" for this module. |
| <a name="output_layer_etags"></a> [layer\_etags](#output\_layer\_etags) | Map of layer name to S3 object etag (= input md5). Used as source\_code\_hash on the wrapper's aws\_lambda\_layer\_version. |
| <a name="output_layer_keys"></a> [layer\_keys](#output\_layer\_keys) | Map of layer name to S3 object key produced by the local build. |
| <a name="output_layer_suffix"></a> [layer\_suffix](#output\_layer\_suffix) | Random suffix used in S3 keys. |
| <a name="output_s3_bucket"></a> [s3\_bucket](#output\_s3\_bucket) | S3 bucket name where layer zips are uploaded. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | S3 bucket ARN (echoed from input for parity). |
