# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IWebApplication - Behavioral interface outputs from CDK implementation
output "bucket" {
  description = "The S3 bucket where the web application assets are deployed"
  value = {
    bucket_name = local.web_app_bucket.bucket_name
    bucket_arn  = local.web_app_bucket.bucket_arn
  }
}

output "distribution" {
  description = "The CloudFront distribution that serves the web application (CloudFront hosting mode only)"
  value = local.create_cloudfront ? {
    distribution_id          = aws_cloudfront_distribution.web_distribution[0].id
    distribution_arn         = aws_cloudfront_distribution.web_distribution[0].arn
    distribution_domain_name = aws_cloudfront_distribution.web_distribution[0].domain_name
  } : null
}

# Additional outputs for integration and debugging
output "application_url" {
  description = "URL of the web application (CloudFront domain in CloudFront mode; the supplied web_ui_url otherwise)"
  value       = local.app_url
}

# Legacy outputs for backward compatibility
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = local.cloudfront_distribution_id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = local.cloudfront_domain_name
}

output "settings_parameter" {
  description = "SSM Parameter for Web UI settings"
  value = {
    parameter_name = aws_ssm_parameter.web_ui_settings.name
    parameter_arn  = aws_ssm_parameter.web_ui_settings.arn
  }
}

output "codebuild_project" {
  description = "CodeBuild project for building and deploying the web UI (null when ui_local = true)"
  value = !var.ui_local ? {
    project_name = aws_codebuild_project.ui_build[0].name
    project_arn  = aws_codebuild_project.ui_build[0].arn
  } : null
}

output "build_mode" {
  description = "Active build mode: codebuild or local."
  value       = var.ui_local ? "local" : "codebuild"
}

output "web_ui_test_env_file" {
  description = "Environment file content for local UI development"
  value       = <<EOF
REACT_APP_USER_POOL_ID=${var.user_identity.user_pool.user_pool_id}
REACT_APP_USER_POOL_CLIENT_ID=${var.user_identity.user_pool_client.user_pool_client_id}
REACT_APP_IDENTITY_POOL_ID=${var.user_identity.identity_pool.identity_pool_id}
VITE_API_BASE_URL=${var.api_url}
VITE_STREAM_URL=${var.stream_url != null ? var.stream_url : ""}
VITE_UI_BASE_PATH=${local.ui_base_path}
REACT_APP_AWS_REGION=${data.aws_region.current.id}
REACT_APP_SETTINGS_PARAMETER=${aws_ssm_parameter.web_ui_settings.name}
REACT_APP_SHOULD_HIDE_SIGN_UP=${var.should_allow_sign_up_email_domain ? "false" : "true"}
REACT_APP_CLOUDFRONT_DOMAIN=${local.app_url != null ? "${local.app_url}/" : ""}
EOF
}
