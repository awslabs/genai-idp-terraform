# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
locals {
  # Mutation resolver request template — passes identity through to the
  # lightweight resolver Lambda so it can record/verify session ownership.
  # Mirrors upstream SendChatDocumentMessageResolver (nested appsync template).
  send_chat_request_template = <<-VTL
    {
      "version": "2017-02-28",
      "operation": "Invoke",
      "payload": {
        "arguments": $util.toJson($context.arguments),
        "identity": {
          "username": $util.toJson($context.identity.username),
          "sub": $util.toJson($context.identity.sub),
          "sourceIp": $util.toJson($context.identity.sourceIp),
          "userArn": $util.toJson($context.identity.userArn),
          "claims": $util.toJson($context.identity.claims)
        }
      }
    }
  VTL

  send_chat_response_template = <<-VTL
    #if($ctx.error)
      $util.error($ctx.error.message, $ctx.error.type)
    #end
    $util.toJson($ctx.result)
  VTL

  # Subscription fan-out resolver (NONE data source) — filters by sessionId so
  # one user cannot eavesdrop on another user's chat session. Mirrors upstream
  # OnChatDocumentMessageUpdateResolver.
  on_chat_request_template = <<-VTL
    {
      "version": "2018-05-29",
      "payload": {}
    }
  VTL

  on_chat_response_template = <<-VTL
    #if($context.arguments.sessionId && $context.source.sessionId)
      #if($context.arguments.sessionId == $context.source.sessionId)
        $util.toJson($context.source)
      #else
        #set($result = $util.appendError("Session ID does not match", "Unauthorized"))
        $util.toJson(null)
      #end
    #else
      $util.toJson($context.source)
    #end
  VTL

  chat_resolvers = {
    sendChatDocumentMessage = {
      type              = "Mutation"
      field             = "sendChatDocumentMessage"
      data_source       = aws_appsync_datasource.send_chat_document_message.name
      request_template  = local.send_chat_request_template
      response_template = local.send_chat_response_template
    }
    onChatDocumentMessageUpdate = {
      type              = "Subscription"
      field             = "onChatDocumentMessageUpdate"
      data_source       = aws_appsync_datasource.chat_document_none.name
      request_template  = local.on_chat_request_template
      response_template = local.on_chat_response_template
    }
  }
}

output "contract" {
  description = <<-EOT
    Feature-plugin contract consumed by `processing-environment-api` via its
    `enabled_feature_contracts` input (mirrors the CDK `api.enable(feature)`
    mechanism). The Chat-with-Document submodule owns its Lambdas, execution
    roles, session table, and AppSync data sources, so the contract contributes
    only the two resolvers (the async `sendChatDocumentMessage` mutation and the
    `onChatDocumentMessageUpdate` subscription fan-out). `iam_statements` and
    `environment` are empty because the submodule is fully self-contained.
  EOT
  value = {
    enabled          = true
    resolvers        = local.chat_resolvers
    iam_statements   = []
    environment      = {}
    schema_additions = null
  }
}

output "effective_chat_config" {
  description = <<-EOT
    The resolved chat configuration: the top-level
    `chat:` block when present, otherwise the `summarization.*` fallback, with
    the model defaulting to `us.anthropic.claude-opus-4-7:1m` when unspecified.
    `source` reports which block the values came from ("chat" or "summarization").
  EOT
  value       = local.effective_chat_config
}

output "chat_processor_function_arn" {
  description = "ARN of the long-running Chat-with-Document processor Lambda."
  value       = aws_lambda_function.chat_processor.arn
}

output "chat_resolver_function_arn" {
  description = "ARN of the lightweight sendChatDocumentMessage resolver Lambda."
  value       = aws_lambda_function.chat_resolver.arn
}

output "chat_document_sessions_table_name" {
  description = "Name of the Chat-with-Document session-ownership DynamoDB table."
  value       = aws_dynamodb_table.chat_document_sessions.name
}
