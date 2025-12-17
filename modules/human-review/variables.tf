# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "user_pool_id" {
  description = "ID of the Cognito User Pool"
  type        = string
}



variable "output_bucket_arn" {
  description = "ARN of the S3 bucket for output storage"
  type        = string
}

variable "private_workforce_arn" {
  description = "ARN of the existing SageMaker private workforce"
  type        = string
}

variable "workteam_name" {
  description = "Name of the existing SageMaker workteam"
  type        = string
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
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

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  type        = string
}

variable "stack_name" {
  description = "Name of the CloudFormation stack"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
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

# Pattern-2 HITL Variables
variable "enable_pattern2_hitl" {
  description = "Enable HITL support for Pattern-2 workflows"
  type        = bool
  default     = false
}

variable "hitl_confidence_threshold" {
  description = "Confidence threshold below which HITL review is triggered (0-100)"
  type        = number
  default     = 80

  validation {
    condition     = var.hitl_confidence_threshold >= 0 && var.hitl_confidence_threshold <= 100
    error_message = "hitl_confidence_threshold must be between 0 and 100."
  }
}

variable "tracking_table_name" {
  description = "Name of the DynamoDB tracking table for HITL tokens"
  type        = string
  default     = ""
}

variable "tracking_table_arn" {
  description = "ARN of the DynamoDB tracking table for HITL tokens"
  type        = string
  default     = ""
}

variable "working_bucket_name" {
  description = "Name of the S3 working bucket for document processing"
  type        = string
  default     = ""
}

variable "working_bucket_arn" {
  description = "ARN of the S3 working bucket for document processing"
  type        = string
  default     = ""
}

variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine for Pattern-2 workflow"
  type        = string
  default     = ""
}
