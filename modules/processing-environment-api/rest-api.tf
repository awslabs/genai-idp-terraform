# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API Gateway REST API transport (replaces AWS AppSync).
#
# Faithfully mirrors sources/nested/api-resolvers/template.yaml:
#   HttpApi (AWS::ApiGateway::RestApi), HttpApiAuthorizer, HttpApiOpResource,
#   HttpApiFieldResource, HttpApiMethod (POST AWS_PROXY -> dispatcher),
#   HttpApiOptionsMethod (MOCK CORS preflight, CONVERT_TO_TEXT),
#   HttpApiGatewayResponse4xx/5xx, HttpApiDeployment*/HttpApiStage (stage "api"),
#   HttpApiDispatcherPermission, and the optional REGIONAL WAFv2 stack
#   (ApiWafIPv4Set / ApiWafWebACL / ApiWafAssociation).
#
# REST (v1), not HTTP API (v2): only REST supports a PRIVATE endpoint type and a
# WAFv2 WebACL on the stage — both required for regulated/GovCloud deployments.

locals {
  # Cognito user pool id backing the authorizer. The API module is only
  # meaningfully used with Cognito auth; if a non-Cognito auth type is
  # configured, the authorizer/method below are guarded so plan still succeeds.
  cognito_user_pool_id = local.has_cognito_auth ? var.authorization_config.default_authorization.user_pool_config.user_pool_id : null

  # PRIVATE endpoint (VPC-only) vs REGIONAL (public, Cognito-authorized).
  is_private_api = var.visibility == "PRIVATE"

  # WAF is enabled unless the IP allow-list is the allow-all default.
  api_waf_enabled = var.waf_allowed_ipv4_ranges != ["0.0.0.0/0"]

  # CORS + security headers reused by the OPTIONS preflight and gateway
  # responses (mirrors the upstream static values).
  api_cors_headers = {
    "Access-Control-Allow-Origin"  = "'*'"
    "Access-Control-Allow-Headers" = "'authorization,content-type'"
    "Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "X-Content-Type-Options"       = "'nosniff'"
    "Strict-Transport-Security"    = "'max-age=31536000; includeSubDomains'"
    "X-Frame-Options"              = "'DENY'"
    "Referrer-Policy"              = "'strict-origin-when-cross-origin'"
  }
}

resource "aws_api_gateway_rest_api" "http_api" {
  name        = "${local.api_name}-api"
  description = "REST API transport for ${local.api_name} (replaces AppSync)"

  # Treat all media as binary so byte payloads pass through intact. The JSON
  # /op POST transport is unaffected (the dispatcher base64-decodes request
  # bodies and returns a JSON string).
  binary_media_types = ["*/*"]

  endpoint_configuration {
    types            = local.is_private_api ? ["PRIVATE"] : ["REGIONAL"]
    vpc_endpoint_ids = local.is_private_api && var.api_gateway_vpc_endpoint_id != "" ? [var.api_gateway_vpc_endpoint_id] : null
  }

  # When PRIVATE, restrict invocation to the supplied VPC endpoint; when
  # regional, no resource policy (auth is enforced by the authorizer).
  policy = local.is_private_api ? jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "execute-api:Invoke"
      Resource  = "execute-api:/*"
      Condition = {
        StringEquals = { "aws:SourceVpce" = var.api_gateway_vpc_endpoint_id }
      }
    }]
  }) : null

  tags = var.tags
}

# Cognito User Pools authorizer (authN only; RBAC is re-enforced in-resolver).
resource "aws_api_gateway_authorizer" "cognito" {
  count           = local.has_cognito_auth ? 1 : 0
  name            = "CognitoUserPoolsAuthorizer"
  rest_api_id     = aws_api_gateway_rest_api.http_api.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = ["arn:${data.aws_partition.current.partition}:cognito-idp:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:userpool/${local.cognito_user_pool_id}"]
}

# /op and /op/{field}
resource "aws_api_gateway_resource" "op" {
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  parent_id   = aws_api_gateway_rest_api.http_api.root_resource_id
  path_part   = "op"
}

resource "aws_api_gateway_resource" "op_field" {
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  parent_id   = aws_api_gateway_resource.op.id
  path_part   = "{field}"
}

# POST /op/{field} — Cognito-authorized, AWS_PROXY to the dispatcher.
resource "aws_api_gateway_method" "op_post" {
  rest_api_id   = aws_api_gateway_rest_api.http_api.id
  resource_id   = aws_api_gateway_resource.op_field.id
  http_method   = "POST"
  authorization = local.has_cognito_auth ? "COGNITO_USER_POOLS" : "AWS_IAM"
  authorizer_id = local.has_cognito_auth ? aws_api_gateway_authorizer.cognito[0].id : null

  request_parameters = {
    "method.request.path.field" = true
  }
}

resource "aws_api_gateway_integration" "op_post" {
  rest_api_id             = aws_api_gateway_rest_api.http_api.id
  resource_id             = aws_api_gateway_resource.op_field.id
  http_method             = aws_api_gateway_method.op_post.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${aws_lambda_function.http_api_dispatcher.arn}/invocations"
}

# Unauthenticated CORS preflight. MOCK integration answering 200 with CORS +
# security headers. CONVERT_TO_TEXT is required because BinaryMediaTypes is */*.
resource "aws_api_gateway_method" "op_options" {
  rest_api_id   = aws_api_gateway_rest_api.http_api.id
  resource_id   = aws_api_gateway_resource.op_field.id
  http_method   = "OPTIONS"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.field" = true
  }
}

