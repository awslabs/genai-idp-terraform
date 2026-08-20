# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "interface_endpoint_ids" {
  description = "Map of interface endpoint IDs keyed by service name (the enabled_interface_endpoints key)."
  value       = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.id }
}

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint, or null when disabled."
  value       = one(aws_vpc_endpoint.s3_gateway[*].id)
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB gateway endpoint, or null when disabled."
  value       = one(aws_vpc_endpoint.dynamodb_gateway[*].id)
}

# v0.6.4: replaces the former appsync_api_endpoint_id output. Feed this into
# api.api_gateway_vpc_endpoint_id when api.api_gateway_visibility = "PRIVATE".
output "execute_api_endpoint_id" {
  description = "ID of the execute-api interface endpoint, or null when not enabled. Required when the REST API visibility is PRIVATE."
  value       = try(aws_vpc_endpoint.interface["execute-api"].id, null)
}

output "endpoint_dns_entries" {
  description = "Map of DNS entries for each interface endpoint, keyed by service name."
  value       = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.dns_entry }
}
