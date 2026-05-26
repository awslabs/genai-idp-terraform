# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Pattern-2 HITL Outputs
output "pattern2_hitl_enabled" {
  description = "Whether Pattern-2 HITL is enabled"
  value       = var.enable_pattern2_hitl
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
