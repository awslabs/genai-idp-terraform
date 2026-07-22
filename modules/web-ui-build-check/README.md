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
| <a name="input_script_path"></a> [script\_path](#input\_script\_path) | Absolute path to scripts/detect-node-runtime.sh. Defaults to the path relative to this module. | `string` | `""` | no |
| <a name="input_ui_local"></a> [ui\_local](#input\_ui\_local) | When true (root build.ui\_local), this module gates plan/apply on Node.js >= 18 being available. When false, the probe still runs but the check {} block does not fail plan. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_available"></a> [available](#output\_available) | True when Node.js >= 18 was detected on the host. |
| <a name="output_version"></a> [version](#output\_version) | Detected Node.js version (semver string), or empty if not found. |
