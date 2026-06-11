# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# =============================================================================
# State-migration `moved {}` blocks for the v0.5.12 processor-façade refactor
# =============================================================================
#
# Spec: idp-v0.5.12-round-1 (task 4.3). Design decision 5 ("`moved {}` first,
# recreate as last resort") and .kiro/steering/breaking-changes.md.
#
# The per-pattern processor modules (`module.bda_processor`,
# `module.bedrock_llm_processor`, `module.sagemaker_udop_processor`) were
# refactored from monolithic modules into thin public façades that delegate the
# document-processing engine to a shared internal submodule, `module.engine`
# (`modules/processors/unified-processor/`). The inner engine resources that
# previously lived directly under each façade now live one level deeper under
# `module.<facade>[0].module.engine.*`.
#
# These blocks remap the OLD per-pattern addresses (as they exist in a v0.4.16
# state) to the NEW façade->engine nested addresses so that `terraform apply`
# preserves real infrastructure instead of destroy/recreating it.
#
# Address-correctness notes:
#   * All three façade modules are count-gated at the root (`count = ... ? 1 : 0`),
#     so both the OLD and NEW addresses carry the `[0]` instance index.
#   * The shared engine (`unified-processor`) was derived 1:1 from the former
#     `bedrock-llm-processor`, so that façade maps cleanly across every resource
#     (count-gating parity verified). Whole-resource moves preserve instance
#     keys for count-gated resources.
#   * The former BDA and SageMaker-UDOP monoliths had a genuinely different
#     internal topology (ECR + CodeBuild image builds, differently-named IAM /
#     Lambda / SFN resources). Only the resources whose identity is preserved in
#     the shared engine are remapped here; the BDA/UDOP-only resources that have
#     no engine equivalent (ECR repositories, CodeBuild projects, the extra
#     per-function DLQs, the EventBridge wiring under different names, etc.) are
#     unavoidable recreates and are documented in
#     docs/migration-v0.4.16-to-v0.5.12.md (task 13.2) with impact + rollback.
#
# Verification: a full 0-destroy / 0-create confirmation requires a real or
# representative v0.4.16 state and a live `terraform plan` (spec task 14.2).
# This file is validated for syntax + address shape via `make validate`.

# =============================================================================
# Bedrock-LLM processor façade  (clean 1:1 -> module.engine)
# =============================================================================
# The unified engine is a 1:1 derivation of the former bedrock-llm-processor
# module, so every former resource maps to the identically-named engine
# resource one level deeper. Generated from the engine resource set; the engine
# only adds `time_sleep.wait_for_iam_propagation` (new, no prior address, so it
# intentionally has no `moved` block).

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.assessment_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.assessment_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.classification_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.classification_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.evaluation_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.evaluation_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.extraction_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.extraction_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.ocr_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.ocr_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.process_results_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.process_results_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.rule_validation_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.rule_validation_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.rule_validation_orchestration_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.rule_validation_orchestration_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.state_machine
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.state_machine
}

moved {
  from = module.bedrock_llm_processor[0].aws_cloudwatch_log_group.summarization_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_cloudwatch_log_group.summarization_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_policy.kms_policy
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_policy.kms_policy
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.assessment_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.assessment_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.classification_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.classification_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.evaluation_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.evaluation_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.extraction_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.extraction_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.ocr_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.ocr_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.process_results_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.process_results_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.rule_validation_role
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.rule_validation_role
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.state_machine
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.state_machine
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role.summarization_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role.summarization_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.assessment_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.assessment_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.assessment_lambda_appsync
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.assessment_lambda_appsync
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.assessment_lambda_kms
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.assessment_lambda_kms
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.classification_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.classification_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.evaluation_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.evaluation_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.evaluation_lambda_appsync
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.evaluation_lambda_appsync
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.extraction_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.extraction_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.ocr_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.ocr_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.process_results_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.process_results_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.rule_validation_kms
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.rule_validation_kms
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.rule_validation_orchestration_extras
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.rule_validation_orchestration_extras
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.rule_validation_policy
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.rule_validation_policy
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.state_machine
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.state_machine
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.state_machine_hook_inference
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.state_machine_hook_inference
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy.summarization_lambda
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy.summarization_lambda
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.assessment_kms_attachment
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.assessment_kms_attachment
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.assessment_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.assessment_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.classification_lambda_basic
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.classification_lambda_basic
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.classification_lambda_kms_attachment
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.classification_lambda_kms_attachment
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.classification_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.classification_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.evaluation_lambda_kms
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.evaluation_lambda_kms
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.evaluation_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.evaluation_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.extraction_lambda_basic
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.extraction_lambda_basic
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.extraction_lambda_kms_attachment
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.extraction_lambda_kms_attachment
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.extraction_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.extraction_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.ocr_lambda_attachment
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.ocr_lambda_attachment
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.ocr_lambda_basic
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.ocr_lambda_basic
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.ocr_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.ocr_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.process_results_lambda_basic
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.process_results_lambda_basic
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.process_results_lambda_kms_attachment
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.process_results_lambda_kms_attachment
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.process_results_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.process_results_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.rule_validation_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.rule_validation_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.summarization_kms_attachment
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.summarization_kms_attachment
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.summarization_lambda_basic
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.summarization_lambda_basic
}

