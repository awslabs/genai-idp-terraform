# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API Key for GraphQL API. Only created when the caller explicitly opts
# into API_KEY auth on an additional_authorization_mode. The default_authorization
# is no longer allowed to be API_KEY (see variables.tf validation), so an
# unconfigured module will not provision an API key.
resource "aws_appsync_api_key" "api_key" {
  count = var.authorization_config != null && (
    try(var.authorization_config.default_authorization.authorization_type, "") == "API_KEY" ||
    length([
      for m in coalesce(try(var.authorization_config.additional_authorization_modes, null), []) : m
      if m.authorization_type == "API_KEY"
    ]) > 0
  ) ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  description = "API Key for ${aws_appsync_graphql_api.api.name}"
  expires     = timeadd(timestamp(), "8760h") # 1 year from deployment
}
