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
