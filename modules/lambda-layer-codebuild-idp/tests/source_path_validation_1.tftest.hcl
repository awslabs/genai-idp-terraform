# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the input contracts on this module's naming and
# path variables.
#
# `layer_prefix` composes an IAM role name, a CodeBuild project name, a log
# group name, an S3 key and a Lambda layer name, and is also embedded in build
# paths. `idp_common_source_path` locates a source tree on the build host. Both
# are therefore restricted to a documented character set (see variables.tf and
# README.md), and both restrictions are pinned here in both directions:
#
#   * reject: values outside the documented set fail validation, asserted with
#     `expect_failures` on the variable itself.
#   * accept: the values real callers pass — including a relative path with
#     parent traversal, which modules/idp-common-layer relies on — continue to
#     plan cleanly, so the contract cannot be tightened by accident.
#
# Offline harness: the aws provider is mocked, and every run is `command = plan`,
# so the suite needs no AWS credentials and creates nothing.

#
# Split note: this suite is deliberately kept in per-variable files rather than
# one combined file. Every run is a full `command = plan` of the module, and
# `terraform test` holds all of a file's runs in one process, so a single file
# with every case OOM-killed the shared CI runner (exit 137). `make unit-test`
# runs one process per test file, so keeping these separate bounds peak memory.
# Do not merge them back into one file.
# Every provider the module requires is mocked, not just aws. These are
# variable-validation tests: validation fires before any provider work, so no
# real plugin is needed. Mocking only aws left five real plugin processes
# (random, local, null, archive, time) to start per run block, and on the shared
# CI runner the handshake began timing out around the eighth run
# ("timeout while waiting for plugin to start"). Mock all six, start none.
mock_provider "aws" {}
mock_provider "random" {}
mock_provider "local" {}
mock_provider "null" {}
mock_provider "archive" {}
mock_provider "time" {}

variables {
  # Minimum required inputs, held constant so each run varies only the variable
  # under test. The bucket ARN is split on ":::" by the module, so it must be a
  # well-formed S3 ARN.
  requirements_files = {
    "idp-common" = "boto3>=1.34.0\n"
  }
  lambda_layers_bucket_arn = "arn:aws:s3:::test-lambda-layers-bucket"
  idp_common_source_path   = ""
}

# ---------------------------------------------------------------------------
# idp_common_source_path: values outside the documented character set are
# rejected.
# ---------------------------------------------------------------------------
run "source_path_rejects_semicolon" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg; id"
  }

  expect_failures = [var.idp_common_source_path]
}

run "source_path_rejects_double_quote" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg\" id \""
  }

  expect_failures = [var.idp_common_source_path]
}

run "source_path_rejects_backtick" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg`id`"
  }

  expect_failures = [var.idp_common_source_path]
}

run "source_path_rejects_pipe" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg|id"
  }

  expect_failures = [var.idp_common_source_path]
}

run "source_path_rejects_dollar_parenthesis" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg$(id)"
  }

  expect_failures = [var.idp_common_source_path]
}

