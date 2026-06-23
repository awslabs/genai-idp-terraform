# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the tracking-gsi-backfill module (task 4.4).
#
# Property 5 (Requirements 8.1, 8.2, 8.4, 8.5): the GSI backfill is default-off,
# never auto-runs, and its roles are least-privilege.
#
#   * default-off (Req 8.5): the *default-off gating lives at the ROOT*, not in
#     this module. The module itself has no enable flag — it is always "on" when
#     instantiated, and the root gates it via
#     `count = try(var.tracking.enable_gsi_backfill, false) ? 1 : 0` on
#     `module.tracking_gsi_backfill` (features.tf). So `enable_gsi_backfill =
#     false` ⇒ count 0 ⇒ neither the worker Lambda nor the state machine is
#     created. That root-count behavior is a `count` on a module block and is
#     verified by the root `terraform plan`/validate; this module test covers the
#     complementary half: the "on" shape, the no-auto-start guarantee, and the
#     least-privilege scoping (Req 8.1, 8.2, 8.4).
#
#   * on-shape (Req 8.1): instantiating the module yields BOTH the
#     `backfill_worker` Lambda and the `backfill` Step Functions state machine.
#
#   * never auto-runs (Req 8.4): the worker is driven *only* by the Step
#     Functions state machine (the rendered SFN definition references exactly the
#     worker's ARN), and the module declares NO `aws_lambda_invocation`,
#     `null_resource`, or any other auto-start/trigger resource. The latter is a
#     STATIC guarantee: there is no such resource address to assert on, and
#     referencing one would be a configuration error caught by `make validate`.
#     `make check-sources`/grep over the module confirms zero
#     `aws_lambda_invocation`/`null_resource`/`local-exec`. Applying the module
#     creates the machinery only; the operator triggers the run explicitly.
#
#   * least-privilege (Req 8.2):
#       - the WORKER role's policy has NO wildcard ("*") resource on ANY
#         statement; its DynamoDB statement is scoped to exactly the tracking
#         table ARN (+ `/index/*`) and its KMS statement to exactly the
#         encryption key ARN.
#       - the STATE-MACHINE role's `lambda:InvokeFunction` statement is scoped to
#         exactly the worker Lambda ARN (never "*").
#         IMPORTANT EXCEPTION: the state-machine policy also carries CloudWatch
#         vended-log-delivery (`logs:CreateLogDelivery`, …) and X-Ray
#         (`xray:PutTraceSegments`, …) statements that legitimately require
#         `Resource = "*"` — those actions are NOT resource-scopable (a documented
#         AWS requirement, carried with a `#tfsec:ignore` annotation in main.tf
#         and mirroring the wrapper's other logged state machines). So "no
#         wildcard" is asserted ONLY on the SCOPABLE statement
#         (`lambda:InvokeFunction`), never blanket across the SFN policy.
#
# Offline harness: the aws + time providers are mocked. The worker policy is
# `jsonencode(...)` over the worker log-group ARN (computed) plus the input
# tracking-table/KMS ARNs; the SFN policy is `jsonencode(...)` over the worker
# Lambda ARN (computed). Because those resource ARNs are computed attributes, the
# runs use `command = apply` so the mock provider materializes them and the
# policy JSON is fully known for `jsondecode`-based assertions (per the testing
# guidance that computed ARNs require apply even when mocked).

# Several resources validate that computed ARNs are well-formed: the Lambda
# validates its execution-role ARN, the state machine validates its `role_arn`
# and its `logging_configuration.log_destination` (the log-group ARN + ":*").
# The default mock provider returns a random short string for computed
# attributes, which fails those validations on apply, so the IAM role ARN, the
# Lambda ARN, and the log-group ARN are overridden with valid ARNs. (The policies
# under test are unaffected — they are `jsonencode`d from those ARNs and the
# input table/KMS ARNs.)
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/idp-test-gsi-backfill"
    }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:function:idp-test-gsi-backfill-worker"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/vendedlogs/states/idp-test-gsi-backfill"
    }
  }
}

# Mock the time provider so `time_sleep.wait_for_iam_propagation` does not
# actually sleep 30s during the test apply.
mock_provider "time" {}

variables {
  name_prefix         = "idp-test"
  tracking_table_name = "idp-test-tracking"
  tracking_table_arn  = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-test-tracking"
  encryption_key_arn  = "arn:aws:kms:us-east-1:123456789012:key/00000000-1111-2222-3333-444444444444"
}

