# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IDP Common Layer Module
# This module creates a Lambda layer containing the idp_common library

locals {
  # Use the local copy of idp_common_pkg
  idp_common_source_path = "${path.module}/../../sources/lib/idp_common_pkg"

  # Generate requirements.txt content for the idp_common library dependencies only
  idp_common_requirements = {
    "idp-common" = templatefile("${path.module}/templates/requirements.txt.tpl", {
      extras = var.idp_common_extras
    })
  }
}

# Use a custom lambda-layer-codebuild module specifically for idp-common
# The lambda-layer-codebuild-idp module now handles comprehensive change detection
# including all Python files in the idp_common package
module "idp_common_layer" {
  source = "../lambda-layer-codebuild-idp"

  layer_prefix             = var.layer_prefix
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn
  requirements_files       = local.idp_common_requirements
  # Remove local hash calculation - let the module handle change detection
  requirements_hash      = "" # Empty string lets module calculate its own hash
  force_rebuild          = var.force_rebuild
  idp_common_extras      = var.idp_common_extras
  idp_common_source_path = local.idp_common_source_path
  lambda_tracing_mode    = var.lambda_tracing_mode
}
