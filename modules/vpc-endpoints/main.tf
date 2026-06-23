# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Standalone, partition-aware VPC endpoints module. Generalizes the inline
# interface/gateway endpoints from the bedrock-llm-processor-vpc example into a
# reusable building block: each interface endpoint is individually toggleable and
# service names are rendered from the current region so the module works across
# partitions (including us-gov-*).

data "aws_region" "current" {}

locals {
  # Only the interface endpoints toggled on. The map key doubles as the
  # PrivateLink service suffix, so service names render as
  # com.amazonaws.<region>.<key> and partition-quirk names (e.g. appsync-api)
  # are expressed directly in the service map by the caller.
  enabled_interface_endpoints = {
    for service, enabled in var.enabled_interface_endpoints : service => service
    if enabled
  }
}

# Interface endpoints (PrivateLink ENIs).
resource "aws_vpc_endpoint" "interface" {
  for_each = local.enabled_interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = var.private_dns_enabled

  tags = merge(var.tags, {
    Name = "${each.key}-endpoint"
  })
}

# Gateway endpoints (free; routed via route tables).
resource "aws_vpc_endpoint" "s3_gateway" {
  count = var.enable_s3_gateway ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.tags, {
    Name = "s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb_gateway" {
  count = var.enable_dynamodb_gateway ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.tags, {
    Name = "dynamodb-endpoint"
  })
}

