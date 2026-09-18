# Plans the example from EMPTY state, as a customer's first apply does, to catch
# count/for_each gated on computed values. Gate only on var.* or length(module.*).
# Exits nonzero by design: three root check blocks cannot evaluate this early, so
# CI greps for the count/for_each errors instead of trusting the exit code.

# A bare mock_provider "aws" does not cover the aliased provider; without the
# second block the plan fails with "No valid credential sources found".
mock_provider "aws" {
  # Generated values make partition a random string, so every derived ARN is
  # rejected as "invalid partition value", burying the real failures.
  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      id                 = "aws"
      reverse_dns_prefix = "com.amazonaws"
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      id     = "us-east-1"
      name   = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/test"
      id         = "123456789012"
      user_id    = "AIDATEST"
    }
  }
}

mock_provider "aws" {
  alias = "us-east-1"

  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      id                 = "aws"
      reverse_dns_prefix = "com.amazonaws"
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      id     = "us-east-1"
      name   = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/test"
      id         = "123456789012"
      user_id    = "AIDATEST"
    }
  }
}

mock_provider "awscc" {}
mock_provider "random" {}
mock_provider "local" {}
mock_provider "null" {}
mock_provider "archive" {}
mock_provider "time" {}
mock_provider "external" {}
mock_provider "opensearch" {}

variables {
  region      = "us-east-1"
  prefix      = "fresh-plan"
  admin_email = "nobody@example.com"
}

# Evaluation ON is the regression guard: its enablement used to derive from a
# computed bucket ARN.
run "fresh_deploy_with_evaluation_enabled" {
  command = plan

  variables {
    enable_evaluation = true
  }
}

run "fresh_deploy_with_evaluation_disabled" {
  command = plan

  variables {
    enable_evaluation = false
  }
}
