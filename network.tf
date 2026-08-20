# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Private network deployment wiring.
#
# VPC placement of the Lambdas is threaded through main.tf via
# var.vpc_subnet_ids / var.vpc_security_group_ids. This file instantiates
# module.vpc_endpoints so those Lambdas reach AWS services over PrivateLink.
# Default-off: created only when var.private_network is set and at least one
# subnet is supplied; otherwise no endpoints exist and the deployment is public.

locals {
  # Active only when a private_network config (with vpc_id) and at least one
  # subnet are supplied.
  private_network_enabled = var.private_network != null && length(var.vpc_subnet_ids) > 0

  # A PRIVATE REST API needs the execute-api interface endpoint (v0.6.4: was
  # appsync-api before upstream replaced AppSync with API Gateway). Resolved in
  # locals.tf from api.api_gateway_visibility / the deprecated api.visibility.
  api_visibility_private = local.api_use_private

  # Interface endpoints required by the enabled processors/features. The map key
  # is the PrivateLink service suffix (com.amazonaws.<region>.<key>).
  #   - base: operational services every deployment's Lambdas need.
  #   - bedrock: any processor can call Bedrock.
  #   - textract: only the OCR processors (bedrock-llm, sagemaker-udop).
  #   - bedrock-agent-runtime: Knowledge Base / agent-analytics / chat retrieval.
  #   - execute-api: only when the REST API is PRIVATE.
  _vpc_endpoint_base = {
    ssm         = true
    ssmmessages = true
    ec2messages = true
    logs        = true
    monitoring  = true
    kms         = true
    sts         = true
    sqs         = true
    states      = true
    lambda      = true
    events      = true
    codebuild   = true
  }

  _vpc_endpoint_bedrock = local.processor_type != null ? {
    bedrock         = true
    bedrock-runtime = true
  } : {}

  _vpc_endpoint_textract = contains(["bedrock-llm", "sagemaker-udop"], coalesce(local.processor_type, "none")) ? {
    textract = true
  } : {}

  _vpc_endpoint_agent_runtime = (
    try(local.knowledge_base_config.enabled, false) ||
    try(local.agent_analytics_config.enabled, false) ||
    try(local.chat_with_document_config.enabled, false)
  ) ? { bedrock-agent-runtime = true } : {}

  _vpc_endpoint_execute_api = local.api_visibility_private ? { execute-api = true } : {}

  required_interface_endpoints = merge(
    local._vpc_endpoint_base,
    local._vpc_endpoint_bedrock,
    local._vpc_endpoint_textract,
    local._vpc_endpoint_agent_runtime,
    local._vpc_endpoint_execute_api,
  )
}

# Standalone VPC endpoints for the private deployment: the interface endpoints
# the enabled processors/features need plus the free S3/DynamoDB gateways,
# placed in the same subnets/SGs as the Lambdas.
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"
  count  = local.private_network_enabled ? 1 : 0

  vpc_id             = var.private_network.vpc_id
  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_security_group_ids

  private_dns_enabled         = var.private_network.private_dns_enabled
  enabled_interface_endpoints = local.required_interface_endpoints

  # Gateway endpoints route via the supplied route tables; skip them when no
  # route tables are provided so the module does not create unroutable gateways.
  enable_s3_gateway       = length(var.private_network.route_table_ids) > 0
  enable_dynamodb_gateway = length(var.private_network.route_table_ids) > 0
  route_table_ids         = var.private_network.route_table_ids

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Private-network endpoint-gap checks (plan-time).
#
# "Provisioned" is read from the keys of the module's interface_endpoint_ids
# output, which are known at plan time (the IDs themselves are not). The
# try(module.vpc_endpoints[0]..., {}) form is robust whether or not the
# count-gated module is instantiated.
# ---------------------------------------------------------------------------

# A PRIVATE REST API requires the execute-api interface endpoint. Passes on the
# default path (GLOBAL or unset).
#tfsec:ignore:*
check "private_api_endpoint_present" {
  assert {
    condition = !local.api_visibility_private || contains(
      keys(try(module.vpc_endpoints[0].interface_endpoint_ids, {})),
      "execute-api"
    )
    error_message = "api.api_gateway_visibility = PRIVATE requires the execute-api interface VPC endpoint so VPC clients can resolve and reach the REST API. Provision it by enabling a private-network deployment (set var.private_network and var.vpc_subnet_ids) so module.vpc_endpoints includes the \"execute-api\" endpoint."
  }
}

# Every interface endpoint the enabled processors/features require is actually
# provisioned. Guards against drift in the required-vs-enabled wiring and lists
# any missing endpoints. Skipped when private networking is off.
#tfsec:ignore:*
check "private_required_endpoints_present" {
  assert {
    condition = !local.private_network_enabled || length(setsubtract(
      keys(local.required_interface_endpoints),
      keys(try(module.vpc_endpoints[0].interface_endpoint_ids, {}))
    )) == 0
    error_message = "A private-network deployment is missing interface VPC endpoint(s) required by the enabled processors/features: ${join(", ", setsubtract(keys(local.required_interface_endpoints), keys(try(module.vpc_endpoints[0].interface_endpoint_ids, {}))))}. Enable the missing service(s) in module.vpc_endpoints (var.private_network) so the VPC-placed Lambdas can reach them privately."
  }
}