moved {
  from = module.bedrock_llm_processor[0].aws_iam_role_policy_attachment.summarization_lambda_vpc
  to   = module.bedrock_llm_processor[0].module.engine.aws_iam_role_policy_attachment.summarization_lambda_vpc
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.assessment
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.assessment
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.classification
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.classification
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.evaluation_function
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.evaluation_function
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.extraction
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.extraction
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.ocr
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.ocr
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.process_results
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.process_results
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.rule_validation_function
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.rule_validation_function
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.rule_validation_orchestration_function
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.rule_validation_orchestration_function
}

moved {
  from = module.bedrock_llm_processor[0].aws_lambda_function.summarization
  to   = module.bedrock_llm_processor[0].module.engine.aws_lambda_function.summarization
}

moved {
  from = module.bedrock_llm_processor[0].aws_sfn_state_machine.document_processing
  to   = module.bedrock_llm_processor[0].module.engine.aws_sfn_state_machine.document_processing
}

moved {
  from = module.bedrock_llm_processor[0].null_resource.create_module_build_dir
  to   = module.bedrock_llm_processor[0].module.engine.null_resource.create_module_build_dir
}

moved {
  from = module.bedrock_llm_processor[0].random_id.build_id
  to   = module.bedrock_llm_processor[0].module.engine.random_id.build_id
}

# =============================================================================
# BDA processor façade  (stateful subset preserved -> module.engine)
# =============================================================================
# The former bda-processor monolith built its Lambdas via an ECR image +
# CodeBuild pipeline and used pattern-1-specific resource names. Only the
# resources whose identity is carried into the shared engine are remapped.
# Engine gating differs from the old module for several of these (the old
# resources were ungated; the engine gates them on use_bda / summarization /
# evaluation), so the NEW target carries an explicit `[0]` where the engine
# resource is count-gated. On the BDA façade path use_bda = true and the
# evaluation/summarization Lambdas are present, so index [0] exists.
#
# Recreated (no engine equivalent; see migration guide):
#   aws_ecr_repository.bda_processor, aws_codebuild_project.bda_processor_build,
#   aws_s3_object.pattern1_sources, null_resource.trigger_bda_build,
#   the invoke_bda/process_results/summarization DLQs and their CloudWatch
#   log groups under the old names, the bda_event_rule/target EventBridge
#   wiring, and the per-function IAM roles/policies created under pattern-1
#   names.

# Stateful: SQS dead-letter queue for the BDA completion handler.
moved {
  from = module.bda_processor[0].aws_sqs_queue.bda_completion_dlq
  to   = module.bda_processor[0].module.engine.aws_sqs_queue.bda_completion_dlq[0]
}

# Stateful: Step Functions state machine (document-processing workflow).
moved {
  from = module.bda_processor[0].aws_sfn_state_machine.document_processing
  to   = module.bda_processor[0].module.engine.aws_sfn_state_machine.document_processing
}

# Lambda: BDA completion handler.
moved {
  from = module.bda_processor[0].aws_lambda_function.bda_completion
  to   = module.bda_processor[0].module.engine.aws_lambda_function.bda_completion[0]
}

# Lambda: results-processing handler.
moved {
  from = module.bda_processor[0].aws_lambda_function.process_results
  to   = module.bda_processor[0].module.engine.aws_lambda_function.process_results
}

# Lambda: summarization handler.
moved {
  from = module.bda_processor[0].aws_lambda_function.summarization
  to   = module.bda_processor[0].module.engine.aws_lambda_function.summarization[0]
}

# Lambda: evaluation handler.
moved {
  from = module.bda_processor[0].aws_lambda_function.evaluation_function
  to   = module.bda_processor[0].module.engine.aws_lambda_function.evaluation_function[0]
}

# IAM: shared KMS access policy.
moved {
  from = module.bda_processor[0].aws_iam_policy.kms_policy
  to   = module.bda_processor[0].module.engine.aws_iam_policy.kms_policy
}

