# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "installed_features_table_name" {
  description = "Name of the InstalledFeatures registry table."
  value       = aws_dynamodb_table.installed_features.name
}

output "installed_features_table_arn" {
  description = "ARN of the InstalledFeatures registry table."
  value       = aws_dynamodb_table.installed_features.arn
}

output "function_arns" {
  description = "Map of feature-platform Lambda function name -> ARN."
  value       = { for k, f in aws_lambda_function.feature : k => f.arn }
}

output "field_functions" {
  description = <<-EOT
    API field name -> backing Lambda ARN, for the REST dispatcher's
    field-function map (IDP v0.6.4).

    Replaces the AppSync data sources and per-field resolvers this module used to
    create. The API module merges this into `local.field_function_map` in
    dispatcher.tf; the dispatcher then invokes the mapped Lambda with an
    AppSync-shaped event, so the Lambdas themselves are unchanged.

    Keys are the field names exactly as the client sends them to
    `POST /op/{field}`. They must NOT be pre-collapsed onto a canonical key:
    the dispatcher's FIELD_ALIASES table has no entries for feature-platform
    fields, so every field resolves 1:1. Several fields intentionally share one
    ARN (e.g. registerFeature / unregisterFeature both hit register_feature),
    which is fine — the dispatcher's invoke grant de-duplicates by ARN.
  EOT
  value       = { for field, r in local.resolvers : field => aws_lambda_function.feature[r.fn].arn }
}
