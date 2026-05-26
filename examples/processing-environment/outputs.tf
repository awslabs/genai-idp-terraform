# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "input_bucket_name" {
  description = "The name of the input bucket"
  value       = aws_s3_bucket.input_bucket.bucket
}

output "output_bucket_name" {
  description = "The name of the output bucket"
  value       = aws_s3_bucket.output_bucket.bucket
}

output "tracking_table_name" {
  description = "The name of the tracking table"
  value       = module.processing_environment.tracking_table_name
}

output "configuration_table_name" {
  description = "The name of the configuration table"
  value       = module.processing_environment.configuration_table_name
}

output "concurrency_table_name" {
  description = "The name of the concurrency table"
  value       = module.processing_environment.concurrency_table_name
}

output "document_queue_url" {
  description = "The URL of the document queue"
  value       = module.processing_environment.document_queue_url
}

output "encryption_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = aws_kms_key.encryption_key.key_id
}

output "encryption_key_alias" {
  description = "The alias of the KMS key used for encryption"
  value       = aws_kms_alias.encryption_key_alias.name
}

output "idp_common_layer_arn" {
  description = "The ARN of the IDP common Lambda layer"
  value       = module.idp_common_layer.layer_arn
}

output "lambda_functions" {
  description = "Information about the Lambda functions created"
  value = {
    queue_sender = {
      function_name = module.processing_environment.queue_sender_function_name
      function_arn  = module.processing_environment.queue_sender_function_arn
    }
    workflow_tracker = {
      function_name = module.processing_environment.workflow_tracker_function_name
      function_arn  = module.processing_environment.workflow_tracker_function_arn
    }
    lookup_function = {
      function_name = module.processing_environment.lookup_function_name
      function_arn  = module.processing_environment.lookup_function_arn
    }
  }
}

output "evaluation_baseline_bucket_arn" {
  description = "ARN of the evaluation baseline bucket (when enable_evaluation = true). Pass this to a processor module's `evaluation_baseline_bucket_arn` to wire up the per-pattern evaluation Lambda."
  value       = var.enable_evaluation ? aws_s3_bucket.evaluation_baseline_bucket[0].arn : null
}

output "reporting_bucket_arn" {
  description = "ARN of the reporting bucket (when enable_reporting = true). Pass this to a processor module's reporting wiring."
  value       = var.enable_reporting ? aws_s3_bucket.reporting_bucket[0].arn : null
}
