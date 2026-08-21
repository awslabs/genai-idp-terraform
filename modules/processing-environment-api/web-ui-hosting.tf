# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Web UI S3 proxy (serve_web_ui = true / web_ui.hosting = "APIGateway").
#
# Faithfully mirrors sources/nested/api-resolvers/template.yaml:
#   WebUIProxyRole (here: aws_iam_role.web_ui_proxy), WebUIRootMethod,
#   WebUIProxyResource, WebUIProxyMethod.
#
# Serves the React SPA from the web-app bucket directly through this REST API,
# on the same stage as the /op transport. Two GET routes:
#   GET /         -> s3://<bucket>/index.html   (SPA shell)
#   GET /{proxy+} -> s3://<bucket>/{proxy}      (assets, favicon, etc.)
#
# The explicit /op resource takes precedence over the greedy {proxy+} (API
# Gateway matches specific path parts before catch-all), so the transport route
# is unaffected. Both GETs are AuthorizationType NONE — the browser fetches the
# SPA shell/assets with no JWT (auth happens later inside the app against /op).
# Stage-level WAF and the PRIVATE endpoint policy still apply to these routes,
# which is the whole point of this hosting mode.
#
# The app uses HashRouter, so client-side deep links live in the URL fragment
# (/api/#/...) and are served by index.html at "/" — deep links never reach the
# server as a distinct path, so no rewrite-to-index.html fallback is needed. A
# genuinely missing S3 key surfaces as an S3 4xx and is mapped to 404, which is
# the correct behavior.
#
# Base path: assets are referenced at absolute /assets/... but the API serves
# under the stage prefix /api, so the UI is built with Vite base = /api/ in this
# mode (VITE_UI_BASE_PATH in modules/web-ui) and asset URLs map through {proxy+}
# to the right S3 keys.

locals {
  # Both the flag and a concrete bucket name are required; a bare flag with no
  # bucket would produce an integration URI pointing at nothing.
  serve_web_ui = var.serve_web_ui && var.web_ui_bucket_name != ""

  web_ui_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.web_ui_bucket_name}"

  # Static security headers on the SPA document and its assets. In this hosting
  # mode there is no CloudFront ResponseHeadersPolicy in front, so they are set
  # here (nosniff / X-Frame-Options matter MOST on the HTML document).
  web_ui_security_headers = {
    "X-Content-Type-Options"    = "'nosniff'"
    "Strict-Transport-Security" = "'max-age=31536000; includeSubDomains'"
    "X-Frame-Options"           = "'DENY'"
    "Referrer-Policy"           = "'strict-origin-when-cross-origin'"
  }
}

# =============================================================================
# Integration credentials: role API Gateway assumes to read the web-app bucket
# =============================================================================
resource "aws_iam_role" "web_ui_proxy" {
  count = local.serve_web_ui ? 1 : 0
  name  = "WebUIProxyRole-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.${data.aws_partition.current.dns_suffix}"
        }
      }
    ]
  })

  tags = var.tags
}

# Read-only on the web-app bucket. The bucket is SSE-S3 (AES256) encrypted — see
# modules/web-ui: aws_s3_bucket_server_side_encryption_configuration.web_app_bucket —
# so S3 decrypts transparently and no kms:Decrypt grant is required here. If that
# bucket is ever switched to the customer-managed key, add kms:Decrypt on
# local.kms_policy_resource_arn.
resource "aws_iam_role_policy" "web_ui_proxy" {
  count = local.serve_web_ui ? 1 : 0
  name  = "WebUIProxyPolicy"
  role  = aws_iam_role.web_ui_proxy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${local.web_ui_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = local.web_ui_bucket_arn
      }
    ]
  })
}

# =============================================================================
# GET / -> s3://<bucket>/index.html
# =============================================================================
resource "aws_api_gateway_method" "web_ui_root" {
  count         = local.serve_web_ui ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.http_api.id
  resource_id   = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "web_ui_root" {
  count                   = local.serve_web_ui ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.http_api.id
  resource_id             = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method             = aws_api_gateway_method.web_ui_root[0].http_method
  type                    = "AWS"
  integration_http_method = "GET"
  credentials             = aws_iam_role.web_ui_proxy[0].arn
  uri                     = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.id}:s3:path/${var.web_ui_bucket_name}/index.html"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_method_response" "web_ui_root_200" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method = aws_api_gateway_method.web_ui_root[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type"              = true
    "method.response.header.X-Content-Type-Options"    = true
    "method.response.header.Strict-Transport-Security" = true
    "method.response.header.X-Frame-Options"           = true
    "method.response.header.Referrer-Policy"           = true
  }
}

resource "aws_api_gateway_method_response" "web_ui_root_404" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method = aws_api_gateway_method.web_ui_root[0].http_method
  status_code = "404"
}

resource "aws_api_gateway_method_response" "web_ui_root_500" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method = aws_api_gateway_method.web_ui_root[0].http_method
  status_code = "500"
}

