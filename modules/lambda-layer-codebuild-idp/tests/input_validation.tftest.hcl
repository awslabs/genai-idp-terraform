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

mock_provider "aws" {}

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
# layer_prefix: values outside the documented character set are rejected.
#
# The payload in each case is the inert `id`; what is under test is the
# character, not the text after it.
# ---------------------------------------------------------------------------
run "layer_prefix_rejects_semicolon" {
  command = plan

  variables {
    layer_prefix = "idp; id"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_double_quote" {
  command = plan

  variables {
    layer_prefix = "idp\" id \""
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_backtick" {
  command = plan

  variables {
    layer_prefix = "idp`id`"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_pipe" {
  command = plan

  variables {
    layer_prefix = "idp|id"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_dollar_parenthesis" {
  command = plan

  variables {
    layer_prefix = "idp$(id)"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_ampersand" {
  command = plan

  variables {
    layer_prefix = "idp&&id"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_newline" {
  command = plan

  variables {
    layer_prefix = "idp\nid"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_space" {
  command = plan

  variables {
    layer_prefix = "idp layer"
  }

  expect_failures = [var.layer_prefix]
}

# A leading hyphen would be parsed as a flag rather than an operand by the
# tools this value is handed to, so the set requires a leading alphanumeric.
run "layer_prefix_rejects_leading_hyphen" {
  command = plan

  variables {
    layer_prefix = "-idp"
  }

  expect_failures = [var.layer_prefix]
}

run "layer_prefix_rejects_empty" {
  command = plan

  variables {
    layer_prefix = ""
  }

  expect_failures = [var.layer_prefix]
}

# 51 characters: one over the limit imposed by the shortest AWS name this value
# composes.
run "layer_prefix_rejects_over_length" {
  command = plan

  variables {
    layer_prefix = "aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeef"
  }

  expect_failures = [var.layer_prefix]
}

# ---------------------------------------------------------------------------
# layer_prefix: the values real callers pass are accepted.
# ---------------------------------------------------------------------------

# The shape produced by the root module: "${prefix}-${random_string}-idp-layer".
run "layer_prefix_accepts_generated_value" {
  command = plan

  variables {
    layer_prefix = "genai-idp-a1b2c3d4-idp-layer"
  }
}

run "layer_prefix_accepts_underscores_and_digits" {
  command = plan

  variables {
    layer_prefix = "idp_common_2"
  }
}

run "layer_prefix_accepts_single_character" {
  command = plan

  variables {
    layer_prefix = "a"
  }
}

# 50 characters: exactly at the limit.
run "layer_prefix_accepts_max_length" {
  command = plan

  variables {
    layer_prefix = "aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee"
  }
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

run "source_path_rejects_newline" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg\nid"
  }

  expect_failures = [var.idp_common_source_path]
}

# A tilde is excluded deliberately: the value is always expanded inside double
# quotes, where a tilde is taken literally rather than as a home directory, so
# accepting it would silently resolve to a path that does not exist.
run "source_path_rejects_tilde" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "~/sources/lib/idp_common_pkg"
  }

  expect_failures = [var.idp_common_source_path]
}

# ---------------------------------------------------------------------------
# idp_common_source_path: the values real callers pass are accepted.
# ---------------------------------------------------------------------------

# The value modules/idp-common-layer passes. Parent traversal is load-bearing
# here and must stay within the accepted set.
run "source_path_accepts_relative_parent_traversal" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = "../../sources/lib/idp_common_pkg"
  }
}

# The documented default, which collapses the source staging to count = 0.
run "source_path_accepts_empty" {
  command = plan

  variables {
    layer_prefix           = "idp-layer"
    idp_common_source_path = ""
  }
}
