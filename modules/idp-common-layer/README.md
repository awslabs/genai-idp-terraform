## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_idp_common_layer"></a> [idp\_common\_layer](#module\_idp\_common\_layer) | ../lambda-layer-codebuild-idp | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Container runtime to use when lambda\_local = true. "auto" probes docker -> podman -> finch. | `string` | `"auto"` | no |
| <a name="input_force_rebuild"></a> [force\_rebuild](#input\_force\_rebuild) | Force rebuild of lambda layers regardless of requirements changes | `bool` | `false` | no |
| <a name="input_idp_common_extras"></a> [idp\_common\_extras](#input\_idp\_common\_extras) | List of extra dependencies to include (e.g., ['ocr', 'classification', 'extraction']) | `list(string)` | <pre>[<br/>  "all"<br/>]</pre> | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture. Propagates to compatible\_architectures on the layer and to the local/CodeBuild build-host platform. | `string` | `"x86_64"` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for storing Lambda layers. If not provided, a new bucket will be created. | `string` | `""` | no |
| <a name="input_lambda_local"></a> [lambda\_local](#input\_lambda\_local) | When true, build Lambda layers locally using a container runtime instead of via AWS CodeBuild. See root var.build.lambda\_local. | `bool` | `false` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_layer_prefix"></a> [layer\_prefix](#input\_layer\_prefix) | Prefix for the lambda layers (should be unique per deployment) | `string` | `"idp-common"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_codebuild_project"></a> [codebuild\_project](#output\_codebuild\_project) | CodeBuild project information |
| <a name="output_layer_arn"></a> [layer\_arn](#output\_layer\_arn) | ARN of the IDP common Lambda layer |
| <a name="output_layer_arns"></a> [layer\_arns](#output\_layer\_arns) | Map of all layer ARNs (for compatibility) |
| <a name="output_s3_bucket"></a> [s3\_bucket](#output\_s3\_bucket) | S3 bucket information used for layer storage |
