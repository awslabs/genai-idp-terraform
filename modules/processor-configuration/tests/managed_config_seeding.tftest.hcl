# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for B11 managed-config seeding (task 9.2).
#
# Property 14 (Requirements 11.2, 11.3): managed config rows are non-editable
# and seeding is additive.
#
# What is provable offline (mock_provider + command = plan):
#
#   * managed rows carry `managed: true` (Req 11.3 / non-editable marker):
#     every `aws_lambda_invocation.seed_managed` input decodes to an object
#     with `Managed == true` and `IsActive == false`. The seeder Lambda stamps
#     the DynamoDB `Managed` attribute from that input (see
#     src/lambda/configuration-seeder/index.py `_put_config_default`), and the
#     UPSTREAM config-write path rejects edits to `managed: true` rows. That
#     upstream enforcement lives in read-only `sources/` Python and cannot be
#     unit-tested here — it is documented, not asserted (see notes below).
#
#   * the for_each covers exactly the managed_config subdirs present in
#     `sources/config_library/managed_config/*/config.yaml` — no more, no
#     fewer (Req 11.1 discovery feeds the additive seeding).
#
#   * seeding is additive (Req 11.3): the `seed_managed` invocations are
#     separate resources from `seed_default` / `seed_schema`. The pre-existing
#     consumer-row seeding (`seed_default`) is byte-identical to pre-B11: its
#     decoded input carries NO `Managed` flag, so non-managed rows are
#     untouched and only managed rows add the marker.
#
# Offline harness: the aws provider is mocked. The `seed_managed` `input` is
# `jsonencode(...)` over `yamldecode(file(...))` of the read-only snapshot —
# all known at `command = plan` with no AWS credentials and no apply. The
# `aws_lambda_invocation` resources are NOT executed at plan time, so their
# `input` (a configured argument, not a computed result) is fully resolvable.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_region" {
    defaults = {
      id   = "us-east-1"
      name = "us-east-1"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  name_prefix              = "idp-test"
  configuration_table_name = "idp-test-configuration"

  # Minimal but representative consumer payloads for the pre-existing
  # (non-managed) seed_default / seed_schema rows.
  configuration = {
    classification = {
      classificationMethod = "textPromptListClassification"
    }
  }
  schema = {
    documentTypes = []
  }

  base_layer_arn       = "arn:aws:lambda:us-east-1:123456789012:layer:idp-base:1"
  idp_common_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
  encryption_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-ab12-cd34-ef56-abcdef123456"
}

# ---------------------------------------------------------------------------
# for_each covers exactly the managed_config subdirs in the snapshot.
# These are the four baselines that ship in v0.5.12:
# fake-w2, docsplit, realkie-fcc-verified, ocr-benchmark.
# ---------------------------------------------------------------------------
run "for_each_covers_exactly_the_managed_subdirs" {
  command = plan

  assert {
    condition = toset(keys(aws_lambda_invocation.seed_managed)) == toset([
      "fake-w2", "docsplit", "realkie-fcc-verified", "ocr-benchmark"
    ])
    error_message = "seed_managed for_each must cover exactly the managed_config subdirs present in sources (fake-w2, docsplit, realkie-fcc-verified, ocr-benchmark), no more and no fewer."
  }

  # The discovered local set must agree with the for_each keys (the locals are
  # the single source of truth driving the seeding).
  assert {
    condition     = toset(keys(local.managed_configs)) == toset(keys(aws_lambda_invocation.seed_managed))
    error_message = "local.managed_configs keys must drive the seed_managed for_each exactly."
  }
}

# ---------------------------------------------------------------------------
# Every managed baseline is seeded with Managed = true and IsActive = false.
# This is the marker the seeder stamps onto the DynamoDB row, which the
# upstream config-write path then treats as non-editable.
# ---------------------------------------------------------------------------
run "managed_rows_carry_managed_true_and_inactive" {
  command = plan

  assert {
    condition = alltrue([
      for k, inv in aws_lambda_invocation.seed_managed :
      jsondecode(inv.input).Managed == true
    ])
    error_message = "Every seed_managed invocation input must set Managed == true so the seeded row is non-editable (Req 11.2)."
  }

  assert {
    condition = alltrue([
      for k, inv in aws_lambda_invocation.seed_managed :
      jsondecode(inv.input).IsActive == false
    ])
    error_message = "Every seed_managed invocation must seed IsActive == false so a managed baseline never hijacks the active runtime config."
  }

  # The Default key is reused (versioned), and the version equals the subdir
  # name — deterministic keys, never clobbering a consumer row.
  assert {
    condition = alltrue([
      for k, inv in aws_lambda_invocation.seed_managed :
      jsondecode(inv.input).Key == "Default" && jsondecode(inv.input).Version == k
    ])
    error_message = "Each managed row must use Key=Default with Version equal to its subdir name (deterministic per-baseline version key)."
  }
}

# ---------------------------------------------------------------------------
# Seeding is additive: the pre-existing consumer seed_default row is unchanged
# (no Managed flag), so non-managed rows are byte-identical to pre-B11. Only
# the separate seed_managed resources add the managed marker.
# ---------------------------------------------------------------------------
run "seed_default_is_unchanged_and_non_managed" {
  command = plan

  # seed_default carries no managed flag (the consumer/default row is untouched).
  assert {
    condition     = !can(jsondecode(aws_lambda_invocation.seed_default.input).Managed)
    error_message = "seed_default input must NOT carry a Managed flag — pre-existing non-managed consumer rows must stay byte-identical to pre-B11 (additive seeding, Req 11.3)."
  }

  # seed_default still seeds the Default key with the supplied configuration.
  assert {
    condition     = jsondecode(aws_lambda_invocation.seed_default.input).Key == "Default"
    error_message = "seed_default must still seed the Default consumer configuration row."
  }

  # seed_schema likewise carries no managed flag.
  assert {
    condition     = !can(jsondecode(aws_lambda_invocation.seed_schema.input).Managed)
    error_message = "seed_schema input must NOT carry a Managed flag — schema seeding is non-managed and unchanged by B11."
  }

  # The managed seeding is a strictly separate resource set from the consumer
  # rows: enumerating seed_managed never collides with the single Default row.
  assert {
    condition     = length(aws_lambda_invocation.seed_managed) == length(local.managed_configs)
    error_message = "seed_managed must add exactly one row per discovered managed baseline, independent of the consumer seed_default/seed_schema rows."
  }
}
