## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |
| <a name="provider_docker"></a> [docker](#provider\_docker) | 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [docker_image.lambda](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image) | resource |
| [docker_registry_image.lambda](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/registry_image) | resource |
| [aws_ecr_authorization_token.auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_build_args"></a> [build\_args](#input\_build\_args) | Additional --build-arg key=value pairs to pass to docker build. | `map(string)` | `{}` | no |
| <a name="input_dockerfile_path"></a> [dockerfile\_path](#input\_dockerfile\_path) | Path to the Dockerfile relative to source\_path. Defaults to "Dockerfile". | `string` | `"Dockerfile"` | no |
| <a name="input_ecr_repository_url"></a> [ecr\_repository\_url](#input\_ecr\_repository\_url) | ECR repository URL (without tag) that the built image will be pushed to. | `string` | n/a | yes |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Tag to push under. Default "latest" matches the CodeBuild path; consumers reference the image by sha256 digest regardless of tag so :latest is safe. | `string` | `"latest"` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture; drives the docker --platform value. | `string` | `"x86_64"` | no |
| <a name="input_name"></a> [name](#input\_name) | Human-readable identifier for the image (used in tags and resource names). Typically the processor name. | `string` | n/a | yes |
| <a name="input_source_path"></a> [source\_path](#input\_source\_path) | Absolute path to the directory containing the Dockerfile and build context. Hashes of all files under this path drive image rebuild detection. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied (where applicable -- docker provider resources don't accept tags). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_build_mode"></a> [build\_mode](#output\_build\_mode) | Always "local" for this module. |
| <a name="output_image_digest"></a> [image\_digest](#output\_image\_digest) | Registry-side sha256 digest of the pushed image. |
| <a name="output_image_id"></a> [image\_id](#output\_image\_id) | Local docker image ID (sha256 of the local image, NOT the registry digest). |
| <a name="output_image_tag_uri"></a> [image\_tag\_uri](#output\_image\_tag\_uri) | Tag-based image URI (repository:tag). Useful for non-Lambda consumers that expect the tag form. |
| <a name="output_image_uri"></a> [image\_uri](#output\_image\_uri) | Content-addressed image URI suitable for aws\_lambda\_function.image\_uri. Pins by sha256 digest so Lambda runs the exact image we pushed, not whatever :latest happens to be in ECR at invoke time. |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | ECR repository URL (echoed from input). |
| <a name="output_source_hash"></a> [source\_hash](#output\_source\_hash) | md5 hash of all files under var.source\_path. Drives rebuilds. |
