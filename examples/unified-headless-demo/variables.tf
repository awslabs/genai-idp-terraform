# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "prefix" {
  type    = string
  default = "idp-headless"
}

variable "config_file_path" {
  type    = string
  default = "../../sources/config_library/unified/lending-package-sample/config.yaml"
}

variable "create_bda_project" {
  type    = bool
  default = true
}

variable "bda_project_arn" {
  type    = string
  default = ""
}

variable "bda_version_name" {
  type    = string
  default = "bda"
}

# Deployment toggles. Headless defaults: API off (DynamoDB-only), no
# web-ui, no chat. Flip these in terraform.tfvars to model other shapes.
variable "enable_api" {
  description = "Deploy the AppSync GraphQL API. false = headless, DynamoDB-only tracking."
  type        = bool
  default     = false
}

variable "enable_chat_with_document" {
  description = "Enable chat-with-document. Requires enable_api = true (it references the API)."
  type        = bool
  default     = false
}

variable "enable_web_ui" {
  description = "Deploy the web UI (CloudFront/S3). Requires enable_api = true."
  type        = bool
  default     = false
}

variable "classification_model_id" {
  type    = string
  default = "us.amazon.nova-2-lite-v1:0"
}

variable "extraction_model_id" {
  type    = string
  default = "us.amazon.nova-2-lite-v1:0"
}

variable "log_level" {
  type    = string
  default = "INFO"
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
