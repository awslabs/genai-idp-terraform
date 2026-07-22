## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.54.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_vpc_endpoint.dynamodb_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_dynamodb_gateway"></a> [enable\_dynamodb\_gateway](#input\_enable\_dynamodb\_gateway) | Whether to create the DynamoDB gateway endpoint. | `bool` | `true` | no |
| <a name="input_enable_s3_gateway"></a> [enable\_s3\_gateway](#input\_enable\_s3\_gateway) | Whether to create the S3 gateway endpoint. | `bool` | `true` | no |
| <a name="input_enabled_interface_endpoints"></a> [enabled\_interface\_endpoints](#input\_enabled\_interface\_endpoints) | Map of interface endpoint service keys to a boolean enabling each one. The key is the<br/>AWS service suffix as it appears in the PrivateLink service name<br/>(`com.amazonaws.<region>.<key>`), so it is partition-portable. Set a key to `false`<br/>(or omit it) to skip provisioning that endpoint. The default covers the full set IDP<br/>can require; consumers typically narrow it to the services their enabled processors<br/>and features actually use. | `map(bool)` | <pre>{<br/>  "appsync-api": true,<br/>  "bedrock": true,<br/>  "bedrock-agent-runtime": true,<br/>  "bedrock-runtime": true,<br/>  "codebuild": true,<br/>  "ec2messages": true,<br/>  "events": true,<br/>  "kms": true,<br/>  "lambda": true,<br/>  "logs": true,<br/>  "monitoring": true,<br/>  "sqs": true,<br/>  "ssm": true,<br/>  "ssmmessages": true,<br/>  "states": true,<br/>  "sts": true,<br/>  "textract": true<br/>}</pre> | no |
| <a name="input_private_dns_enabled"></a> [private\_dns\_enabled](#input\_private\_dns\_enabled) | Whether to enable private DNS for the interface endpoints. Enabled by default; supported by all services in the default endpoint set. | `bool` | `true` | no |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | List of route table IDs to associate with the S3 and DynamoDB gateway endpoints. Required when either gateway endpoint is enabled. | `list(string)` | `[]` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security group IDs to associate with the interface endpoints. This module does<br/>not manage the security group; the caller owns it. The SG MUST allow inbound HTTPS (TCP<br/>443) from the VPC CIDR, not just from the Lambda SG. In-VPC browser clients (WorkSpaces,<br/>VPN, bastion) send AppSync GraphQL requests directly to the `appsync-api` interface<br/>endpoint rather than through the ALB, so an SG that only permits 443 from the Lambda SG<br/>leaves the UI hanging when `api.visibility = "PRIVATE"` (this is the upstream IDP 0.5.15<br/>"VpcCidr" fix). See `examples/bedrock-llm-processor-vpc` for a reference SG that opens<br/>443 from the VPC CIDR. | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs in which to place the interface endpoint ENIs. Use the private subnets of the deployment. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC in which to create the endpoints. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_appsync_api_endpoint_id"></a> [appsync\_api\_endpoint\_id](#output\_appsync\_api\_endpoint\_id) | ID of the appsync-api interface endpoint, or null when not enabled. Required when AppSync visibility is PRIVATE. |
| <a name="output_dynamodb_endpoint_id"></a> [dynamodb\_endpoint\_id](#output\_dynamodb\_endpoint\_id) | ID of the DynamoDB gateway endpoint, or null when disabled. |
| <a name="output_endpoint_dns_entries"></a> [endpoint\_dns\_entries](#output\_endpoint\_dns\_entries) | Map of DNS entries for each interface endpoint, keyed by service name. |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Map of interface endpoint IDs keyed by service name (the enabled\_interface\_endpoints key). |
| <a name="output_s3_endpoint_id"></a> [s3\_endpoint\_id](#output\_s3\_endpoint\_id) | ID of the S3 gateway endpoint, or null when disabled. |