resource "aws_api_gateway_integration" "op_options" {
  rest_api_id      = aws_api_gateway_rest_api.http_api.id
  resource_id      = aws_api_gateway_resource.op_field.id
  http_method      = aws_api_gateway_method.op_options.http_method
  type             = "MOCK"
  content_handling = "CONVERT_TO_TEXT"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "op_options" {
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  resource_id = aws_api_gateway_resource.op_field.id
  http_method = aws_api_gateway_method.op_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.X-Content-Type-Options"       = true
    "method.response.header.Strict-Transport-Security"    = true
    "method.response.header.X-Frame-Options"              = true
    "method.response.header.Referrer-Policy"              = true
  }
}

resource "aws_api_gateway_integration_response" "op_options" {
  rest_api_id      = aws_api_gateway_rest_api.http_api.id
  resource_id      = aws_api_gateway_resource.op_field.id
  http_method      = aws_api_gateway_method.op_options.http_method
  status_code      = aws_api_gateway_method_response.op_options.status_code
  content_handling = "CONVERT_TO_TEXT"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.api_cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.api_cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = local.api_cors_headers["Access-Control-Allow-Methods"]
    "method.response.header.X-Content-Type-Options"       = local.api_cors_headers["X-Content-Type-Options"]
    "method.response.header.Strict-Transport-Security"    = local.api_cors_headers["Strict-Transport-Security"]
    "method.response.header.X-Frame-Options"              = local.api_cors_headers["X-Frame-Options"]
    "method.response.header.Referrer-Policy"              = local.api_cors_headers["Referrer-Policy"]
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.op_options]
}

# CORS + security headers on gateway-level errors (most importantly the Cognito
# authorizer's 401/403), so the browser sees the real status, not a CORS error.
resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.http_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = local.api_cors_headers["Access-Control-Allow-Origin"]
    "gatewayresponse.header.Access-Control-Allow-Headers" = local.api_cors_headers["Access-Control-Allow-Headers"]
    "gatewayresponse.header.Access-Control-Allow-Methods" = local.api_cors_headers["Access-Control-Allow-Methods"]
    "gatewayresponse.header.X-Content-Type-Options"       = local.api_cors_headers["X-Content-Type-Options"]
    "gatewayresponse.header.Strict-Transport-Security"    = local.api_cors_headers["Strict-Transport-Security"]
    "gatewayresponse.header.X-Frame-Options"              = local.api_cors_headers["X-Frame-Options"]
    "gatewayresponse.header.Referrer-Policy"              = local.api_cors_headers["Referrer-Policy"]
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.http_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = local.api_cors_headers["Access-Control-Allow-Origin"]
    "gatewayresponse.header.Access-Control-Allow-Headers" = local.api_cors_headers["Access-Control-Allow-Headers"]
    "gatewayresponse.header.Access-Control-Allow-Methods" = local.api_cors_headers["Access-Control-Allow-Methods"]
    "gatewayresponse.header.X-Content-Type-Options"       = local.api_cors_headers["X-Content-Type-Options"]
    "gatewayresponse.header.Strict-Transport-Security"    = local.api_cors_headers["Strict-Transport-Security"]
    "gatewayresponse.header.X-Frame-Options"              = local.api_cors_headers["X-Frame-Options"]
    "gatewayresponse.header.Referrer-Policy"              = local.api_cors_headers["Referrer-Policy"]
  }
}

# Deployment + stage "api". The redeployment trigger re-snapshots the API
# whenever methods/integrations/resources/gateway-responses change (a bare
# property mutation does not otherwise reach the stage).
resource "aws_api_gateway_deployment" "http_api" {
  rest_api_id = aws_api_gateway_rest_api.http_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.op.id,
      aws_api_gateway_resource.op_field.id,
      aws_api_gateway_method.op_post.id,
      aws_api_gateway_integration.op_post.id,
      aws_api_gateway_method.op_options.id,
      aws_api_gateway_integration.op_options.id,
      aws_api_gateway_integration_response.op_options.id,
      aws_api_gateway_gateway_response.default_4xx.id,
      aws_api_gateway_gateway_response.default_5xx.id,
      join(",", [for c in aws_api_gateway_authorizer.cognito : c.id]),
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.op_post,
    aws_api_gateway_integration.op_options,
    aws_api_gateway_integration_response.op_options,
  ]
}

resource "aws_api_gateway_stage" "api" {
  rest_api_id           = aws_api_gateway_rest_api.http_api.id
  deployment_id         = aws_api_gateway_deployment.http_api.id
  stage_name            = "api"
  xray_tracing_enabled  = var.xray_enabled
  cache_cluster_enabled = false

  tags = var.tags
}

# API Gateway invokes the dispatcher on POST /op/*.
resource "aws_lambda_permission" "http_api_dispatcher" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.http_api_dispatcher.function_name
  principal     = "apigateway.${data.aws_partition.current.dns_suffix}"
  source_arn    = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.http_api.id}/*/POST/op/*"
}

# =============================================================================
# Optional REGIONAL WAFv2 fronting the stage (gated on waf_allowed_ipv4_ranges)
# =============================================================================
resource "aws_wafv2_ip_set" "api_allow_ipv4" {
  count              = local.api_waf_enabled ? 1 : 0
  name               = "${local.api_name}-api-allow-ipv4"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.waf_allowed_ipv4_ranges
  tags               = var.tags
}

resource "aws_wafv2_web_acl" "api" {
  count = local.api_waf_enabled ? 1 : 0
  name  = "${local.api_name}-api-acl"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "AllowListedIPv4"
    priority = 0

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.api_allow_ipv4[0].arn
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowListedIPv4"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.api_name}-api-acl"
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "api" {
  count        = local.api_waf_enabled ? 1 : 0
  resource_arn = aws_api_gateway_stage.api.arn
  web_acl_arn  = aws_wafv2_web_acl.api[0].arn
}
