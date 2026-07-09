# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local values for Bedrock LLM Processor

locals {
  # BedrockHubRoleArn cross-account assume-role (v0.5.12). Env keys are read by
  # idp_common/bedrock/session.py: BEDROCK_ASSUME_ROLE_ARN and
  # BEDROCK_ASSUME_ROLE_EXTERNAL_ID. Unset renders an empty map (no diff).
  bedrock_hub_enabled = var.bedrock_hub_role_arn != ""

  bedrock_assume_role_env = local.bedrock_hub_enabled ? merge(
    {
      BEDROCK_ASSUME_ROLE_ARN = var.bedrock_hub_role_arn
    },
    var.bedrock_assume_role_external_id != "" ? {
      BEDROCK_ASSUME_ROLE_EXTERNAL_ID = var.bedrock_assume_role_external_id
    } : {}
  ) : {}

  # Model permissions per step. Precedence: per-step override, model_id, config.yaml.
  bedrock_model_permissions = {
    for name, id in {
      classification = coalesce(var.classification_model_id, var.model_id)
      extraction     = coalesce(var.extraction_model_id, var.model_id)
      summarization  = coalesce(var.summarization_model_id, var.model_id)
      evaluation     = var.evaluation_model_id != null ? var.evaluation_model_id : (can(local.config_with_overrides.evaluation.llm_method.model) ? local.config_with_overrides.evaluation.llm_method.model : var.model_id)
      assessment     = var.assessment_model_id != null ? var.assessment_model_id : (can(local.config_with_overrides.assessment.model) ? local.config_with_overrides.assessment.model : var.model_id)
      } : name => id != null ? {

      is_arn          = startswith(id, "arn:")
      is_cross_region = !startswith(id, "arn:") && can(regex("^(us|eu|apac)\\.", id))
      base_model_id   = can(regex("^(us|eu|apac)\\.", id)) ? replace(id, "/^(us|eu|apac)\\./", "") : id

      # Foundation model statement (always needed)
      foundation_statement = {
        effect = "Allow"
        actions = [
          "bedrock:InvokeModel*",
          "bedrock:GetFoundationModel"
        ]
        resources = [
          startswith(id, "arn:") && !contains(split(":", id), "inference-profile") ?
          id :
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${can(regex("^(us|eu|apac)\\.", id)) ? replace(id, "/^(us|eu|apac)\\./", "") : id}"
        ]
      }

      # Inference profile statement (only for cross-region inference profiles)
      inference_profile_statement = (!startswith(id, "arn:") && can(regex("^(us|eu|apac)\\.", id))) || (startswith(id, "arn:") && contains(split(":", id), "inference-profile")) ? {
        effect = "Allow"
        actions = [
          "bedrock:GetInferenceProfile",
          "bedrock:InvokeModel*"
        ]
        resources = [
          startswith(id, "arn:") ? id : "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/${id}"
        ]
      } : null

    } : null
  }
}
