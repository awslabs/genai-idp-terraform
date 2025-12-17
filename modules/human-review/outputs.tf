# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "workteam_arn" {
  description = "ARN of the SageMaker workteam (externally provided)"
  value       = var.private_workforce_arn
}

output "workteam_name" {
  description = "Name of the SageMaker workteam (externally provided)"
  value       = var.workteam_name
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client for A2I"
  value       = aws_cognito_user_pool_client.a2i_client.id
}

output "flow_definition_role_arn" {
  description = "ARN of the IAM role for A2I Flow Definition"
  value       = aws_iam_role.a2i_flow_definition_role.arn
}

output "workforce_portal_url_parameter" {
  description = "SSM Parameter for workforce portal URL"
  value       = aws_ssm_parameter.workforce_portal_url.name
}

output "labeling_console_url_parameter" {
  description = "SSM Parameter for labeling console URL"
  value       = aws_ssm_parameter.labeling_console_url.name
}

# Pattern-2 HITL Outputs
output "pattern2_hitl_enabled" {
  description = "Whether Pattern-2 HITL is enabled"
  value       = var.enable_pattern2_hitl
}

output "pattern2_flow_definition_arn" {
  description = "ARN of the Pattern-2 A2I Flow Definition"
  value       = var.enable_pattern2_hitl ? aws_sagemaker_flow_definition.pattern2_hitl_flow[0].arn : null
}

output "pattern2_human_task_ui_arn" {
  description = "ARN of the Pattern-2 A2I Human Task UI"
  value       = var.enable_pattern2_hitl ? aws_sagemaker_human_task_ui.pattern2_hitl_ui[0].arn : null
}

output "pattern2_hitl_wait_function_arn" {
  description = "ARN of the Pattern-2 HITL Wait Lambda function"
  value       = var.enable_pattern2_hitl ? module.pattern2_hitl_wait_function[0].function_arn : null
}

output "pattern2_hitl_wait_function_name" {
  description = "Name of the Pattern-2 HITL Wait Lambda function"
  value       = var.enable_pattern2_hitl ? module.pattern2_hitl_wait_function[0].function_name : null
}

output "pattern2_hitl_process_function_arn" {
  description = "ARN of the Pattern-2 HITL Process Lambda function"
  value       = var.enable_pattern2_hitl ? module.pattern2_hitl_process_function[0].function_arn : null
}

output "pattern2_hitl_process_function_name" {
  description = "Name of the Pattern-2 HITL Process Lambda function"
  value       = var.enable_pattern2_hitl ? module.pattern2_hitl_process_function[0].function_name : null
}

output "pattern2_hitl_status_update_function_arn" {
  description = "ARN of the Pattern-2 HITL Status Update Lambda function"
  value       = var.enable_pattern2_hitl ? module.pattern2_hitl_status_update_function[0].function_arn : null
}

output "pattern2_hitl_status_update_function_name" {
  description = "Name of the Pattern-2 HITL Status Update Lambda function"
  value       = var.enable_pattern2_hitl ? module.pattern2_hitl_status_update_function[0].function_name : null
}

output "pattern2_hitl_confidence_threshold" {
  description = "Confidence threshold for Pattern-2 HITL triggering"
  value       = var.enable_pattern2_hitl ? var.hitl_confidence_threshold : null
}
