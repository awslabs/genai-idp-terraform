# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API Key for GraphQL API (only created if API key authentication is enabled)
resource "aws_appsync_api_key" "api_key" {
  count       = var.authorization_config == null || try(var.authorization_config.default_authorization.authorization_type, "API_KEY") == "API_KEY" ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  description = "API Key for ${aws_appsync_graphql_api.api.name}"
  expires     = timeadd(timestamp(), "8760h") # 1 year from deployment
}
