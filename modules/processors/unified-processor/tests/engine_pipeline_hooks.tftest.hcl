# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Native `terraform test` for the IDP v0.6 flat hook points (`preprocessing` and
# `postprocessing`) and the shared workflow tail they introduce.
#
# What this guards:
#
#   1. The two flat hook points are ALWAYS rendered, in every combination of
#      summarization / evaluation / HITL. Upstream renders them unconditionally
#      (they are inert until a config version populates the section), and a
#      config-dependent hook point would silently skip customer hooks.
#
#   2. The state graph stays CLOSED. Every path that used to terminate at
#      WorkflowComplete now funnels through PostprocessingHook via a per-edge
#      normalizer Pass, and which normalizer renders depends on the
#      summarization/evaluation combination. Step Functions only rejects a
#      dangling `Next` at CreateStateMachine time — i.e. during apply, against a
#      real account. Asserting closure at plan time catches it here instead.
#
# Offline by design: the AWS provider is mocked, so the suite needs no
# credentials and no network. `command = plan` throughout — the assertions target
# the routing-topology outputs, which derive from literal state names and are
# therefore known at plan (the full `definition` string is not: it interpolates
# computed Lambda ARNs).

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
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

variables {
  name = "hooks-test"

  input_bucket_arn        = "arn:aws:s3:::idp-input-bucket"
  output_bucket_arn       = "arn:aws:s3:::idp-output-bucket"
  working_bucket_arn      = "arn:aws:s3:::idp-working-bucket"
  configuration_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-configuration"
  tracking_table_arn      = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-tracking"
  concurrency_table_arn   = "arn:aws:dynamodb:us-east-1:123456789012:table/idp-concurrency"

  metric_namespace = "IDP/Test"
  log_level        = "INFO"

  idp_common_layer_arn = "arn:aws:lambda:us-east-1:123456789012:layer:idp-common:1"
  base_layer_arn       = "arn:aws:lambda:us-east-1:123456789012:layer:idp-base:1"

  config = {}
}

# ---------------------------------------------------------------------------
# Minimal pipeline: no summarization, no evaluation, no HITL.
# The tail leaves CheckHITLRequired with the document at $.Result.document, so
# TailWrapResultDocument is the normalizer that must render.
# ---------------------------------------------------------------------------
run "tail_closed_without_summarization_or_evaluation" {
  command = plan

  variables {
    is_summarization_enabled = false
    evaluation_enabled       = false
    enable_hitl              = false
  }

  assert {
    condition     = output.state_machine_start_at == "PreprocessingHook"
    error_message = "The v0.6 preprocessing hook must be the StartAt state so it runs before BDA/pipeline routing."
  }

  # Graph closure: every transition target must be a rendered state.
  assert {
    condition = length(setsubtract(
      output.state_machine_transition_targets,
      output.state_machine_state_names
    )) == 0
    error_message = "State machine references transition targets that are not rendered states: ${join(", ", setsubtract(output.state_machine_transition_targets, output.state_machine_state_names))}"
  }

  assert {
    condition = alltrue([for s in [
      "PreprocessingHook",
      "ApplyPreprocessingHookDocument",
      "PreprocessingHookFailed",
      "CheckPreprocessingHalt",
      "MarkSupersededByRedacted",
      "SetSupersededStatus",
      "PostprocessingHook",
      "ApplyPostprocessingHookDocument",
    ] : contains(output.state_machine_state_names, s)])
    error_message = "Both v0.6 flat hook points and the preprocessing halt path must always be rendered."
  }

  assert {
    condition     = contains(output.state_machine_state_names, "TailWrapResultDocument")
    error_message = "Without summarization or evaluation the tail must wrap $.Result.document for PostprocessingHook."
  }

  # The other two normalizers belong to other combinations; rendering them here
  # would leave unreachable states in the definition.
  assert {
    condition = alltrue([for s in [
      "TailWrapSummarizedDocument",
      "NormalizeForEvaluation",
    ] : !contains(output.state_machine_state_names, s)])
    error_message = "Only the normalizer for the active summarization/evaluation combination should render."
  }
}

