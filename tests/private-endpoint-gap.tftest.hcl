# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the root PRIVATE endpoint-gap validation
# (the `check "private_api_endpoint_present"` block in network.tf).
#
# Verifies the check fails if and only if the REST API visibility is PRIVATE AND
# the `execute-api` interface VPC endpoint is absent from the provisioned set
# (the keys of `module.vpc_endpoints[0].interface_endpoint_ids`). On every other
# path (GLOBAL/unset, or PRIVATE *with* the execute-api endpoint present) the
# check holds.
#
# v0.6.4: upstream replaced AppSync with the API Gateway REST transport, so the
# endpoint this gap guards is `execute-api` (was `appsync-api`), the derived local
# is `local.api_visibility_private` (was `appsync_visibility_private`), and the
# supported input is `api.api_gateway_visibility` (was `api.visibility`).
#
# How the gap arises (and why this is the faithful gap case):
#   network.tf wires `_vpc_endpoint_execute_api = api_visibility_private ?
#   { execute-api = true } : {}` into `required_interface_endpoints`, so whenever
#   a private-network deployment is active AND visibility is PRIVATE the
#   execute-api endpoint is *always* provisioned. The only way to reach
#   "PRIVATE without execute-api" is therefore the operator-error case the check
#   exists to catch: visibility set to PRIVATE while no private-network
#   deployment is configured (var.private_network = null / empty subnets), so
#   `module.vpc_endpoints` is count = 0 and the provisioned set is empty ({}).
#   That is exactly the iff boundary this test pins.
#
# check{}-vs-expect_failures note (same mechanism as exactly-one-processor.tftest):
#   A `check {}` assertion failure is only a plan *warning* in a normal plan, but
#   `terraform test`'s `expect_failures = [check.<name>]` is the first-class way
#   to assert a check failed during `command = plan`: the run PASSES iff the named
#   check reported a failure, and FAILS if the check unexpectedly held. The PRIVATE
#   gap case is asserted via `expect_failures`; the passing cases assert the plan
#   is clean (no expect_failures) plus the relevant endpoint-set keys.
#
# Offline harness (identical to the other root tests): aws + an aliased
# aws.us-east-1 provider are mocked (mock_data supplies real partition/region/
# account so AWS ARN-partition validation passes); awscc is mocked; the archive
# provider zips Lambda sources from the read-only `sources/` snapshot for real;
# random_string.suffix is pinned at plan so suffix-embedded resource names (and
# the SageMaker hook-count path) are known at plan. web_ui + api.enabled are
# false so the only validations in play are the processor + private-network
# checks — the API module is never instantiated, so this stays a faithful
# ROOT-level test of the gap check rather than of API-module internals
# (api visibility is read by the check directly, independent of api.enabled).

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_data "aws_region" {
    defaults = {
      id   = "us-east-1"
      name = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

mock_provider "aws" {
  alias = "us-east-1"
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
  mock_data "aws_region" {
    defaults = {
      id   = "us-east-1"
      name = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

mock_provider "awscc" {}

# Pin the random suffix at plan time so suffix-embedded resource names resolve
# (the SageMaker hook-count path and others are unknown-at-plan otherwise).
override_resource {
  target          = random_string.suffix
  override_during = plan
  values = {
    result = "testsuf1"
  }
}

# Shared inputs. web_ui disabled, exactly one processor configured so the only
# validations exercised are the processor gate and the private-network endpoint
# checks. api.enabled stays false everywhere (the gap check reads the effective
# visibility directly and does not need the API module instantiated).
variables {
  region             = "us-east-1"
  input_bucket_arn   = "arn:aws:s3:::idp-test-input"
  output_bucket_arn  = "arn:aws:s3:::idp-test-output"
  working_bucket_arn = "arn:aws:s3:::idp-test-working"
  encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-1234-1234-1234-123456789012"

  web_ui = { enabled = false }

  bedrock_llm_processor = {
    config = {
      classification = { model = "us.amazon.nova-lite-v1:0" }
      extraction     = { model = "us.amazon.nova-lite-v1:0" }
    }
  }
}

# ---------------------------------------------------------------------------
# GLOBAL (explicit) → check holds. No private network, public deployment.
# ---------------------------------------------------------------------------
run "global_visibility_passes" {
  command = plan

  variables {
    api = {
      enabled                = false
      api_gateway_visibility = "GLOBAL"
    }
  }

  # No private network ⇒ module absent ⇒ empty provisioned set; but GLOBAL means
  # the gap check is not triggered at all.
  assert {
    condition     = length(module.vpc_endpoints) == 0
    error_message = "GLOBAL public deployment must not instantiate module.vpc_endpoints."
  }
  assert {
    condition     = local.api_visibility_private == false
    error_message = "GLOBAL visibility must not be treated as PRIVATE by the gap check."
  }
}

# ---------------------------------------------------------------------------
# Visibility unset → defaults to GLOBAL → check holds (current behavior preserved).
# ---------------------------------------------------------------------------
run "unset_visibility_defaults_global_passes" {
  command = plan

  variables {
    api = { enabled = false }
  }

  assert {
    condition     = local.api_gateway_visibility == "GLOBAL"
    error_message = "Unset visibility must default to GLOBAL."
  }
  assert {
    condition     = local.api_visibility_private == false
    error_message = "Unset visibility must not trigger the PRIVATE gap check."
  }
}

# ---------------------------------------------------------------------------
# PRIVATE *with* a private-network deployment → execute-api endpoint is
# provisioned (network.tf wires it in whenever visibility is PRIVATE) → check
# holds. This is the "no gap" half of the iff.
# ---------------------------------------------------------------------------
# Stays a plan run, but overrides module.vpc_endpoints' outputs so the
# `interface_endpoint_ids` keys are KNOWN AT PLAN. Under the mocked aws provider
# the real `aws_vpc_endpoint.interface` ids are known-after-apply, which makes
# the gap-check condition "known after apply" at plan and uncheckable; a full
# `command = apply` of the whole root is not viable offline (mocked providers
# emit random non-ARN values that fail unrelated ARN validations elsewhere in the
# root). Overriding only this module's outputs supplies the "execute-api" key the
# check reads while leaving everything else as the real mocked plan — keeping the
# assertion focused on the check's PRIVATE-with-endpoint branch. (count is still
# driven by config: private_network_enabled = true ⇒ one instance.)
run "private_with_execute_api_endpoint_passes" {
  command = plan

  override_module {
    target = module.vpc_endpoints
    outputs = {
      # Mirror the full required set network.tf derives for a bedrock-llm
      # processor under PRIVATE (base + bedrock + textract + execute-api), so the
      # companion `private_required_endpoints_present` check also holds and the
      # run isolates cleanly to the execute-api branch under test.
      interface_endpoint_ids = {
        ssm                   = "vpce-ssm0000000000000000"
        ssmmessages           = "vpce-ssmmsg00000000000000"
        ec2messages           = "vpce-ec2msg00000000000000"
        logs                  = "vpce-logs000000000000000"
        monitoring            = "vpce-mon0000000000000000"
        kms                   = "vpce-kms0000000000000000"
        sts                   = "vpce-sts0000000000000000"
        sqs                   = "vpce-sqs0000000000000000"
        states                = "vpce-states00000000000000"
        lambda                = "vpce-lambda00000000000000"
        events                = "vpce-events00000000000000"
        codebuild             = "vpce-cb00000000000000000"
        bedrock               = "vpce-br00000000000000000"
        bedrock-runtime       = "vpce-brrt0000000000000000"
        bedrock-agent-runtime = "vpce-bragentrt0000000000"
        textract              = "vpce-txt0000000000000000"
        execute-api           = "vpce-executeapi000000000"
      }
      s3_endpoint_id          = null
      dynamodb_endpoint_id    = null
      execute_api_endpoint_id = "vpce-executeapi000000000"
      endpoint_dns_entries    = {}
    }
  }

  variables {
    api = {
      enabled                = false
      api_gateway_visibility = "PRIVATE"
      # v0.6.4 validation: a PRIVATE REST API requires the execute-api endpoint id
      # (variables.tf `api.api_gateway_vpc_endpoint_id` must be non-empty).
      api_gateway_vpc_endpoint_id = "vpce-executeapi000000000"
    }

    private_network        = { vpc_id = "vpc-0123456789abcdef0" }
    vpc_subnet_ids         = ["subnet-0123456789abcdef0"]
    vpc_security_group_ids = ["sg-0123456789abcdef0"]
  }

  # PRIVATE is recognised, the endpoints module is instantiated, and the
  # execute-api interface endpoint is in the provisioned set — so the gap check
  # passes (no expect_failures).
  assert {
    condition     = local.api_visibility_private == true
    error_message = "api_gateway_visibility = PRIVATE must be recognised by the gap check."
  }
  assert {
    condition     = length(module.vpc_endpoints) == 1
    error_message = "A PRIVATE private-network deployment must instantiate module.vpc_endpoints."
  }
  assert {
    condition     = contains(keys(module.vpc_endpoints[0].interface_endpoint_ids), "execute-api")
    error_message = "PRIVATE deployment must provision the execute-api interface endpoint."
  }
}

# ---------------------------------------------------------------------------
# PRIVATE *without* a private-network deployment → the execute-api endpoint is
# absent from the (empty) provisioned set → the gap check FIRES. This is the
# operator-error case the check exists to surface at plan time, and the "gap"
# half of the iff.
# ---------------------------------------------------------------------------
run "private_without_execute_api_endpoint_fails" {
  command = plan

  variables {
    api = {
      enabled                = false
      api_gateway_visibility = "PRIVATE"
      # Satisfy the v0.6.4 PRIVATE-requires-endpoint-id variable validation so the
      # run reaches the network-level gap check under test (the two guard different
      # things: the variable checks the REST API endpoint id is supplied; the check
      # verifies module.vpc_endpoints actually provisions execute-api for the VPC).
      api_gateway_vpc_endpoint_id = "vpce-executeapi000000000"
    }
    # No private_network / subnets ⇒ module.vpc_endpoints count = 0 ⇒ the
    # execute-api endpoint is absent from the provisioned set ⇒ the gap check fails.
  }

  expect_failures = [
    check.private_api_endpoint_present,
  ]
}
