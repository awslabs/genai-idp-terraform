# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "concurrency_table_name" {
  description = "The name of the concurrency table"
  value       = element(split("/", module.concurrency_table.table_arn), 1)
}

output "concurrency_table_arn" {
  description = "The ARN of the concurrency table"
  value       = module.concurrency_table.table_arn
}

output "configuration_table_name" {
  description = "The name of the configuration table"
  value       = element(split("/", module.configuration_table.table_arn), 1)
}

output "configuration_table_arn" {
  description = "The ARN of the configuration table"
  value       = module.configuration_table.table_arn
}

output "tracking_table_name" {
  description = "The name of the tracking table"
  value       = element(split("/", module.tracking_table.table_arn), 1)
}

output "tracking_table_arn" {
  description = "The ARN of the tracking table"
  value       = module.tracking_table.table_arn
}