# ---------------------------------------------------------------------------
# On-shape (Req 8.1): instantiating the module yields BOTH the worker Lambda and
# the backfill state machine.
# ---------------------------------------------------------------------------
run "on_shape_has_worker_and_state_machine" {
  command = apply

  assert {
    condition     = aws_lambda_function.backfill_worker.function_name == "${var.name_prefix}-gsi-backfill-worker"
    error_message = "Instantiating the module must create the backfill worker Lambda."
  }
  assert {
    condition     = aws_sfn_state_machine.backfill.name == "${var.name_prefix}-gsi-backfill"
    error_message = "Instantiating the module must create the backfill Step Functions state machine."
  }
}

# ---------------------------------------------------------------------------
# Never auto-runs (Req 8.4): the worker is driven only by the state machine —
# the rendered SFN definition references exactly the worker ARN. Combined with
# the static absence of any aws_lambda_invocation/null_resource (documented
# above), applying the module creates machinery only; it never invokes the
# worker as a side effect of `terraform apply`.
# ---------------------------------------------------------------------------
run "worker_is_driven_by_state_machine_not_auto_invoked" {
  command = apply

  assert {
    condition     = strcontains(aws_sfn_state_machine.backfill.definition, aws_lambda_function.backfill_worker.arn)
    error_message = "The state-machine definition must invoke exactly the backfill worker (operator-triggered path), confirming the worker is run via Step Functions, not auto-invoked."
  }
}

# ---------------------------------------------------------------------------
# Least-privilege — WORKER role (Req 8.2): no wildcard resource on any statement;
# DynamoDB scoped to exactly the table (+ /index/*); KMS scoped to exactly the
# encryption key.
# ---------------------------------------------------------------------------
run "worker_role_is_least_privilege" {
  command = apply

  # No statement in the worker policy may use a bare "*" resource, and no entry
  # in any statement's Resource list may be "*".
  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.backfill_worker.policy).Statement :
      [for r in s.Resource : r != "*"]
    ]))
    error_message = "No backfill-worker policy statement may use a wildcard ('*') resource."
  }

  # The DynamoDB statement (identified by the dynamodb:Scan action) must be
  # scoped to exactly the tracking-table ARN.
  assert {
    condition = contains(
      one([
        for s in jsondecode(aws_iam_role_policy.backfill_worker.policy).Statement :
        s.Resource if contains(s.Action, "dynamodb:Scan")
      ]),
      var.tracking_table_arn
    )
    error_message = "The worker DynamoDB statement must be scoped to exactly the tracking-table ARN."
  }

  # …and additionally to the table's indexes (arn/index/*), never a bare wildcard.
  assert {
    condition = contains(
      one([
        for s in jsondecode(aws_iam_role_policy.backfill_worker.policy).Statement :
        s.Resource if contains(s.Action, "dynamodb:Scan")
      ]),
      "${var.tracking_table_arn}/index/*"
    )
    error_message = "The worker DynamoDB statement must additionally scope to the table's indexes (arn/index/*)."
  }

  # The KMS statement (identified by kms:Decrypt) must be scoped to exactly the
  # encryption key ARN.
  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.backfill_worker.policy).Statement :
      s.Resource if contains(s.Action, "kms:Decrypt")
    ]) == [var.encryption_key_arn]
    error_message = "The worker KMS statement must be scoped to exactly the encryption-key ARN."
  }
}

# ---------------------------------------------------------------------------
# Least-privilege — STATE-MACHINE role (Req 8.2): the SCOPABLE
# lambda:InvokeFunction statement is scoped to exactly the worker ARN (no "*").
#
# The log-delivery (logs:CreateLogDelivery, …) and X-Ray (xray:PutTraceSegments,
# …) statements legitimately require Resource="*" — those actions are not
# resource-scopable, are carried with a #tfsec:ignore in main.tf, and mirror the
# wrapper's other logged state machines. They are the DOCUMENTED EXCEPTION, so we
# assert no-wildcard ONLY on the lambda:InvokeFunction statement, not blanket.
# ---------------------------------------------------------------------------
run "state_machine_invoke_is_scoped_to_worker" {
  command = apply

  # The lambda:InvokeFunction statement must target exactly the worker Lambda ARN.
  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.backfill_state_machine.policy).Statement :
      s.Resource if contains(s.Action, "lambda:InvokeFunction")
    ]) == [aws_lambda_function.backfill_worker.arn]
    error_message = "The state-machine lambda:InvokeFunction statement must be scoped to exactly the backfill worker ARN."
  }

  # The lambda:InvokeFunction statement's resource list must contain no "*".
  assert {
    condition = alltrue([
      for r in one([
        for s in jsondecode(aws_iam_role_policy.backfill_state_machine.policy).Statement :
        s.Resource if contains(s.Action, "lambda:InvokeFunction")
      ]) : r != "*"
    ])
    error_message = "The state-machine lambda:InvokeFunction statement must not use a wildcard ('*') resource."
  }
}
