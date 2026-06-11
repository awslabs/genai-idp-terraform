# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# When VPC is enabled (`var.vpc_config != null`), every Lambda role
# defined in this module needs the AWS-managed
# `AWSLambdaVPCAccessExecutionRole` policy so the Lambda can call
# `ec2:CreateNetworkInterface` / `DescribeNetworkInterfaces` /
# `DeleteNetworkInterface`. Without it, Lambda's CreateFunction call
# fails with: "The provided execution role does not have permissions
# to call CreateNetworkInterface on EC2".
#
# Roles with their own count predicate (e.g. agent_chat_processor)
# already exist conditionally; we mirror that gating here so the
# attachment count matches the role count.

locals {
  lambda_vpc_access_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Always-on Lambdas (no feature flag)
resource "aws_iam_role_policy_attachment" "abort_workflow_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.abort_workflow.name
  policy_arn = local.lambda_vpc_access_arn
}

resource "aws_iam_role_policy_attachment" "sync_bda_idp_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.sync_bda_idp.name
  policy_arn = local.lambda_vpc_access_arn
}

# Feature-gated Lambdas — count must match the role's own count

resource "aws_iam_role_policy_attachment" "agent_chat_processor_vpc" {
  count      = var.enable_agent_companion_chat && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.agent_chat_processor[0].name
  policy_arn = local.lambda_vpc_access_arn
}

resource "aws_iam_role_policy_attachment" "agent_chat_resolver_vpc" {
  count      = var.enable_agent_companion_chat && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.agent_chat_resolver[0].name
  policy_arn = local.lambda_vpc_access_arn
}

resource "aws_iam_role_policy_attachment" "chat_session_resolvers_vpc" {
  count      = var.enable_agent_companion_chat && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.chat_session_resolvers[0].name
  policy_arn = local.lambda_vpc_access_arn
}

resource "aws_iam_role_policy_attachment" "capacity_planning_vpc" {
  count      = var.enable_capacity_planning && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.capacity_planning[0].name
  policy_arn = local.lambda_vpc_access_arn
}

resource "aws_iam_role_policy_attachment" "dataset_deployers_vpc" {
  count      = (local.enable_ocr_benchmark_deployer || local.enable_docsplit_testset_deployer) && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.dataset_deployers[0].name
  policy_arn = local.lambda_vpc_access_arn
}

# error_analyzer_vpc / error_analyzer_resolver_vpc — REMOVED at v0.5.12.
# The error-analyzer feature was removed upstream; see error-analyzer.tf for the
# `removed {}` blocks that drop the orphaned VPC attachments from state.

resource "aws_iam_role_policy_attachment" "complete_section_review_vpc" {
  count      = var.enable_hitl && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.complete_section_review[0].name
  policy_arn = local.lambda_vpc_access_arn
}

# NOTE: MCP integration moved to the `mcp-integration` feature submodule
# (modules/features/mcp-integration) in v0.5.12-tf.0. Its VPC/ENI attachment
# (`agentcore_mcp_handler_vpc`) now lives inside that submodule; the
# gateway-manager Lambda is intentionally never placed in a VPC (the AgentCore
# control plane doesn't support PrivateLink).

resource "aws_iam_role_policy_attachment" "test_studio_lambdas_vpc" {
  count      = var.enable_test_studio && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.test_studio_lambdas[0].name
  policy_arn = local.lambda_vpc_access_arn
}
