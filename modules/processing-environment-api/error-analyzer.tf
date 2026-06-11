# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Error Analyzer — REMOVED upstream at v0.5.12
# =============================================================================
# The standalone `error_analyzer` and `error_analyzer_resolver` Lambdas (added
# in v0.3.19, wired here via `enable_error_analyzer`) were REMOVED from the
# upstream accelerator in v0.5.12. Their source directories
# (`sources/src/lambda/error_analyzer` and `.../error_analyzer_resolver`) no
# longer exist in the snapshot, and v0.5.12 ships no replacement Lambda,
# AppSync datasource/resolver, or GraphQL field for error analysis.
#
# The capability moved into the unified **agents framework**: error analysis is
# now a library agent (`sources/lib/idp_common_pkg/idp_common/agents/error_analyzer/`)
# registered in the agent factory as `Error-Analyzer-Agent` and surfaced through
# the generic `agent_request_handler` / `list_available_agents` resolvers (see
# `agent-analytics/`). No dedicated wrapper resources are required.
#
# Because these resources were applyable in prior wrapper releases
# (`enable_error_analyzer` defaulted to `true`), consumers upgrading from
# <= v0.4.16-tf.x may have them in real state. The `removed {}` blocks below
# drop them from Terraform state on the next apply WITHOUT destroying the real
# infrastructure (`destroy = false`), so the orphaned Lambdas/roles/log groups
# can be cleaned up out-of-band at the operator's discretion. See
# breaking-changes.md and the migration guide.
#
# `var.enable_error_analyzer` is retained as a deprecated no-op (see
# variables.tf) so existing consumer tfvars continue to plan without error.

removed {
  from = aws_lambda_function.error_analyzer

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_cloudwatch_log_group.error_analyzer

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role.error_analyzer

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy.error_analyzer

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy_attachment.error_analyzer_xray

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy_attachment.error_analyzer_vpc

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_lambda_function.error_analyzer_resolver

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_cloudwatch_log_group.error_analyzer_resolver

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role.error_analyzer_resolver

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy.error_analyzer_resolver

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy_attachment.error_analyzer_resolver_vpc

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_appsync_datasource.error_analyzer_resolver

  lifecycle {
    destroy = false
  }
}