# ---------------------------------------------------------------------------
# Summarization only. SummarizationStep's OutputPath already reduces $ to the
# bare document, so TailWrapSummarizedDocument is the normalizer.
# ---------------------------------------------------------------------------
run "tail_closed_with_summarization_only" {
  command = plan

  variables {
    is_summarization_enabled = true
    evaluation_enabled       = false
    enable_hitl              = false
  }

  assert {
    condition = length(setsubtract(
      output.state_machine_transition_targets,
      output.state_machine_state_names
    )) == 0
    error_message = "State machine references transition targets that are not rendered states: ${join(", ", setsubtract(output.state_machine_transition_targets, output.state_machine_state_names))}"
  }

  assert {
    condition     = contains(output.state_machine_state_names, "TailWrapSummarizedDocument")
    error_message = "With summarization but no evaluation the tail must wrap the bare document for PostprocessingHook."
  }

  assert {
    condition     = contains(output.state_machine_state_names, "PostSummarizationHook")
    error_message = "The per-step postSummarization hook must still be wired alongside the flat hook points."
  }
}

# ---------------------------------------------------------------------------
# Evaluation without summarization. EvaluationStep reads `"document.$" = "$"`,
# which is only the document when arriving from summarization — so this
# combination must route through NormalizeForEvaluation.
# ---------------------------------------------------------------------------
run "tail_closed_with_evaluation_only" {
  command = plan

  variables {
    is_summarization_enabled       = false
    evaluation_enabled             = true
    evaluation_baseline_bucket_arn = "arn:aws:s3:::idp-baseline-bucket"
    enable_hitl                    = false
  }

  assert {
    condition = length(setsubtract(
      output.state_machine_transition_targets,
      output.state_machine_state_names
    )) == 0
    error_message = "State machine references transition targets that are not rendered states: ${join(", ", setsubtract(output.state_machine_transition_targets, output.state_machine_state_names))}"
  }

  assert {
    condition     = contains(output.state_machine_state_names, "NormalizeForEvaluation")
    error_message = "Evaluation without summarization must reduce the envelope to the bare document before EvaluationStep."
  }

  assert {
    condition     = contains(output.state_machine_state_names, "EvaluationStep")
    error_message = "EvaluationStep must render when evaluation is enabled with a baseline bucket."
  }
}

# ---------------------------------------------------------------------------
# Everything on: summarization + evaluation + HITL. Here the document reaches
# EvaluationStep already reduced by summarization, so no normalizer renders and
# EvaluationStep hands off to PostprocessingHook directly.
# ---------------------------------------------------------------------------
run "tail_closed_with_summarization_evaluation_and_hitl" {
  command = plan

  variables {
    is_summarization_enabled       = true
    evaluation_enabled             = true
    evaluation_baseline_bucket_arn = "arn:aws:s3:::idp-baseline-bucket"
    enable_hitl                    = true
  }

  assert {
    condition = length(setsubtract(
      output.state_machine_transition_targets,
      output.state_machine_state_names
    )) == 0
    error_message = "State machine references transition targets that are not rendered states: ${join(", ", setsubtract(output.state_machine_transition_targets, output.state_machine_state_names))}"
  }

  assert {
    condition     = contains(output.state_machine_state_names, "MarkHITLPending")
    error_message = "The async HITL pending state must render when HITL is enabled."
  }

  assert {
    condition = alltrue([for s in [
      "TailWrapResultDocument",
      "TailWrapSummarizedDocument",
      "NormalizeForEvaluation",
    ] : !contains(output.state_machine_state_names, s)])
    error_message = "With both summarization and evaluation the evaluation output is already { document: ... }, so no tail normalizer should render."
  }

  assert {
    condition     = contains(output.state_machine_transition_targets, "PostprocessingHook")
    error_message = "Something must transition into PostprocessingHook; otherwise the flat hook point is unreachable."
  }
}
