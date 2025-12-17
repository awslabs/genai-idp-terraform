# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "save_reporting_data_function_arn" {
  description = "ARN of the save reporting data Lambda function"
  value       = aws_lambda_function.save_reporting_data.arn
}

output "save_reporting_data_function_name" {
  description = "Name of the save reporting data Lambda function"
  value       = aws_lambda_function.save_reporting_data.function_name
}

output "document_evaluations_table_name" {
  description = "Name of the document evaluations Glue table"
  value       = aws_glue_catalog_table.document_evaluations_table.name
}

output "section_evaluations_table_name" {
  description = "Name of the section evaluations Glue table"
  value       = aws_glue_catalog_table.section_evaluations_table.name
}

output "attribute_evaluations_table_name" {
  description = "Name of the attribute evaluations Glue table"
  value       = aws_glue_catalog_table.attribute_evaluations_table.name
}

output "metering_table_name" {
  description = "Name of the metering Glue table"
  value       = aws_glue_catalog_table.metering_table.name
}

output "document_sections_crawler_name" {
  description = "Name of the document sections Glue crawler"
  value       = aws_glue_crawler.document_sections_crawler.name
}

output "document_sections_crawler_arn" {
  description = "ARN of the document sections Glue crawler"
  value       = aws_glue_crawler.document_sections_crawler.arn
}
