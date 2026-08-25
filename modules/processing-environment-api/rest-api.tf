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
  # Attach the WAF only when an explicit, non-allow-all IPv4 allow-list is given.
  #
  # Do NOT write this as `var.waf_allowed_ipv4_ranges != ["0.0.0.0/0"]`. Terraform
  # does not type-convert when comparing a `list(string)` against a tuple
  # literal, so that expression is ALWAYS true (verified: `var.v == ["0.0.0.0/0"]`
  # evaluates false for a `list(string)` var holding exactly that value, while
  # `var.v != tolist(["0.0.0.0/0"])` correctly evaluates false). The result was a
  # WAF built on every deployment with `0.0.0.0/0` in its IPSet — which WAFv2
  # rejects outright (`WAFInvalidParameterException ... field: IP_ADDRESS,
  # parameter: 0.0.0.0/0`), so the API WAF path could never apply successfully.
  #
  # The semantic test below avoids the comparison entirely: an empty list means
  # "no allow-list" (and would also produce an invalid empty IPSet), and an
  # allow-list containing 0.0.0.0/0 means "allow all", which is expressed by not
  # attaching a WAF rather than by an IPSet WAFv2 will not accept.
  api_waf_enabled = length(var.waf_allowed_ipv4_ranges) > 0 && !contains(var.waf_allowed_ipv4_ranges, "0.0.0.0/0")

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
# A CORS preflight MUST be unauthenticated: browsers send OPTIONS without the
# Authorization header before each cross-origin POST, so requiring auth here
# would break every request. The MOCK integration returns only static
# CORS/security headers and reaches no backend or data; the POST method on the
# same resource is Cognito-authorized. Mirrors upstream HttpApiOptionsMethod
# (AuthorizationType: NONE).
#tfsec:ignore:aws-api-gateway-no-public-access
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

      # Web UI S3-proxy routes (web-ui-hosting.tf, serve_web_ui = true). These
      # MUST be part of the trigger: a deployment is an immutable snapshot of the
      # API, so adding/changing methods without re-cutting it leaves the stage
      # serving the previous snapshot and the SPA routes never appear (this is
      # the Terraform equivalent of upstream bumping the
      # AWS::ApiGateway::Deployment logical id — see the NB in
      # sources/nested/api-resolvers/template.yaml). Count-safe splats keep the
      # expression valid when the routes are disabled.
      join(",", [for r in aws_api_gateway_resource.web_ui_proxy : r.id]),
      join(",", [for m in aws_api_gateway_method.web_ui_root : m.id]),
      join(",", [for i in aws_api_gateway_integration.web_ui_root : i.id]),
      join(",", [for r in aws_api_gateway_integration_response.web_ui_root_200 : r.id]),
      join(",", [for r in aws_api_gateway_integration_response.web_ui_root_404 : r.id]),
      join(",", [for r in aws_api_gateway_integration_response.web_ui_root_500 : r.id]),
      join(",", [for m in aws_api_gateway_method.web_ui_proxy : m.id]),
      join(",", [for i in aws_api_gateway_integration.web_ui_proxy : i.id]),
      join(",", [for r in aws_api_gateway_integration_response.web_ui_proxy_200 : r.id]),
      join(",", [for r in aws_api_gateway_integration_response.web_ui_proxy_404 : r.id]),
      join(",", [for r in aws_api_gateway_integration_response.web_ui_proxy_500 : r.id]),
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.op_post,
    aws_api_gateway_integration.op_options,
    aws_api_gateway_integration_response.op_options,
    aws_api_gateway_integration.web_ui_root,
    aws_api_gateway_integration_response.web_ui_root_200,
    aws_api_gateway_integration.web_ui_proxy,
    aws_api_gateway_integration_response.web_ui_proxy_200,
  ]
}

# =============================================================================
# Stage access / execution logging (mirrors upstream EnableApiAccessLogs)
# =============================================================================
# Upstream enables these only at LogLevel INFO/DEBUG, because execution logging
# at INFO echoes full request/response payloads (customer document data) into
# CloudWatch. We follow that exactly:
#   * ACCESS logs: request METADATA only, never bodies. These capture the
#     failures that never reach the dispatcher — authorizer 401/403s, WAF
#     blocks, CORS/gateway responses.
#   * EXECUTION logs: pinned to ERROR with data tracing OFF for the same
#     no-payloads reason (deliberately not INFO).
# At WARN/ERROR (the recommended production setting) no logging is configured,
# matching prior behaviour.
locals {
  api_access_logs_enabled = contains(["INFO", "DEBUG"], upper(var.log_level))
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  count             = local.api_access_logs_enabled ? 1 : 0
  name              = "/aws/apigateway/${local.api_name}-access"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

# A REST API stage REJECTS access logging unless the ACCOUNT-level API Gateway
# CloudWatch role is set ("CloudWatch Logs role ARN must be set in account
# settings to enable logging"). This is a per-account, per-region SINGLETON:
# multiple stacks that declare it overwrite each other (last writer wins), which
# is harmless because they all grant the same managed push policy. Mirrors
# upstream's AWS::ApiGateway::Account with the same caveat.
resource "aws_iam_role" "api_gateway_cloudwatch" {
  count = local.api_access_logs_enabled ? 1 : 0
  name  = "${local.api_name}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  count      = local.api_access_logs_enabled ? 1 : 0
  role       = aws_iam_role.api_gateway_cloudwatch[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count               = local.api_access_logs_enabled ? 1 : 0
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch[0].arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}

resource "aws_api_gateway_stage" "api" {
  rest_api_id           = aws_api_gateway_rest_api.http_api.id
  deployment_id         = aws_api_gateway_deployment.http_api.id
  stage_name            = "api"
  xray_tracing_enabled  = var.xray_enabled
  cache_cluster_enabled = false

  # Request metadata only — never bodies. The error/authorizer fields are what
  # diagnose requests that never reach the dispatcher Lambda.
  dynamic "access_log_settings" {
    for_each = local.api_access_logs_enabled ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_access_logs[0].arn
      format = jsonencode({
        requestId         = "$context.requestId"
        ip                = "$context.identity.sourceIp"
        requestTime       = "$context.requestTime"
        httpMethod        = "$context.httpMethod"
        resourcePath      = "$context.resourcePath"
        status            = "$context.status"
        responseLatency   = "$context.responseLatency"
        integrationStatus = "$context.integrationStatus"
        integrationError  = "$context.integration.error"
        errorMessage      = "$context.error.message"
        errorResponseType = "$context.error.responseType"
        authorizerError   = "$context.authorizer.error"
        principalId       = "$context.authorizer.principalId"
        wafStatus         = "$context.wafResponseCode"
        userAgent         = "$context.identity.userAgent"
      })
    }
  }

  tags = var.tags

  depends_on = [aws_api_gateway_account.this]
}

# Execution logging at ERROR only, data tracing off (no payloads). Captures the
# gateway-side failures access logs cannot diagnose (integration mapping errors,
# MOCK/CORS template failures).
resource "aws_api_gateway_method_settings" "api" {
  count       = local.api_access_logs_enabled ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.http_api.id
  stage_name  = aws_api_gateway_stage.api.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "ERROR"
    data_trace_enabled = false
    metrics_enabled    = true
  }
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
