## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_external"></a> [external](#provider\_external) | 2.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [external_external.probe](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Runtime selector mirroring root var.build.container\_runtime. "auto" probes docker -> podman -> finch in order. Explicit values probe only that runtime. | `string` | `"auto"` | no |
| <a name="input_lambda_local"></a> [lambda\_local](#input\_lambda\_local) | When true (root build.lambda\_local), this module gates plan/apply on a usable container runtime. When false, the probe still runs but the check {} block does not fail plan. | `bool` | `false` | no |
| <a name="input_script_path"></a> [script\_path](#input\_script\_path) | Absolute path to scripts/detect-container-runtime.sh. Defaults to the path relative to this module. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_available"></a> [available](#output\_available) | True when at least one runtime was found. Mirrors the check {} assertion. |
| <a name="output_docker_host"></a> [docker\_host](#output\_docker\_host) | Value to feed kreuzwerker/docker provider's `host`. Empty string means use the provider default (platform docker socket); unix://path values point at podman/finch sockets. |
| <a name="output_runtime"></a> [runtime](#output\_runtime) | Detected container runtime: docker, podman, finch, or none. |
