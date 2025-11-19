# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local values for Bedrock LLM Processor

locals {
  # Helper function to generate model permissions for any model_id
  # Config.yaml first, variable override second (proper precedence)
  bedrock_model_permissions = {
    for name, id in {
      classification = var.classification_model_id != null ? var.classification_model_id : (can(local.config_with_overrides.classification.model) ? local.config_with_overrides.classification.model : null)
      extraction     = var.extraction_model_id != null ? var.extraction_model_id : (can(local.config_with_overrides.extraction.model) ? local.config_with_overrides.extraction.model : null)
      summarization  = var.summarization_model_id != null ? var.summarization_model_id : (can(local.config_with_overrides.summarization.model) ? local.config_with_overrides.summarization.model : null)
      evaluation     = var.evaluation_model_id != null ? var.evaluation_model_id : (can(local.config_with_overrides.evaluation.llm_method.model) ? local.config_with_overrides.evaluation.llm_method.model : null)
      assessment     = var.assessment_model_id != null ? var.assessment_model_id : (can(local.config_with_overrides.assessment.model) ? local.config_with_overrides.assessment.model : null)
      } : name => id != null ? {

      # Parse model information
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
