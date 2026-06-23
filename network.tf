# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Private Network Deployment wiring (C7, Req 8.1, 8.2, 8.3)
#
# VPC *placement* of the IDP Lambdas (and other VPC-capable resources) is already
# threaded throughout main.tf via `var.vpc_subnet_ids` / `var.vpc_security_group_ids`
# (each processor module + processing-environment + feature submodules receive the
# same subnet/SG inputs). This file owns the second half of a private deployment:
# instantiating `module.vpc_endpoints` so those VPC-placed Lambdas reach the AWS
# services the *enabled* processors and features need over PrivateLink — without
# public internet egress.
#
# Default-off: `module.vpc_endpoints` is created only when `var.private_network`
# is set AND at least one private subnet is supplied. With the defaults
# (private_network = null, empty subnet/SG lists) no endpoint resources exist and
# the deployment behaves exactly as a public one.

locals {
  # A private-network deployment is active only when the operator has supplied a
  # private_network config (with a vpc_id) and at least one subnet to place the
  # interface ENIs in. Empty subnets ⇒ nothing to privately route ⇒ no module.
  private_network_enabled = var.private_network != null && length(var.vpc_subnet_ids) > 0

  # Whether the AppSync API is configured PRIVATE (B3). PRIVATE requires the
  # appsync-api interface endpoint so VPC clients can resolve/reach the GraphQL
  # API (Req 8.3 / 9.3).
  appsync_visibility_private = try(var.api.visibility, "GLOBAL") == "PRIVATE"

  # Interface endpoints required by the enabled processors and features (Req 8.2).
  # The map key doubles as the PrivateLink service suffix
  # (com.amazonaws.<region>.<key>) so the set stays partition-portable.
  #
  # - Base operational services every IDP deployment's Lambdas need: SSM (config
  #   + Session Manager), CloudWatch logs/metrics, KMS (encryption), STS
  #   (credentials / assume-role), SQS (work queues), Step Functions (states),
  #   Lambda (invoke), EventBridge (events), and CodeBuild (the layer-build
  #   projects run inside the VPC when one is configured).
  # - Bedrock + Bedrock runtime: any configured processor can call Bedrock
  #   (classification/extraction/summarization), so enable whenever a processor
  #   is set.
  # - Textract: only the OCR-based processors (bedrock-llm, sagemaker-udop) call
  #   Textract; BDA does its own document extraction.
  # - Bedrock agent runtime: used by Knowledge Base / agent-analytics / chat
  #   retrieval features.
  # - appsync-api: only required when the API is PRIVATE (Req 8.3).
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

  _vpc_endpoint_appsync = local.appsync_visibility_private ? { appsync-api = true } : {}

  required_interface_endpoints = merge(
    local._vpc_endpoint_base,
    local._vpc_endpoint_bedrock,
    local._vpc_endpoint_textract,
    local._vpc_endpoint_agent_runtime,
    local._vpc_endpoint_appsync,
  )
}

# Standalone VPC endpoints for the private deployment. Provisions exactly the
# interface endpoints the enabled processors/features need (plus the free
# S3/DynamoDB gateway endpoints), placed in the same private subnets/SGs as the
# IDP Lambdas. Partition-aware service names live inside the module.
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
# Private-network endpoint-gap checks (Req 8.3, 8.4, 9.3)
#
# These surface, at *plan* time, a private deployment whose interface-endpoint
# set does not cover what the chosen configuration needs — instead of letting
# the gap show up only as a runtime connection timeout inside the VPC.
#
# "Provisioned" is read from the *keys* of the vpc-endpoints module output
# (interface_endpoint_ids). Those keys come from the module's for_each enable
# map and are known at plan time; the endpoint IDs themselves are
# known-after-apply, so comparing keys (rather than `appsync_api_endpoint_id !=
# null`) keeps these a plan-time gate rather than an apply-time one. The
# `try(module.vpc_endpoints[0]..., {})` form makes the expression robust whether
# or not the count-gated module is instantiated (count = 0 ⇒ {}).
# ---------------------------------------------------------------------------

# Validation: PRIVATE AppSync requires the appsync-api interface VPC endpoint.
# When var.api.visibility = "PRIVATE" the GraphQL API is reachable only through
# the appsync-api PrivateLink endpoint; without it, VPC clients cannot resolve or
# reach the API at all. Passes on the default path (GLOBAL, or visibility unset).
#tfsec:ignore:*
check "private_appsync_endpoint_present" {
  assert {
    condition = try(var.api.visibility, "GLOBAL") != "PRIVATE" || contains(
      keys(try(module.vpc_endpoints[0].interface_endpoint_ids, {})),
      "appsync-api"
    )
    error_message = "AppSyncVisibility = PRIVATE requires the appsync-api interface VPC endpoint so VPC clients can resolve and reach the GraphQL API. Provision it by enabling a private-network deployment (set var.private_network and var.vpc_subnet_ids) so module.vpc_endpoints includes the \"appsync-api\" endpoint. See docs/migration-v0.4.16-to-v0.5.12.md."
  }
}

# Validation (best-effort): every interface endpoint the enabled processors and
# features require is actually provisioned. This compares the required set
# (local.required_interface_endpoints, derived from the enabled processor +
# features) against the set module.vpc_endpoints actually provisions. By
# construction the root wires required ⇒ enabled, so this normally holds; the
# check guards against drift if that wiring is ever changed and gives the
# operator a concrete list of missing endpoints rather than a runtime failure.
# Skipped entirely when private networking is off (Lambdas use public egress).
#tfsec:ignore:*
check "private_required_endpoints_present" {
  assert {
    condition = !local.private_network_enabled || length(setsubtract(
      keys(local.required_interface_endpoints),
      keys(try(module.vpc_endpoints[0].interface_endpoint_ids, {}))
    )) == 0
    error_message = "A private-network deployment is missing interface VPC endpoint(s) required by the enabled processors/features: ${join(", ", setsubtract(keys(local.required_interface_endpoints), keys(try(module.vpc_endpoints[0].interface_endpoint_ids, {}))))}. Enable the missing service(s) in module.vpc_endpoints (var.private_network) so the VPC-placed Lambdas can reach them privately. See docs/migration-v0.4.16-to-v0.5.12.md."
  }
}
