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
    - ocr: OCR module dependencies (Pillow, pypdfium2, textractor, numpy, pandas, etc.)
    - classification: Classification module dependencies
    - extraction: Extraction module dependencies  
    - assessment: Assessment module dependencies
    - evaluation: Evaluation module dependencies (munkres, numpy)
    - rule_validation: Rule validation dependencies (renamed from criteria_validation in IDP v0.5.9)
    - reporting: Reporting module dependencies (pyarrow)
    - appsync: HTTP client dependencies (requests) — name retained upstream after the AppSync removal
    - docs_service: Document service factory dependencies
    - agents: Agent dependencies (strands, bedrock-agentcore)
    - multi_document_discovery: Multi-document discovery dependencies
    - synthesis: Synthesis module dependencies
    - code_intel: Code-intelligence dependencies
    - dev / test: Development and testing dependencies
    - all: All available dependencies

    The list above mirrors `[project.optional-dependencies]` in
    `sources/lib/idp_common_pkg/pyproject.toml` for the vendored IDP version.
    Keep the validation below in sync with it — pip does not fail on an
    unknown extra, it silently installs nothing, so a stale name here
    produces a layer that is missing dependencies at runtime.
    
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
        "assessment", "evaluation", "rule_validation", "reporting",
        "appsync", "docs_service", "agents", "multi_document_discovery",
        "synthesis", "code_intel", "test", "all"
      ], extra)
    ])
    error_message = "Variable idp_common_extras contains invalid extras. Valid options are: core, dev, image, ocr, classification, extraction, assessment, evaluation, rule_validation, reporting, appsync, docs_service, agents, multi_document_discovery, synthesis, code_intel, test, all."
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
          "assessment", "evaluation", "rule_validation", "reporting",
          "appsync", "docs_service", "agents", "multi_document_discovery",
          "synthesis", "code_intel", "test", "all"
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

#
# Build strategy (controls dispatcher in main.tf)
#
# When lambda_local = false (default), this module behaves bit-for-bit as before
# and provisions CodeBuild infrastructure. When lambda_local = true, those
# resources collapse to count = 0 and modules/lambda-layer-local-build is used
# to produce equivalent layer artifacts via Docker on the deploy host. The
# idp_common-specific staging (source copy of sources/lib/idp_common_pkg) is
# handled by the local-build module via local_file resources.
#
variable "lambda_local" {
  description = "When true, build the Lambda layer locally on the deploy host instead of via AWS CodeBuild. See modules/lambda-layer-local-build."
  type        = bool
  default     = false
}

variable "lambda_architecture" {
  description = "Target Lambda architecture (x86_64 | arm64). Sets compatible_architectures on every produced aws_lambda_layer_version regardless of build path."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

variable "container_runtime" {
  description = "Container runtime for local builds (auto|docker|podman|finch). Ignored when lambda_local = false."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "docker", "podman", "finch"], var.container_runtime)
    error_message = "container_runtime must be one of: auto, docker, podman, finch."
  }
}
