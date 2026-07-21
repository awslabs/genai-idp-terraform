# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local web UI build path (active only when var.ui_local = true).
#
# Runs `npm ci && npm run build` on the deploy host, syncs the output to the
# web-app S3 bucket, and invalidates the CloudFront distribution cache. This
# replaces the CodeBuild + trigger-Lambda pipeline for faster dev-loop iteration.

resource "null_resource" "local_ui_build" {
  count = var.ui_local ? 1 : 0

  triggers = {
    # Rebuild when source code changes.
    source_code_hash = data.archive_file.ui_source.output_base64sha256
    # Rebuild when config (VITE_ env vars) changes.
    settings_hash = sha256(jsonencode({
      user_pool_id               = var.user_identity.user_pool.user_pool_id
      user_pool_client_id        = var.user_identity.user_pool_client.user_pool_client_id
      identity_pool_id           = var.user_identity.identity_pool.identity_pool_id
      appsync_url                = var.api_url
      cloudfront_domain          = local.app_url
      knowledge_base_enabled     = var.knowledge_base_enabled
      discovery_bucket_name      = var.discovery_bucket_name
      reporting_bucket_name      = var.reporting_bucket_name
      evaluation_baseline_bucket = var.evaluation_baseline_bucket_name
      idp_pattern                = var.idp_pattern
    }))
  }

  provisioner "local-exec" {
    command     = "${path.module}/../../scripts/build-web-ui.sh"
    working_dir = path.module

    environment = {
      UI_SOURCE_DIR              = "${path.module}/../../sources/src/ui"
      WEB_APP_BUCKET             = local.web_app_bucket.bucket_name
      CLOUDFRONT_DISTRIBUTION_ID = local.cloudfront_distribution_id != null ? local.cloudfront_distribution_id : ""
      VITE_SETTINGS_PARAMETER    = aws_ssm_parameter.web_ui_settings.name
      VITE_USER_POOL_ID          = var.user_identity.user_pool.user_pool_id
      VITE_USER_POOL_CLIENT_ID   = var.user_identity.user_pool_client.user_pool_client_id
      VITE_IDENTITY_POOL_ID      = var.user_identity.identity_pool.identity_pool_id
      VITE_APPSYNC_GRAPHQL_URL   = var.api_url
      VITE_AWS_REGION            = data.aws_region.current.id
      VITE_SHOULD_HIDE_SIGN_UP   = var.should_allow_sign_up_email_domain ? "false" : "true"
      VITE_CLOUDFRONT_DOMAIN     = local.app_url != null ? "${local.app_url}/" : ""
    }
  }

  depends_on = [
    aws_ssm_parameter.web_ui_settings
  ]
}
