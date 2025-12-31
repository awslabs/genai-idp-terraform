# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Process Changes Sub-module Variables
# This module creates the Lambda function and GraphQL resolver for document editing and reprocessing functionality

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "appsync_api_id" {
  description = "AppSync API ID"
  type        = string
}

variable "appsync_lambda_role_arn" {
  description = "AppSync Lambda service role ARN"
  type        = string
}

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  type        = string
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tracking_table_name" {
  description = "Name of the DynamoDB tracking table"
  type        = string
}

variable "tracking_table_arn" {
  description = "ARN of the DynamoDB tracking table"
  type        = string
}

variable "queue_url" {
  description = "URL of the SQS queue for document processing"
  type        = string
}

variable "queue_arn" {
  description = "ARN of the SQS queue for document processing"
  type        = string
}

variable "data_retention_days" {
  description = "Data retention period in days"
  type        = number
  default     = 365
}

variable "working_bucket_arn" {
  description = "ARN of the working S3 bucket"
  type        = string
}

variable "input_bucket_arn" {
  description = "ARN of the input S3 bucket"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the output S3 bucket"
  type        = string
}

variable "appsync_graphql_url" {
  description = "AppSync GraphQL API URL"
  type        = string
}

variable "encryption_key_arn" {
  description = "ARN of the KMS encryption key"
  type        = string
}

variable "vpc_subnet_ids" {
  description = "List of VPC subnet IDs for Lambda function (optional)"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs for Lambda function (optional)"
  type        = list(string)
  default     = []
}

variable "lambda_tracing_mode" {
  description = "Lambda tracing mode"
  type        = string
  default     = "Active"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}