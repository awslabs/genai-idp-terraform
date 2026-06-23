# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the standalone vpc-endpoints module (task 3.2).
#
# Property 10 (Requirements 7.1, 7.3, 7.4): VPC interface endpoints are
# individually toggleable and partition/region-aware.
#
#   * toggle (Req 7.1, 7.3): several `enabled_interface_endpoints` maps -> the
#     planned interface endpoints equal exactly the enabled set, no more and no
#     fewer. Asserted on the keys/count of `aws_vpc_endpoint.interface`.
#   * partition-aware (Req 7.4): for the configured region, every interface
#     `service_name` renders as `com.amazonaws.${region}.${service}`. Multiple
#     regions are exercised with per-`run` provider overrides.
#
# Offline harness: the aws provider is mocked. `for_each` is input-derived and
# `service_name` is built from `data.aws_region.current.name`, which the mock
# returns as a fixed value, so every assertion is known at `command = plan` with
# no AWS credentials or apply.
#
# Region handling: `data.aws_region.current.name` is mocked to a fixed value per
# provider. The module uses the default (unaliased) `aws` provider, so each
# region `run` maps it to an aliased mock via the `providers` block. The
# default mock (region-agnostic) is used for the toggle runs, which do not
# assert on region.

mock_provider "aws" {}

mock_provider "aws" {
  alias = "use1"
  mock_data "aws_region" {
    defaults = {
      id   = "us-east-1"
      name = "us-east-1"
    }
  }
}

mock_provider "aws" {
  alias = "usgov"
  mock_data "aws_region" {
    defaults = {
      id   = "us-gov-west-1"
      name = "us-gov-west-1"
    }
  }
}

variables {
  vpc_id             = "vpc-0123456789abcdef0"
  subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  security_group_ids = ["sg-0123456789abcdef0"]
  # Gateways are exercised independently; default them off so the toggle runs
  # assert purely on the interface set.
  enable_s3_gateway       = false
  enable_dynamodb_gateway = false
}

# ---------------------------------------------------------------------------
# Toggle: a small enabled subset -> exactly that set of interface endpoints.
# ---------------------------------------------------------------------------
run "toggle_small_subset" {
  command = plan

  variables {
    enabled_interface_endpoints = {
      ssm  = true
      logs = true
      kms  = false # explicitly disabled -> must NOT be provisioned
    }
  }

  assert {
    condition     = toset(keys(aws_vpc_endpoint.interface)) == toset(["ssm", "logs"])
    error_message = "Planned interface endpoints must equal exactly the enabled set {ssm, logs}, no more and no fewer."
  }
  assert {
    condition     = length(aws_vpc_endpoint.interface) == 2
    error_message = "A two-true / one-false toggle map must yield exactly two interface endpoints."
  }
  assert {
    condition     = !contains(keys(aws_vpc_endpoint.interface), "kms")
    error_message = "An endpoint set to false must not be provisioned."
  }
}

# ---------------------------------------------------------------------------
# Toggle: empty map -> no interface endpoints at all.
# ---------------------------------------------------------------------------
run "toggle_none" {
  command = plan

  variables {
    enabled_interface_endpoints = {}
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 0
    error_message = "An empty enable map must provision zero interface endpoints."
  }
}

# ---------------------------------------------------------------------------
# Partition-aware: commercial us-east-1 service names.
# ---------------------------------------------------------------------------
run "service_names_us_east_1" {
  command = plan

  providers = {
    aws = aws.use1
  }

  variables {
    enabled_interface_endpoints = {
      ssm         = true
      logs        = true
      bedrock     = true
      appsync-api = true
    }
  }

  assert {
    condition = alltrue([
      for service, endpoint in aws_vpc_endpoint.interface :
      endpoint.service_name == "com.amazonaws.us-east-1.${service}"
    ])
    error_message = "Every interface service_name must render as com.amazonaws.us-east-1.<service> in us-east-1."
  }
}

# ---------------------------------------------------------------------------
# Partition-aware: GovCloud partition (us-gov-west-1) service names — interface
# AND gateway endpoints, in a single plan (the region is sourced from the
# provider, not hard-coded; us-east-1 above + GovCloud here span both partitions).
# ---------------------------------------------------------------------------
run "service_names_us_gov_west_1" {
  command = plan

  providers = {
    aws = aws.usgov
  }

  variables {
    enabled_interface_endpoints = {
      ssm     = true
      sts     = true
      bedrock = true
    }
    enable_s3_gateway       = true
    enable_dynamodb_gateway = true
    route_table_ids         = ["rtb-0123456789abcdef0"]
  }

  assert {
    condition = alltrue([
      for service, endpoint in aws_vpc_endpoint.interface :
      endpoint.service_name == "com.amazonaws.us-gov-west-1.${service}"
    ])
    error_message = "Every interface service_name must render as com.amazonaws.us-gov-west-1.<service> in the GovCloud partition (Req 7.4)."
  }
  assert {
    condition     = aws_vpc_endpoint.s3_gateway[0].service_name == "com.amazonaws.us-gov-west-1.s3"
    error_message = "S3 gateway service_name must be region/partition-aware (com.amazonaws.us-gov-west-1.s3)."
  }
  assert {
    condition     = aws_vpc_endpoint.dynamodb_gateway[0].service_name == "com.amazonaws.us-gov-west-1.dynamodb"
    error_message = "DynamoDB gateway service_name must be region/partition-aware (com.amazonaws.us-gov-west-1.dynamodb)."
  }
}
