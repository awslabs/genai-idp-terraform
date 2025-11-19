# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local values for Processing Environment API

locals {
  # Helper function to generate model permissions for knowledge base model_id
  # This follows the same pattern as bedrock-llm-processor
  knowledge_base_model_permissions = var.knowledge_base.enabled && var.knowledge_base.model_id != null ? {
    # Parse model information
    is_arn          = startswith(var.knowledge_base.model_id, "arn:")
    is_cross_region = !startswith(var.knowledge_base.model_id, "arn:") && can(regex("^(us|eu|apac)\\.", var.knowledge_base.model_id))
    base_model_id   = can(regex("^(us|eu|apac)\\.", var.knowledge_base.model_id)) ? replace(var.knowledge_base.model_id, "/^(us|eu|apac)\\./", "") : var.knowledge_base.model_id

    # Foundation model statement (always needed)
    # For inference profiles, we need permissions for both the underlying model and the profile itself
    foundation_statement = {
      effect = "Allow"
      actions = [
        "bedrock:InvokeModel*",
        "bedrock:GetFoundationModel"
      ]
      resources = compact([
        # Always include the underlying foundation model
        startswith(var.knowledge_base.model_id, "arn:") && !contains(split(":", var.knowledge_base.model_id), "inference-profile") ?
        var.knowledge_base.model_id :
        "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${can(regex("^(us|eu|apac)\\.", var.knowledge_base.model_id)) ? replace(var.knowledge_base.model_id, "/^(us|eu|apac)\\./", "") : var.knowledge_base.model_id}",
        # For cross-region inference profiles, also include the profile as a foundation model ARN
        # (some Bedrock operations may reference it this way)
        (!startswith(var.knowledge_base.model_id, "arn:") && can(regex("^(us|eu|apac)\\.", var.knowledge_base.model_id))) ?
        "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.knowledge_base.model_id}" : null
      ])
    }

    # Inference profile statement (only for cross-region inference profiles)
    inference_profile_statement = (!startswith(var.knowledge_base.model_id, "arn:") && can(regex("^(us|eu|apac)\\.", var.knowledge_base.model_id))) || (startswith(var.knowledge_base.model_id, "arn:") && contains(split(":", var.knowledge_base.model_id), "inference-profile")) ? {
      effect = "Allow"
      actions = [
        "bedrock:GetInferenceProfile",
        "bedrock:InvokeModel*"
      ]
      resources = [
        startswith(var.knowledge_base.model_id, "arn:") ? var.knowledge_base.model_id : "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/${var.knowledge_base.model_id}"
      ]
    } : null
  } : null
}
