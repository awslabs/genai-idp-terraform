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

      # Cross-region inference-profile prefixes. `global` was added for IDP v0.6:
      # its system defaults ship `global.anthropic.claude-sonnet-4-6`, and without
      # `global` here that model would get the foundation-model grant but NOT the
      # inference-profile grant, failing at invoke time with AccessDenied. `ca` and
      # `sa` complete the set that idp_common.bda.bda_ocr._PROFILE_GEO_PREFIXES
      # recognises.
      is_arn          = startswith(id, "arn:")
      is_cross_region = !startswith(id, "arn:") && can(regex("^(us|eu|apac|ca|sa|global)\\.", id))
      base_model_id   = can(regex("^(us|eu|apac|ca|sa|global)\\.", id)) ? replace(id, "/^(us|eu|apac|ca|sa|global)\\./", "") : id

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
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${can(regex("^(us|eu|apac|ca|sa|global)\\.", id)) ? replace(id, "/^(us|eu|apac|ca|sa|global)\\./", "") : id}"
        ]
      }

      # Inference profile statement (only for cross-region inference profiles)
      inference_profile_statement = (!startswith(id, "arn:") && can(regex("^(us|eu|apac|ca|sa|global)\\.", id))) || (startswith(id, "arn:") && contains(split(":", id), "inference-profile")) ? {
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

  # OpenAI GPT-5.x models are served via the bedrock-mantle endpoint (OpenAI
  # Responses API) and use a separate IAM action namespace. Model-independent
  # (Resource "*"), so granted as a flat statement to every model-invoking role.
  # Mirrors upstream IDP v0.5.16.
  bedrock_mantle_statement = {
    Effect = "Allow"
    Action = [
      "bedrock-mantle:CreateInference",
      "bedrock-mantle:GetProject",
      "bedrock-mantle:ListProjects",
      "bedrock-mantle:ListTagsForResources",
    ]
    Resource = "*"
  }
}
