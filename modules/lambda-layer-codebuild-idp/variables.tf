# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

variable "layer_prefix" {
  description = "Prefix for layer names"
  type        = string
  validation {
    condition     = length(var.layer_prefix) > 0 && length(var.layer_prefix) <= 50
    error_message = "Variable layer_prefix must be between 1 and 50 characters."
  }
}

variable "requirements_files" {
  description = "Map of requirements files content for different layer types"
  type        = map(string)
  validation {
    condition     = length(var.requirements_files) > 0
    error_message = "Variable requirements_files must contain at least one requirements file."
  }
}

variable "requirements_hash" {
  description = "Hash of requirements to trigger rebuilds. If empty, will be calculated from requirements_files."
  type        = string
  default     = ""
}

variable "force_rebuild" {
  description = "Force rebuild of layers regardless of content changes"
  type        = bool
  default     = false
}

variable "idp_common_source_path" {
  description = "Path to the idp_common source code directory"
  type        = string
  default     = ""
}

variable "idp_common_extras" {
  description = <<-EOT
    List of extras to install for idp_common package. Available extras:
    - core: Base functionality only (minimal dependencies)
    - image: Image handling dependencies (Pillow)
    - ocr: OCR module dependencies (Pillow, PyMuPDF, textractor, numpy, pandas, etc.)
    - classification: Classification module dependencies
    - extraction: Extraction module dependencies  
    - assessment: Assessment module dependencies
    - evaluation: Evaluation module dependencies (munkres, numpy)
    - criteria_validation: Criteria validation dependencies (s3fs)
    - reporting: Reporting module dependencies (pyarrow)
    - appsync: AppSync module dependencies (requests)
    - docs_service: Document service factory dependencies (requests for appsync support)
    - test: Testing dependencies
    - all: All available dependencies
    
    Example function-specific combinations:
    - OCR functions: ["ocr", "docs_service"]
    - Classification functions: ["classification", "docs_service"]
    - Assessment functions: ["assessment", "docs_service"]
    - Evaluation functions: ["evaluation"]
    - Reporting functions: ["reporting"]
    - Basic processing: ["core"] or []
  EOT
  type        = list(string)
  default     = ["core"]

  validation {
    condition = alltrue([
      for extra in var.idp_common_extras : contains([
        "core", "dev", "image", "ocr", "classification", "extraction",
        "assessment", "evaluation", "criteria_validation", "reporting",
        "appsync", "docs_service", "agents", "analytics", "code_intel", "test", "all"
      ], extra)
    ])
    error_message = "Variable idp_common_extras contains invalid extras. Valid options are: core, dev, image, ocr, classification, extraction, assessment, evaluation, criteria_validation, reporting, appsync, docs_service, agents, analytics, code_intel, test, all."
  }
}



variable "function_layer_config" {
  description = <<-EOT
    Optional configuration for creating function-specific layers.
    Map of function names to their required idp_common extras.
    If provided, creates separate optimized layers for each function type.
    
    Example:
    {
      "ocr-function" = ["ocr", "docs_service"]
      "classification-function" = ["classification", "docs_service"] 
      "assessment-function" = ["assessment", "docs_service"]
      "evaluation-function" = ["evaluation"]
      "basic-function" = ["core"]
    }
    
    If not provided, creates a single layer with the extras specified in idp_common_extras.
  EOT
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for function_name, extras in var.function_layer_config : alltrue([
        for extra in extras : contains([
          "core", "dev", "image", "ocr", "classification", "extraction",
          "assessment", "evaluation", "criteria_validation", "reporting",
          "appsync", "docs_service", "test", "all"
        ], extra)
      ])
    ])
    error_message = "Variable function_layer_config contains invalid extras in one or more function configurations."
  }
}

variable "lambda_layers_bucket_arn" {
  description = "ARN of the S3 bucket for storing Lambda layers. This is required and should be provided by the assets-bucket module."
  type        = string

  validation {
    condition     = var.lambda_layers_bucket_arn != ""
    error_message = "lambda_layers_bucket_arn is required and cannot be empty."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
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