# IAM: summarization role KMS attachment.
moved {
  from = module.bda_processor[0].aws_iam_role_policy_attachment.summarization_kms_attachment
  to   = module.bda_processor[0].module.engine.aws_iam_role_policy_attachment.summarization_kms_attachment[0]
}

# =============================================================================
# SageMaker-UDOP processor façade  (stateful subset preserved -> module.engine)
# =============================================================================
# The former sagemaker-udop-processor monolith (Pattern 3) also built its
# Lambdas via ECR + CodeBuild and used pattern-3-specific resource names
# (e.g. *_function, step_functions_*). It is rebuilt as a façade over the shared
# engine (design decision 6). Only the resources whose identity is carried into
# the shared engine are remapped; on the UDOP façade path use_bda = false, so
# the BDA-branch resources do not exist and are not mapped.
#
# Recreated (no engine equivalent; see migration guide):
#   aws_ecr_repository.udop_processor, aws_codebuild_project.udop_processor_build,
#   aws_s3_object.pattern3_sources, the *_function Lambdas/roles/log groups and
#   the step_functions_* role/log group created under pattern-3 names, plus
#   time_sleep.wait_for_sfn_iam_propagation.

# Stateful: Step Functions state machine (document-processing workflow).
moved {
  from = module.sagemaker_udop_processor[0].aws_sfn_state_machine.document_processing
  to   = module.sagemaker_udop_processor[0].module.engine.aws_sfn_state_machine.document_processing
}

# Lambda: evaluation handler.
moved {
  from = module.sagemaker_udop_processor[0].aws_lambda_function.evaluation_function
  to   = module.sagemaker_udop_processor[0].module.engine.aws_lambda_function.evaluation_function[0]
}

# Lambda + IAM: assessment handler (role, inline policies, log group).
moved {
  from = module.sagemaker_udop_processor[0].aws_cloudwatch_log_group.assessment_lambda
  to   = module.sagemaker_udop_processor[0].module.engine.aws_cloudwatch_log_group.assessment_lambda
}

moved {
  from = module.sagemaker_udop_processor[0].aws_iam_role.assessment_lambda
  to   = module.sagemaker_udop_processor[0].module.engine.aws_iam_role.assessment_lambda
}

moved {
  from = module.sagemaker_udop_processor[0].aws_iam_role_policy.assessment_lambda
  to   = module.sagemaker_udop_processor[0].module.engine.aws_iam_role_policy.assessment_lambda
}

moved {
  from = module.sagemaker_udop_processor[0].aws_iam_role_policy.assessment_lambda_appsync
  to   = module.sagemaker_udop_processor[0].module.engine.aws_iam_role_policy.assessment_lambda_appsync[0]
}

moved {
  from = module.sagemaker_udop_processor[0].aws_iam_role_policy.assessment_lambda_kms
  to   = module.sagemaker_udop_processor[0].module.engine.aws_iam_role_policy.assessment_lambda_kms
}

# Count-gated in both the old module and the engine (VPC-conditional);
# whole-resource move preserves the instance key.
moved {
  from = module.sagemaker_udop_processor[0].aws_iam_role_policy_attachment.assessment_lambda_vpc
  to   = module.sagemaker_udop_processor[0].module.engine.aws_iam_role_policy_attachment.assessment_lambda_vpc
}


# =============================================================================
# MCP integration feature submodule — v0.5.3 rename + relocation (C5, task 10)
# =============================================================================
#
# Spec: idp-v0.5.12-round-1 (tasks 10.1/10.2). Requirements 8.1, 8.2, Property 4.
# Governing: .kiro/steering/breaking-changes.md.
#
# TWO address changes are folded into these blocks:
#   1. Lambda RENAME: upstream v0.5.3 renamed `agentcore_analytics_processor`
#      -> `agentcore_mcp_handler` (resource label + `sources/` source path +
#      handler entrypoint). The deployed `function_name` is intentionally kept
#      at the legacy `<api_name>-agentcore-analytics-proc` value so the rename is
#      an in-place update (0 destroy / 0 create) — `function_name` is ForceNew.
#   2. RELOCATION: the whole MCP stack moves OUT of
#      `module.processing_environment_api` INTO the new
#      `module.mcp_integration` feature submodule
#      (`modules/features/mcp-integration/`), per the feature-plugin model
#      (Requirement 3 / 8.4).
#
# -----------------------------------------------------------------------------
# CUTOVER ACTIVE (v0.5.12-tf.0). The three coupled edits have all landed:
# -----------------------------------------------------------------------------
#   (a) the OLD MCP resources were removed from `modules/processing-environment-api`
#       (mcp-integration.tf deleted + the MCP slices of iam-vpc-attachments.tf /
#       outputs.tf / variables.tf removed),
#   (b) the root instantiates `module "mcp_integration"` (count-gated on
#       `local.feature_enable.mcp`) and wires its contract into
#       `local.enabled_feature_contracts` (features.tf),
#   (c) these `moved {}` blocks are UNCOMMENTED (below).
#
# Now that (a) removed the OLD addresses from configuration and (b) instantiated
# the NEW module, each `moved {}` has a `from` that no longer exists in config
# and a `to` that does — the correct state for a relocation. All addresses are
# count-gated ([0]) on both sides; whole-resource moves preserve instance keys.
# A `terraform plan` against a real v0.4.16 state MUST show 0 destroy / 0 create
# for these resources (task 10.3 / 14.2 — needs representative state to confirm).

