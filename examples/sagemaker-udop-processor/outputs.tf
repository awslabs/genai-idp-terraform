# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "input_bucket" {
  description = "S3 bucket for input documents"
  value = {
    name = aws_s3_bucket.input_bucket.id
    arn  = aws_s3_bucket.input_bucket.arn
  }
}

output "output_bucket" {
  description = "S3 bucket for processed output documents"
  value = {
    name = aws_s3_bucket.output_bucket.id
    arn  = aws_s3_bucket.output_bucket.arn
  }
}

output "working_bucket" {
  description = "S3 bucket for working files"
  value = {
    name = aws_s3_bucket.working_bucket.id
    arn  = aws_s3_bucket.working_bucket.arn
  }
}

output "encryption_key" {
  description = "KMS key for encryption"
  value = {
    id  = aws_kms_key.encryption_key.id
    arn = aws_kms_key.encryption_key.arn
  }
}

output "api" {
  description = "GraphQL API details"
  value       = (var.enable_api != null ? var.enable_api : var.api.enabled) ? module.genai_idp_accelerator.api : null
}

output "web_ui" {
  description = "Web UI details"
  value       = var.web_ui.enabled ? module.genai_idp_accelerator.web_ui : null
}

output "web_ui_url" {
  description = "Web UI URL (if enabled)"
  value       = var.web_ui.enabled ? module.genai_idp_accelerator.web_ui.url : null
}

output "user_identity" {
  description = "User identity details"
  value       = module.genai_idp_accelerator.user_identity
}

output "name_prefix" {
  description = "Name prefix used for all resources"
  value       = module.genai_idp_accelerator.name_prefix
}

output "processor_type" {
  description = "Type of document processor used"
  value       = module.genai_idp_accelerator.processor_type
}

output "step_function_arn" {
  description = "ARN of the Step Functions state machine for document processing"
  value       = module.genai_idp_accelerator.processor.state_machine_arn
}

output "queue_processor_arn" {
  description = "ARN of the Lambda function that processes documents from the queue"
  value       = module.genai_idp_accelerator.processor.queue_processor_arn
}

output "queue_sender_arn" {
  description = "ARN of the Lambda function that sends documents to the processing queue"
  value       = module.genai_idp_accelerator.processor.queue_sender_arn
}

output "configuration_table_arn" {
  description = "ARN of the DynamoDB table that stores configuration settings"
  value       = module.genai_idp_accelerator.processing_environment.configuration_table_arn
}

# SageMaker Model Training Outputs
output "model_training" {
  description = "SageMaker model training details"
  value = {
    model_data_uri     = module.sagemaker_model.model_data_uri
    training_job_name  = module.sagemaker_model.training_job_name
    data_bucket_name   = module.sagemaker_model.data_bucket_name
    execution_role_arn = module.sagemaker_model.sagemaker_execution_role_arn
  }
}

# SageMaker Classifier Outputs
output "classifier" {
  description = "SageMaker classifier endpoint details"
  value = {
    endpoint_name = aws_sagemaker_endpoint.udop_endpoint.name
    endpoint_arn  = aws_sagemaker_endpoint.udop_endpoint.arn
    model_name    = aws_sagemaker_model.udop_model.name
    model_arn     = aws_sagemaker_model.udop_model.arn
  }
}

# Training Data Bucket
output "training_data_bucket" {
  description = "S3 bucket containing training data and model artifacts"
  value = {
    name = module.sagemaker_model.data_bucket_name
    arn  = "arn:${data.aws_partition.current.partition}:s3:::${module.sagemaker_model.data_bucket_name}"
  }
}