# Return the S3 object bytes verbatim. With binary_media_types = ["*/*"],
# CONVERT_TO_BINARY makes API Gateway pass the raw payload through for binary
# assets (images, fonts, wasm) instead of base64.
resource "aws_api_gateway_integration_response" "web_ui_root_200" {
  count            = local.serve_web_ui ? 1 : 0
  rest_api_id      = aws_api_gateway_rest_api.http_api.id
  resource_id      = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method      = aws_api_gateway_method.web_ui_root[0].http_method
  status_code      = aws_api_gateway_method_response.web_ui_root_200[0].status_code
  content_handling = "CONVERT_TO_BINARY"

  response_parameters = {
    "method.response.header.Content-Type"              = "integration.response.header.Content-Type"
    "method.response.header.X-Content-Type-Options"    = local.web_ui_security_headers["X-Content-Type-Options"]
    "method.response.header.Strict-Transport-Security" = local.web_ui_security_headers["Strict-Transport-Security"]
    "method.response.header.X-Frame-Options"           = local.web_ui_security_headers["X-Frame-Options"]
    "method.response.header.Referrer-Policy"           = local.web_ui_security_headers["Referrer-Policy"]
  }

  depends_on = [aws_api_gateway_integration.web_ui_root]
}

resource "aws_api_gateway_integration_response" "web_ui_root_404" {
  count             = local.serve_web_ui ? 1 : 0
  rest_api_id       = aws_api_gateway_rest_api.http_api.id
  resource_id       = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method       = aws_api_gateway_method.web_ui_root[0].http_method
  status_code       = aws_api_gateway_method_response.web_ui_root_404[0].status_code
  selection_pattern = "4\\d{2}"

  depends_on = [aws_api_gateway_integration.web_ui_root]
}

resource "aws_api_gateway_integration_response" "web_ui_root_500" {
  count             = local.serve_web_ui ? 1 : 0
  rest_api_id       = aws_api_gateway_rest_api.http_api.id
  resource_id       = aws_api_gateway_rest_api.http_api.root_resource_id
  http_method       = aws_api_gateway_method.web_ui_root[0].http_method
  status_code       = aws_api_gateway_method_response.web_ui_root_500[0].status_code
  selection_pattern = "5\\d{2}"

  depends_on = [aws_api_gateway_integration.web_ui_root]
}

# =============================================================================
# GET /{proxy+} -> s3://<bucket>/{proxy}
# =============================================================================
resource "aws_api_gateway_resource" "web_ui_proxy" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  parent_id   = aws_api_gateway_rest_api.http_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "web_ui_proxy" {
  count         = local.serve_web_ui ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.http_api.id
  resource_id   = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "web_ui_proxy" {
  count                   = local.serve_web_ui ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.http_api.id
  resource_id             = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method             = aws_api_gateway_method.web_ui_proxy[0].http_method
  type                    = "AWS"
  integration_http_method = "GET"
  credentials             = aws_iam_role.web_ui_proxy[0].arn
  uri                     = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.id}:s3:path/${var.web_ui_bucket_name}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_method_response" "web_ui_proxy_200" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method = aws_api_gateway_method.web_ui_proxy[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type"              = true
    "method.response.header.X-Content-Type-Options"    = true
    "method.response.header.Strict-Transport-Security" = true
    "method.response.header.X-Frame-Options"           = true
    "method.response.header.Referrer-Policy"           = true
  }
}

resource "aws_api_gateway_method_response" "web_ui_proxy_404" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method = aws_api_gateway_method.web_ui_proxy[0].http_method
  status_code = "404"
}

resource "aws_api_gateway_method_response" "web_ui_proxy_500" {
  count       = local.serve_web_ui ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method = aws_api_gateway_method.web_ui_proxy[0].http_method
  status_code = "500"
}

resource "aws_api_gateway_integration_response" "web_ui_proxy_200" {
  count            = local.serve_web_ui ? 1 : 0
  rest_api_id      = aws_api_gateway_rest_api.http_api.id
  resource_id      = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method      = aws_api_gateway_method.web_ui_proxy[0].http_method
  status_code      = aws_api_gateway_method_response.web_ui_proxy_200[0].status_code
  content_handling = "CONVERT_TO_BINARY"

  response_parameters = {
    "method.response.header.Content-Type"              = "integration.response.header.Content-Type"
    "method.response.header.X-Content-Type-Options"    = local.web_ui_security_headers["X-Content-Type-Options"]
    "method.response.header.Strict-Transport-Security" = local.web_ui_security_headers["Strict-Transport-Security"]
    "method.response.header.X-Frame-Options"           = local.web_ui_security_headers["X-Frame-Options"]
    "method.response.header.Referrer-Policy"           = local.web_ui_security_headers["Referrer-Policy"]
  }

  depends_on = [aws_api_gateway_integration.web_ui_proxy]
}

# A missing S3 key surfaces as an S3 4xx (403 AccessDenied / 404 NoSuchKey) and
# is mapped to 404. Correct for the SPA: HashRouter keeps client-side routes in
# the fragment, so only genuinely nonexistent asset paths return 404.
resource "aws_api_gateway_integration_response" "web_ui_proxy_404" {
  count             = local.serve_web_ui ? 1 : 0
  rest_api_id       = aws_api_gateway_rest_api.http_api.id
  resource_id       = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method       = aws_api_gateway_method.web_ui_proxy[0].http_method
  status_code       = aws_api_gateway_method_response.web_ui_proxy_404[0].status_code
  selection_pattern = "4\\d{2}"

  depends_on = [aws_api_gateway_integration.web_ui_proxy]
}

resource "aws_api_gateway_integration_response" "web_ui_proxy_500" {
  count             = local.serve_web_ui ? 1 : 0
  rest_api_id       = aws_api_gateway_rest_api.http_api.id
  resource_id       = aws_api_gateway_resource.web_ui_proxy[0].id
  http_method       = aws_api_gateway_method.web_ui_proxy[0].http_method
  status_code       = aws_api_gateway_method_response.web_ui_proxy_500[0].status_code
  selection_pattern = "5\\d{2}"

  depends_on = [aws_api_gateway_integration.web_ui_proxy]
}
