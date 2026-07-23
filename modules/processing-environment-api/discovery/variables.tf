# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "input_bucket_arn" {
  description = "ARN of the S3 bucket for discovery document uploads"
  type        = string
}

variable "discovery_bucket_arn" {
  description = "ARN of the dedicated discovery S3 bucket"
  type        = string
  default     = null
}

variable "data_retention_days" {
  description = "Number of days to retain discovery documents"
  type        = number
  default     = 365
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB configuration table"
  type        = string
}

variable "appsync_api_url" {
  description = "URL of the AppSync GraphQL API for status updates"
  type        = string
  default     = null
}

variable "appsync_api_id" {
  description = "ID of the AppSync GraphQL API"
  type        = string
}

variable "appsync_lambda_role_arn" {
  description = "ARN of the AppSync Lambda service role"
  type        = string
}

variable "appsync_dynamodb_role_arn" {
  description = "ARN of the AppSync DynamoDB service role"
  type        = string
}

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  type        = string
}

variable "base_layer_arn" {
  description = "ARN of the IDP base Lambda layer (used by the multi-doc Prepare Lambda)"
  type        = string
}

variable "appsync_api_arn" {
  description = "ARN of the AppSync GraphQL API (for multi-doc Lambda IAM permissions)"
  type        = string
}

variable "lambda_layers_bucket_arn" {
  description = "ARN of the assets/lambda-layers S3 bucket used to stage CodeBuild source for the multi-doc Docker image build"
  type        = string
}

variable "test_set_bucket_name" {
  description = "Name of the test-set S3 bucket read by multi-doc discovery. Empty string when test sets are not deployed."
  type        = string
  default     = ""
}

variable "bedrock_hub_role_arn" {
  description = "Optional IAM role ARN in a centralized hub account to assume for Bedrock invocations in multi-doc discovery Lambdas"
  type        = string
  default     = ""
}

variable "bedrock_hub_role_external_id" {
  description = "Optional ExternalId for sts:AssumeRole into the Bedrock hub-account role"
  type        = string
  default     = ""
}

variable "bedrock_hub_role_session_name" {
  description = "Optional session name for sts:AssumeRole into the Bedrock hub-account role"
  type        = string
  default     = ""
}

variable "force_rebuild_multi_doc_image" {
  description = "Force a rebuild of the multi-doc discovery Docker image regardless of source changes"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "List of subnet IDs for Lambda functions"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for Lambda functions"
  type        = list(string)
  default     = []
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "s3_endpoint_url" {
  description = "Optional S3 endpoint URL (VPC interface endpoint) for the discovery upload presigner. When set, presigned URLs target the VPCE via virtual-host addressing. Null (default) uses the global regional S3 endpoint."
  type        = string
  default     = null
}

variable "lambda_architecture" {
  description = "Target Lambda architecture (x86_64 | arm64). Must match the architecture the idp_common layers were built for; mismatches break native deps (e.g. pydantic_core)."
  type        = string
  default     = "arm64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}