# --- Lambda: agentcore_analytics_processor -> agentcore_mcp_handler ---
moved {
  from = module.processing_environment_api[0].aws_lambda_function.agentcore_analytics_processor[0]
  to   = module.mcp_integration[0].aws_lambda_function.agentcore_mcp_handler[0]
}
moved {
  from = module.processing_environment_api[0].aws_iam_role.agentcore_analytics_processor[0]
  to   = module.mcp_integration[0].aws_iam_role.agentcore_mcp_handler[0]
}
moved {
  from = module.processing_environment_api[0].aws_iam_role_policy.agentcore_analytics_processor[0]
  to   = module.mcp_integration[0].aws_iam_role_policy.agentcore_mcp_handler[0]
}
moved {
  from = module.processing_environment_api[0].aws_iam_role_policy_attachment.agentcore_analytics_processor_xray[0]
  to   = module.mcp_integration[0].aws_iam_role_policy_attachment.agentcore_mcp_handler_xray[0]
}
moved {
  from = module.processing_environment_api[0].aws_cloudwatch_log_group.agentcore_analytics_processor[0]
  to   = module.mcp_integration[0].aws_cloudwatch_log_group.agentcore_mcp_handler[0]
}
# VPC/ENI attachment moved out of the API module's iam-vpc-attachments.tf.
moved {
  from = module.processing_environment_api[0].aws_iam_role_policy_attachment.agentcore_analytics_processor_vpc[0]
  to   = module.mcp_integration[0].aws_iam_role_policy_attachment.agentcore_mcp_handler_vpc[0]
}

# --- Gateway manager Lambda + build (label unchanged; module relocation only) ---
moved {
  from = module.processing_environment_api[0].aws_lambda_function.agentcore_gateway_manager[0]
  to   = module.mcp_integration[0].aws_lambda_function.agentcore_gateway_manager[0]
}
moved {
  from = module.processing_environment_api[0].aws_iam_role.agentcore_gateway_manager[0]
  to   = module.mcp_integration[0].aws_iam_role.agentcore_gateway_manager[0]
}
moved {
  from = module.processing_environment_api[0].aws_iam_role_policy.agentcore_gateway_manager[0]
  to   = module.mcp_integration[0].aws_iam_role_policy.agentcore_gateway_manager[0]
}
moved {
  from = module.processing_environment_api[0].aws_cloudwatch_log_group.agentcore_gateway_manager[0]
  to   = module.mcp_integration[0].aws_cloudwatch_log_group.agentcore_gateway_manager[0]
}
moved {
  from = module.processing_environment_api[0].null_resource.build_agentcore_gateway_manager[0]
  to   = module.mcp_integration[0].null_resource.build_agentcore_gateway_manager[0]
}

# --- Gateway execution role (module relocation only) ---
moved {
  from = module.processing_environment_api[0].aws_iam_role.agentcore_gateway_execution[0]
  to   = module.mcp_integration[0].aws_iam_role.agentcore_gateway_execution[0]
}
moved {
  from = module.processing_environment_api[0].aws_iam_role_policy.agentcore_gateway_execution[0]
  to   = module.mcp_integration[0].aws_iam_role_policy.agentcore_gateway_execution[0]
}

# --- AgentCore Gateway CFN stack + Cognito client (module relocation only) ---
moved {
  from = module.processing_environment_api[0].aws_cloudformation_stack.agentcore_gateway[0]
  to   = module.mcp_integration[0].aws_cloudformation_stack.agentcore_gateway[0]
}
moved {
  from = module.processing_environment_api[0].aws_cognito_user_pool_client.mcp_client[0]
  to   = module.mcp_integration[0].aws_cognito_user_pool_client.mcp_client[0]
}
