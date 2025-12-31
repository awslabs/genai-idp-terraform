# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Web UI Module
 *
 * This module creates the web user interface for the IDP solution with configurable infrastructure.
 * It can either create CloudFront distribution and S3 bucket with sensible defaults, or work with
 * existing infrastructure provided by the user.
 *
 * ## Modes of Operation
 *
 * ### Full Infrastructure Mode (create_infrastructure = true)
 * - Creates S3 bucket for web app hosting
 * - Creates CloudFront distribution with security headers and WAF
 * - Configures CORS on input/output buckets
 * - Builds and deploys React application
 * - Invalidates CloudFront cache after deployment
 *
 * ### Bring Your Own Infrastructure Mode (create_infrastructure = false)
 * - Uses provided S3 bucket for web app hosting
 * - Uses provided CloudFront distribution ID for cache invalidation (optional)
 * - Builds and deploys React application
 * - User is responsible for CloudFront and CORS configuration
 */

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
# Validation for required variables when create_infrastructure = false
locals {
  # Validate required variables when using existing infrastructure

  # Extract bucket names from ARNs (format: arn:${data.aws_partition.current.partition}:s3:::bucket-name)
  input_bucket_name  = element(split(":", var.input_bucket_arn), 5)
  output_bucket_name = element(split(":", var.output_bucket_arn), 5)

  # Extract table name from ARN (format: arn:${data.aws_partition.current.partition}:dynamodb:region:account:table/table-name)

  # Extract key ID from ARN (format: arn:${data.aws_partition.current.partition}:kms:region:account:key/key-id)

  # Network environment check
  has_network_environment = var.vpc_id != null && length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0

  # Determine web app bucket configuration based on mode
  web_app_bucket = var.create_infrastructure ? {
    bucket_name = aws_s3_bucket.web_app_bucket[0].id
    bucket_arn  = aws_s3_bucket.web_app_bucket[0].arn
    } : {
    bucket_name = var.web_app_bucket_name
    bucket_arn  = "arn:${data.aws_partition.current.partition}:s3:::${var.web_app_bucket_name}"
  }

  # Determine CloudFront distribution ID based on mode
  cloudfront_distribution_id = var.create_infrastructure ? aws_cloudfront_distribution.web_distribution[0].id : var.cloudfront_distribution_id
  cloudfront_domain_name     = var.create_infrastructure ? aws_cloudfront_distribution.web_distribution[0].domain_name : null
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values for resource configuration
locals {
  # Common tags
  common_tags = merge(var.tags, {
    Name        = "${var.name_prefix}-web-ui"
    Environment = var.name_prefix
  })

  # Web UI settings as a structured object
  web_ui_settings = {
    InputBucket                    = local.input_bucket_name
    OutputBucket                   = local.output_bucket_name
    DiscoveryBucket                = var.discovery_bucket_name
    ReportingBucket                = var.reporting_bucket_name
    EvaluationBaselineBucket       = var.evaluation_baseline_bucket_name
    IDPPattern                     = var.idp_pattern
    ShouldUseDocumentKnowledgeBase = var.knowledge_base_enabled ? "true" : "false"
    Version                        = "0.3.18"
    StackName                      = var.display_name != null ? var.display_name : "${var.name_prefix}-processor"
    # Add other settings as needed
  }
}

# SSM Parameter for Web UI settings (equivalent to CDK settingsParameter)
resource "aws_ssm_parameter" "web_ui_settings" {
  name        = "/${var.name_prefix}/web-ui-settings"
  description = "Settings for the Web UI"
  type        = "String"
  value       = jsonencode(local.web_ui_settings)

  tags = local.common_tags
}

# Grant settings parameter read access to authenticated role
resource "aws_iam_role_policy" "settings_parameter_access" {
  name = "${var.name_prefix}-settings-parameter-access"
  role = basename(var.user_identity.identity_pool.authenticated_role_arn)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = aws_ssm_parameter.web_ui_settings.arn
      }
    ]
  })
}

