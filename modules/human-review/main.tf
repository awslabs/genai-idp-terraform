# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Human Review Module (v0.4.16)
#
# SageMaker A2I resources removed in v0.4.9 (DEV-001 / DEC-004).
# HITL is now handled by the `complete_section_review` Lambda in
# processing-environment-api.  This module retains only the Pattern-2
# Step Functions HITL functions (wait / process / status-update) that
# integrate with the existing state machine.

# =============================================================================
# Pattern-2 HITL Resources (conditionally created)
# =============================================================================

# Pattern-2 HITL Wait Function
module "pattern2_hitl_wait_function" {
  source = "./functions/pattern2-hitl-wait"
  count  = var.enable_pattern2_hitl ? 1 : 0

  name_prefix         = "${var.name_prefix}-p2-hitl-wait"
  tracking_table_name = var.tracking_table_name
  tracking_table_arn  = var.tracking_table_arn
  working_bucket_name = var.working_bucket_name
  working_bucket_arn  = var.working_bucket_arn
  image_uri           = var.hitl_wait_image_uri

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_tracing_mode  = var.lambda_tracing_mode

  tags = var.tags
}

# Pattern-2 HITL Process Function
module "pattern2_hitl_process_function" {
  source = "./functions/pattern2-hitl-process"
  count  = var.enable_pattern2_hitl ? 1 : 0

  name_prefix         = "${var.name_prefix}-p2-hitl-process"
  tracking_table_name = var.tracking_table_name
  tracking_table_arn  = var.tracking_table_arn
  output_bucket_arn   = var.output_bucket_arn
  state_machine_arn   = var.state_machine_arn

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_tracing_mode  = var.lambda_tracing_mode

  tags = var.tags
}

# Pattern-2 HITL Status Update Function
module "pattern2_hitl_status_update_function" {
  source = "./functions/pattern2-hitl-status-update"
  count  = var.enable_pattern2_hitl ? 1 : 0

  name_prefix       = "${var.name_prefix}-p2-hitl-status"
  output_bucket_arn = var.output_bucket_arn
  image_uri         = var.hitl_status_update_image_uri

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_tracing_mode  = var.lambda_tracing_mode

  tags = var.tags
}
