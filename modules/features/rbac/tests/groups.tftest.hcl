# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the RBAC submodule — the four Cognito user-pool
# groups.
#
# Verifies the four RBAC groups always exist with default-or-override names:
# exactly four groups, named `Admin`/`Author`/`Reviewer`/`Viewer` by default,
# renamed via `var.group_names` overrides without changing the default-on
# behavior of the four roles.
#
# Offline harness: the aws provider is mocked; the four `aws_cognito_user_group`
# resources are input-derived (name from var.group_names, user_pool_id from
# input), so a `plan` is sufficient to assert names/cardinality.

mock_provider "aws" {}

variables {
  name_prefix  = "idp-test"
  user_pool_id = "us-east-1_TESTPOOL"
}

# ---------------------------------------------------------------------------
# Default names: exactly four groups, canonical names.
# ---------------------------------------------------------------------------
run "default_group_names" {
  command = plan

  assert {
    condition     = length(aws_cognito_user_group.rbac) == 4
    error_message = "RBAC must create exactly four Cognito user-pool groups."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Admin"].name == "Admin"
    error_message = "Admin group must default to name 'Admin'."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Author"].name == "Author"
    error_message = "Author group must default to name 'Author'."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Reviewer"].name == "Reviewer"
    error_message = "Reviewer group must default to name 'Reviewer'."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Viewer"].name == "Viewer"
    error_message = "Viewer group must default to name 'Viewer'."
  }
  assert {
    condition     = output.group_names["Admin"] == "Admin" && output.group_names["Viewer"] == "Viewer"
    error_message = "group_names output must reflect the resolved (default) names."
  }
}

# ---------------------------------------------------------------------------
# Override names: still exactly four groups, renamed per override map.
# ---------------------------------------------------------------------------
run "override_group_names" {
  command = plan

  variables {
    group_names = {
      admin    = "Administrators"
      reviewer = "Approvers"
    }
  }

  assert {
    condition     = length(aws_cognito_user_group.rbac) == 4
    error_message = "Overriding group names must not change the count of four groups."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Admin"].name == "Administrators"
    error_message = "Admin group name override must be honored."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Reviewer"].name == "Approvers"
    error_message = "Reviewer group name override must be honored."
  }
  # Non-overridden roles keep their canonical defaults.
  assert {
    condition     = aws_cognito_user_group.rbac["Author"].name == "Author"
    error_message = "Non-overridden Author group must keep its default name."
  }
  assert {
    condition     = aws_cognito_user_group.rbac["Viewer"].name == "Viewer"
    error_message = "Non-overridden Viewer group must keep its default name."
  }
}
