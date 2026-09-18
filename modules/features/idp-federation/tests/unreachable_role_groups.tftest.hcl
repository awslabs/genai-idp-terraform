# SPDX-License-Identifier: Apache-2.0
#
# F38b/F38c: the group-mapping env must carry EXTERNAL IdP group names, and a
# configuration the vendored trigger cannot reach must fail the plan rather than
# produce a federated user with no role.
#
# index.py matches each *_GROUP_NAME env value against the user's claim and then
# adds the user to the hardcoded group of the same role name, so three things can
# put a deployment out of reach:
#   * group_mapping values that are not canonical roles
#   * an empty group_mapping (nothing to match)
#   * RBAC group names renamed away from Admin/Author/Reviewer/Viewer

mock_provider "archive" {}
mock_provider "time" {}
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_data "aws_region" {
    defaults = {
      # `region` is what local.user_pool_arn reads (provider v6 rename); an
      # unmocked attribute gets a random value and yields an invalid ARN.
      region = "us-east-1"
      id     = "us-east-1"
      name   = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "MOCK-OIDC-CLIENT-SECRET"
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "MOCK-OIDC-CLIENT-SECRET"
    }
  }
}

variables {
  enabled              = true
  provider_type        = "OIDC"
  provider_name        = "ExternalIdP"
  oidc_issuer          = "https://login.example.com"
  oidc_client_id       = "oidc-client-id-123"
  group_attribute_name = "groups"

  user_pool_id        = "us-east-1_TESTPOOL"
  user_pool_client_id = "1examplepoolclientid23"

  base_layer_arn       = "arn:aws:lambda:us-east-1:123456789012:layer:idp-base:1"
  idp_common_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
}

# The env values are the operator's external group names, and a role with no
# mapped group stays empty so the trigger skips it.
run "external_group_names_reach_the_lambda" {
  command = plan

  variables {
    group_mapping = {
      "okta-idp-admins" = "Admin"
      "okta-idp-users"  = "Viewer"
    }
  }

  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["ADMIN_GROUP_NAME"] == "okta-idp-admins"
    error_message = "ADMIN_GROUP_NAME must be the external IdP group name from group_mapping."
  }
  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["VIEWER_GROUP_NAME"] == "okta-idp-users"
    error_message = "VIEWER_GROUP_NAME must be the external IdP group name from group_mapping."
  }
  assert {
    condition     = aws_lambda_function.group_mapping[0].environment[0].variables["AUTHOR_GROUP_NAME"] == ""
    error_message = "An unmapped role must be empty so the trigger skips it."
  }
}

# A Cognito group name where a canonical role belongs.
run "group_mapping_to_a_renamed_group_name_is_rejected" {
  command = plan

  variables {
    group_mapping = {
      "okta-idp-admins" = "Administrators"
    }
  }

  expect_failures = [var.group_mapping]
}

# Two external groups on one role: upstream has a single slot per role.
run "duplicate_role_in_group_mapping_is_rejected" {
  command = plan

  variables {
    group_mapping = {
      "okta-idp-admins" = "Admin"
      "okta-idp-owners" = "Admin"
    }
  }

  expect_failures = [var.group_mapping]
}

# Group mapping switched on with nothing to match.
run "empty_group_mapping_is_rejected" {
  command = plan

  variables {
    group_mapping = {}
  }

  expect_failures = [aws_lambda_function.group_mapping]
}

# Renamed RBAC groups are unreachable: the trigger adds to the literal role names.
run "renamed_rbac_groups_are_rejected" {
  command = plan

  variables {
    group_mapping = {
      "okta-idp-admins" = "Admin"
    }
    rbac_group_names = {
      Admin    = "Administrators"
      Author   = "Author"
      Reviewer = "Reviewer"
      Viewer   = "Viewer"
    }
  }

  expect_failures = [aws_lambda_function.group_mapping]
}