# Web App S3 Bucket (created only if create_infrastructure is true)
#checkov:skip=CKV_AWS_145:S3 bucket encryption is configured via separate aws_s3_bucket_server_side_encryption_configuration resource
resource "aws_s3_bucket" "web_app_bucket" {
  count         = var.create_infrastructure ? 1 : 0
  bucket        = "${var.prefix}-webapp-${random_string.suffix.result}"
  force_destroy = true

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web_app_bucket" {
  count  = var.create_infrastructure ? 1 : 0
  bucket = aws_s3_bucket.web_app_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "web_app_bucket" {
  count  = var.create_infrastructure ? 1 : 0
  bucket = aws_s3_bucket.web_app_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "web_app_bucket" {
  count  = var.create_infrastructure ? 1 : 0
  bucket = aws_s3_bucket.web_app_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "web_app_bucket" {
  count  = var.create_infrastructure ? 1 : 0
  bucket = aws_s3_bucket.web_app_bucket[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Server access logs configuration if logging bucket is provided
resource "aws_s3_bucket_logging" "web_app_bucket" {
  count  = var.create_infrastructure && var.logging_bucket != null ? 1 : 0
  bucket = aws_s3_bucket.web_app_bucket[0].id

  target_bucket = var.logging_bucket.bucket_name
  target_prefix = "webapp-bucket-logs/"
}

# Note: SSL enforcement is now handled in the combined CloudFront policy below

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "${var.name_prefix} CloudFront OAI for ${local.web_app_bucket.bucket_name}"
}

# Grant CloudFront OAI read access to the web app bucket (when we create the bucket)
resource "aws_s3_bucket_policy" "web_app_bucket_cloudfront" {
  count  = var.create_infrastructure ? 1 : 0
  bucket = aws_s3_bucket.web_app_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.web_app_bucket[0].arn}/*"
      },
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.web_app_bucket[0].arn,
          "${aws_s3_bucket.web_app_bucket[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket.web_app_bucket,
    aws_cloudfront_origin_access_identity.oai
  ]
}

# CloudFront Distribution
# WAF Web ACL for CloudFront protection
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.name_prefix}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rule - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CloudFrontWAFMetric"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_cloudfront_distribution" "web_distribution" {
  count = var.create_infrastructure ? 1 : 0

  origin {
    domain_name = "${local.web_app_bucket.bucket_name}.s3.${data.aws_region.current.id}.amazonaws.com"
    origin_id   = "S3-${local.web_app_bucket.bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_All" # Default to global distribution
  web_acl_id          = var.enable_waf ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null

  # Geo restriction configuration (always required)
  restrictions {
    geo_restriction {
      restriction_type = "none" # Default to no geo restrictions
      locations        = []
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${local.web_app_bucket.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    # Security headers
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Custom error pages for SPA routing
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain_name == null
    acm_certificate_arn            = var.custom_domain_name != null ? var.acm_certificate_arn : null
    ssl_support_method             = var.custom_domain_name != null ? "sni-only" : null
    # Only set minimum_protocol_version for custom certificates, as CloudFront default certificate has its own defaults
    minimum_protocol_version = var.custom_domain_name != null ? "TLSv1.2_2021" : null
  }

  # Optional access logging
  dynamic "logging_config" {
    for_each = var.logging_bucket != null ? [1] : []
    content {
      bucket          = "${var.logging_bucket.bucket_name}.s3.amazonaws.com"
      prefix          = "cloudfront-logs/"
      include_cookies = false
    }
  }

  tags = local.common_tags
}

# CloudFront Response Headers Policy for security
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.name_prefix}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  custom_headers_config {
    items {
      header   = "X-Content-Security-Policy"
      value    = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;"
      override = true
    }
  }
}

# Add CORS rules to input and output buckets for web UI access
resource "aws_s3_bucket_cors_configuration" "input_bucket_cors" {
  bucket = local.input_bucket_name

  cors_rule {
    allowed_headers = [
      "Content-Type",
      "x-amz-content-sha256",
      "x-amz-date",
      "Authorization",
      "x-amz-security-token"
    ]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = var.create_infrastructure ? ["https://${aws_cloudfront_distribution.web_distribution[0].domain_name}"] : ["*"]
    expose_headers  = ["ETag", "x-amz-server-side-encryption"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "output_bucket_cors" {
  bucket = local.output_bucket_name

  cors_rule {
    allowed_headers = [
      "Content-Type",
      "x-amz-content-sha256",
      "x-amz-date",
      "Authorization",
      "x-amz-security-token"
    ]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = var.create_infrastructure ? ["https://${aws_cloudfront_distribution.web_distribution[0].domain_name}"] : ["*"]
    expose_headers  = ["ETag", "x-amz-server-side-encryption"]
    max_age_seconds = 3000
  }
}

# Registry-compatible build directory approach
locals {
  # Module-specific build directory that works both locally and in registry
  module_build_dir = "${path.module}/.terraform-build"
  # Unique identifier for this module instance
  module_instance_id = substr(md5("${path.module}-web-ui"), 0, 8)
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Generate unique build ID for this module instance
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    # Include module instance ID for uniqueness
    module_instance_id = local.module_instance_id
    # Trigger rebuild when content changes
    content_hash = md5("web-ui-functions")
  }
}

data "archive_file" "ui_source" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/ui"
  output_path = "${local.module_build_dir}/ui-source_${random_id.build_id.hex}.zip"

  depends_on = [null_resource.create_module_build_dir]
}

# S3 deployment for React app source code
resource "aws_s3_object" "react_app_source" {
  bucket = local.web_app_bucket.bucket_name
  key    = "code/ui-source.zip"
  source = data.archive_file.ui_source.output_path
  etag   = data.archive_file.ui_source.output_base64sha256

  tags = local.common_tags
}

# CodeBuild Project for building and deploying the UI
# Wait for IAM role policy to propagate
# We reach propagation issue, where IAM role and policy were created, CodeBuild was able to use it within its execution.
# The execution was failing, as mentioned policies takes no effect yet.
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.codebuild_role,
    aws_iam_role_policy.codebuild_policy
  ]

  create_duration = "30s"
}

# IAM permissions are handled by time_sleep.wait_for_iam_propagation
# No additional testing needed with Lambda-based approach

resource "aws_codebuild_project" "ui_build" {
  name         = "${var.name_prefix}-webui-build"
  description  = "Web UI build for GenAIDP stack - ${var.name_prefix}"
  service_role = aws_iam_role.codebuild_role.arn

  depends_on = [
    time_sleep.wait_for_iam_propagation,
    aws_iam_role.codebuild_role,
    aws_iam_role_policy.codebuild_policy
  ]

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    # Privileged mode is not required - this build only performs Node.js npm installations,
    # npm build operations, and AWS CLI commands (S3 copy, CloudFront invalidation). No Docker operations are used.
    privileged_mode = false

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.id
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "SOURCE_CODE_LOCATION"
      value = "${local.web_app_bucket.bucket_name}/code/ui-source.zip"
    }

    environment_variable {
      name  = "WEBAPP_BUCKET"
      value = local.web_app_bucket.bucket_name
    }

    environment_variable {
      name  = "CLOUDFRONT_DISTRIBUTION_ID"
      value = local.cloudfront_distribution_id != null ? local.cloudfront_distribution_id : ""
    }

    environment_variable {
      name  = "REACT_APP_SETTINGS_PARAMETER"
      value = aws_ssm_parameter.web_ui_settings.name
    }

    environment_variable {
      name  = "REACT_APP_USER_POOL_ID"
      value = var.user_identity.user_pool.user_pool_id
    }

    environment_variable {
      name  = "REACT_APP_USER_POOL_CLIENT_ID"
      value = var.user_identity.user_pool_client.user_pool_client_id
    }

    environment_variable {
      name  = "REACT_APP_IDENTITY_POOL_ID"
      value = var.user_identity.identity_pool.identity_pool_id
    }

    environment_variable {
      name  = "REACT_APP_APPSYNC_GRAPHQL_URL"
      value = var.api_url
    }

    environment_variable {
      name  = "REACT_APP_AWS_REGION"
      value = data.aws_region.current.id
    }

    environment_variable {
      name  = "REACT_APP_SHOULD_HIDE_SIGN_UP"
      value = var.should_allow_sign_up_email_domain ? "false" : "true"
    }

    environment_variable {
      name  = "REACT_APP_CLOUDFRONT_DOMAIN"
      value = local.cloudfront_domain_name != null ? "https://${local.cloudfront_domain_name}/" : ""
    }
  }

  source {
    type      = "S3"
    location  = "${local.web_app_bucket.bucket_name}/code/ui-source.zip"
    buildspec = file("${path.module}/buildspec.yml")
  }

  # VPC configuration if network environment is provided
  dynamic "vpc_config" {
    for_each = local.has_network_environment ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  # Logging configuration
  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/${var.name_prefix}-webui-build"
      stream_name = "build-log"
    }

    s3_logs {
      status = "DISABLED"
    }
  }

  tags = local.common_tags

  # Remove explicit dependency on log group to avoid circular dependency
  # CodeBuild will auto-create the log group with proper permissions
}

# CloudWatch Log Group for CodeBuild - Let CodeBuild auto-create this
resource "aws_iam_role" "codebuild_role" {
  name = "${var.name_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.name_prefix}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-webui-build",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-webui-build:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          local.web_app_bucket.bucket_arn,
          "${local.web_app_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = var.encryption_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "logs.${data.aws_region.current.id}.amazonaws.com"
          }
        }
      }
      ], local.cloudfront_distribution_id != null ? [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = var.create_infrastructure ? aws_cloudfront_distribution.web_distribution[0].arn : "*"
      }
    ] : [])
  })
}

# Attach VPC execution role if needed
resource "aws_iam_role_policy_attachment" "codebuild_vpc_execution" {
  count      = local.has_network_environment ? 1 : 0
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSCodeBuildVPCAccessExecutionRole"
}

# UI CodeBuild triggering is now handled by Lambda function in lambda.tf
# See aws_lambda_invocation.trigger_ui_codebuild resource

# Optional: Cleanup old build artifacts
resource "null_resource" "cleanup_build_artifacts" {
  depends_on = [
    # This will be triggered after successful Lambda-based deployments
    aws_lambda_invocation.trigger_ui_codebuild
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Cleaning up old build artifacts..."
      # Remove build files older than 1 day but keep the directory
      find "${local.module_build_dir}" -name "*.zip" -mtime +1 -delete 2>/dev/null || true
      echo "Build artifact cleanup completed"
    EOT
  }

  triggers = {
    # Run cleanup when Lambda build completes successfully
    build_success = local.ui_build_success ? "true" : "false"
    build_id      = random_id.build_id.hex
  }
}
