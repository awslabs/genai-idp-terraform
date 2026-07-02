# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Lambda function for configuration seeding
resource "aws_lambda_function" "configuration_seeder" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.name_prefix}-configuration-seeder"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 120
  memory_size   = 512

  # Pull in `idp_common` so the seeder can merge user config with system
  # defaults (the v0.4.16 runtime expects every config item to be a full
  # IDPConfig). Falling back to the per-processor layer is fine if the
  # dedicated base layer isn't wired (older deployments).
  layers = compact([var.base_layer_arn, var.idp_common_layer_arn])

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TABLE_NAME = var.configuration_table_name
    }
  }

  # VPC configuration (conditional)
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = var.tags
}

# Package Lambda function from top-level src directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/configuration-seeder"
  output_path = "${path.module}/lambda.zip"
}

# Seed Default configuration using resource with proper triggers
resource "aws_lambda_invocation" "seed_default" {
  function_name = aws_lambda_function.configuration_seeder.function_name

  # Link the `default` version to a BDA project when default_bda_project_arn is
  # set (bda-processor façade); omitted otherwise so the input is unchanged.
  input = jsonencode(merge(
    {
      Key   = "Default"
      Value = var.configuration
    },
    var.default_bda_project_arn != null ? { BdaProjectArn = var.default_bda_project_arn } : {}
  ))

  triggers = {
    configuration_hash = sha256(jsonencode(var.configuration))
    # Re-seed when the linked project ARN changes (unset -> "none").
    bda_project_arn = coalesce(var.default_bda_project_arn, "none")
    # Re-invoke when the seeder Lambda source itself changes — this is
    # how we propagate seeder fixes to existing deployments without
    # forcing the operator to taint the resource.
    seeder_source_hash = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.configuration_seeder,
    aws_iam_role_policy_attachment.kms_access
  ]
}

# Seed Schema configuration using resource with proper triggers
resource "aws_lambda_invocation" "seed_schema" {
  function_name = aws_lambda_function.configuration_seeder.function_name

  input = jsonencode({
    Key   = "Schema"
    Value = var.schema
  })

  triggers = {
    schema_hash        = sha256(jsonencode(var.schema))
    seeder_source_hash = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.configuration_seeder,
    aws_iam_role_policy_attachment.kms_access
  ]
}

# ----------------------------------------------------------------------------
# Managed baseline configurations
#
# Seed the upstream managed-config baselines
# (`sources/config_library/managed_config/<name>/config.yaml`) as additional,
# non-active versions stamped `Managed = true`. The upstream `idp_common` config
# layer reads that attribute back as `managed` and rejects edits/uploads to
# those rows, so this seeding is what makes them non-editable while enforcement
# stays entirely upstream. Discovery is via `fileset(...)`, so the set tracks
# whatever ships in the read-only snapshot; an absent directory yields an empty
# map. Each managed row uses its directory name as a deterministic version key;
# consumer-authored non-managed rows are never touched.
# ----------------------------------------------------------------------------
locals {
  managed_config_dir   = "${path.module}/../../sources/config_library/managed_config"
  managed_config_files = fileset(local.managed_config_dir, "*/config.yaml")

  # version-name (subdir) => parsed config dict
  managed_configs = {
    for f in local.managed_config_files :
    dirname(f) => yamldecode(file("${local.managed_config_dir}/${f}"))
    if var.seed_managed_configs
  }
}

# Seed each managed baseline as a non-active, non-editable `Config#<name>` row.
resource "aws_lambda_invocation" "seed_managed" {
  for_each = local.managed_configs

  function_name = aws_lambda_function.configuration_seeder.function_name

  input = jsonencode({
    Key         = "Default"
    Version     = each.key
    Managed     = true
    IsActive    = false
    Description = try(each.value.description, "Managed configuration: ${each.key}")
    Value       = each.value
  })

  triggers = {
    configuration_hash = sha256(jsonencode(each.value))
    seeder_source_hash = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.configuration_seeder,
    aws_iam_role_policy_attachment.kms_access
  ]
}

# ----------------------------------------------------------------------------
# Additional customer configurations
#
# Code-supplied config versions seeded as non-active, EDITABLE Config#<name>
# rows (Managed=false), so they show in the UI version dropdown next to the
# default and can be customized like a UI "Save as Version" copy. Names that
# collide with the reserved "default" version or a managed baseline are dropped
# so they can never clobber those rows.
#
# BDA linking: an entry may declare a top-level `bda_project_arn` key to link
# that version to a BDA project. It is a wrapper-only convention (not config
# data), so it is lifted OUT of the seeded `Value` and passed as the seeder's
# `BdaProjectArn`. Resolution: per-version `bda_project_arn` > fallback_bda_project_arn
# > default_bda_project_arn > none. Both fallbacks apply only to use_bda:true versions.
# ----------------------------------------------------------------------------
locals {
  additional_configurations = {
    for k, v in var.additional_configurations :
    k => v if k != "default" && !contains(keys(local.managed_configs), k)
  }

  # Seeded `Value`: entry with the wrapper-only `bda_project_arn` key stripped.
  additional_config_values = {
    for k, v in local.additional_configurations :
    k => { for ck, cv in v : ck => cv if ck != "bda_project_arn" }
  }

  # Resolved link per version (null => seed no BdaProjectArn). The != null chain
  # is null-safe (coalesce errors when all are null).
  additional_bda_project_arns = {
    for k, v in local.additional_configurations :
    k => (
      try(v.bda_project_arn, null) != null
      ? v.bda_project_arn
      : (try(tobool(v.use_bda), false)
        ? (var.fallback_bda_project_arn != null ? var.fallback_bda_project_arn : var.default_bda_project_arn)
      : null)
    )
  }
}

resource "aws_lambda_invocation" "seed_additional" {
  for_each = local.additional_configurations

  function_name = aws_lambda_function.configuration_seeder.function_name

  # Lift the wrapper-only `bda_project_arn` out of the config body; pass it as
  # `BdaProjectArn` only when a link resolves.
  input = jsonencode(merge(
    {
      Key         = "Default"
      Version     = each.key
      Managed     = false
      IsActive    = false
      Description = try(each.value.description, "Configuration: ${each.key}")
      Value       = local.additional_config_values[each.key]
    },
    local.additional_bda_project_arns[each.key] != null ? { BdaProjectArn = local.additional_bda_project_arns[each.key] } : {}
  ))

  triggers = {
    configuration_hash = sha256(jsonencode(local.additional_config_values[each.key]))
    # Re-seed when the resolved project link changes (unset -> "none").
    bda_project_arn    = coalesce(local.additional_bda_project_arns[each.key], "none")
    seeder_source_hash = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.configuration_seeder,
    aws_iam_role_policy_attachment.kms_access
  ]
}
