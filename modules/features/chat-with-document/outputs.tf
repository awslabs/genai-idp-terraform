# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# NOTE (IDP v0.6.4): the AppSync VTL request/response templates and the
# `chat_resolvers` map that used to live here are deleted along with AppSync.
# The REST dispatcher builds the AppSync-shaped event (including the identity
# block the resolver reads) itself in http_api_dispatcher/index.py, so no
# mapping templates are needed. Transport wiring is now the `field_functions`
# map in the contract output below.

output "contract" {
  description = <<-EOT
    Feature-plugin contract consumed by `processing-environment-api` via its
    `enabled_feature_contracts` input (mirrors the CDK `api.enable(feature)`
    mechanism). The Chat-with-Document submodule owns its Lambdas, execution
    roles, and session table, so the contract contributes only transport wiring.
    `iam_statements` and `environment` are empty because the submodule is fully
    self-contained.

    IDP v0.6.4: `resolvers` (AppSync) is replaced by `field_functions` — the
    field -> Lambda ARN map the REST dispatcher routes on. Only
    `sendChatDocumentMessage` appears. The `onChatDocumentMessageUpdate`
    subscription is gone: API Gateway REST has no GraphQL subscriptions, and
    upstream replaced that fan-out with the streaming Lambda Function URL plus
    polling.
  EOT
  value = {
    enabled          = true
    field_functions  = { sendChatDocumentMessage = aws_lambda_function.chat_resolver.arn }
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
