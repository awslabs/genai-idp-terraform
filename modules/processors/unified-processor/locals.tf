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

  # System-default step models, read from the same upstream defaults the seeder
  # Lambda merges in at apply time. Terraform can't see that Lambda-side merge,
  # so without this the IAM allowlist would fall back to var.model_id for a step
  # whose model actually comes from these defaults — the AccessDenied this change
  # removes. Reading sources/ is read-only (allowed); try() degrades to
  # var.model_id if an upstream key ever moves.
  _system_defaults_dir = "${path.module}/../../../sources/lib/idp_common_pkg/idp_common/config/system_defaults"

  _default_classification_model = try(yamldecode(file("${local._system_defaults_dir}/base-classification.yaml")).classification.model, null)
  _default_extraction_model     = try(yamldecode(file("${local._system_defaults_dir}/base-extraction.yaml")).extraction.model, null)
  _default_summarization_model  = try(yamldecode(file("${local._system_defaults_dir}/base-summarization.yaml")).summarization.model, null)
  _default_evaluation_model     = try(yamldecode(file("${local._system_defaults_dir}/base-evaluation.yaml")).evaluation.llm_method.model, null)
  # v0.6 folded assessment under extraction.confidence; the assessment Lambda
  # invokes extraction.confidence.model (primary) and, on low confidence,
  # extraction.confidence.escalation_model. Both must be granted.
  _default_assessment_model            = try(yamldecode(file("${local._system_defaults_dir}/base-confidence.yaml")).extraction.confidence.model, null)
  _default_assessment_escalation_model = try(yamldecode(file("${local._system_defaults_dir}/base-confidence.yaml")).extraction.confidence.escalation_model, null)

  # Per-step resolution, matching what the seeder writes:
  # per-step var -> config YAML -> system default -> var.model_id (backstop).
  bedrock_step_model_ids = {
    classification = coalesce(
      var.classification_model_id,
      try(local.config_with_overrides.classification.model, null),
      local._default_classification_model,
      var.model_id,
    )
    extraction = coalesce(
      var.extraction_model_id,
      try(local.config_with_overrides.extraction.model, null),
      local._default_extraction_model,
      var.model_id,
    )
    summarization = coalesce(
      var.summarization_model_id,
      try(local.config_with_overrides.summarization.model, null),
      local._default_summarization_model,
      var.model_id,
    )
    evaluation = coalesce(
      var.evaluation_model_id,
      try(local.config_with_overrides.evaluation.llm_method.model, null),
      local._default_evaluation_model,
      var.model_id,
    )
    # Assessment reads extraction.confidence.model (v0.6 location), falling back
    # to a top-level assessment.model for older configs, then the system default.
    assessment = coalesce(
      var.assessment_model_id,
      try(local.config_with_overrides.extraction.confidence.model, null),
      try(local.config_with_overrides.assessment.model, null),
      local._default_assessment_model,
      var.model_id,
    )
    # Escalation model the assessment Lambda invokes on low-confidence sections.
    assessment_escalation = try(
      local.config_with_overrides.extraction.confidence.escalation_model,
      local._default_assessment_escalation_model,
    )
  }

  # Per-step lookup into the shared model->statements transform below.
  bedrock_model_permissions = {
    for name, id in local.bedrock_step_model_ids :
    name => id != null ? local.bedrock_model_statements[id] : null
  }

  # Plan-time shape guard: a resolved ID (possibly from an unvalidated config
  # YAML string) must be a full ARN or a Bedrock model / inference-profile ID
  # before it flows into an IAM ARN. Enforced by terraform_data in iam.tf.
  _bedrock_model_id_re = "^(arn:[a-z0-9-]+:bedrock:.*|(us|eu|apac|ca|sa|global)\\.[a-zA-Z0-9][a-zA-Z0-9._:-]*\\.[a-zA-Z0-9][a-zA-Z0-9._:-]*|[a-zA-Z0-9][a-zA-Z0-9._-]*\\.[a-zA-Z0-9][a-zA-Z0-9._:-]*)$"

  bedrock_invalid_model_ids = [
    for step, id in local.bedrock_step_model_ids :
    "${step}=${id}" if id != null && !can(regex(local._bedrock_model_id_re, id))
  ]
}

locals {
  # Shared model-ID -> Bedrock IAM statement transform: ONE place turning an ID
  # into IAM resources, so variable- and config-sourced IDs are treated alike
  # and a geo-prefixed ID always gets both the foundation-model and
  # inference-profile grants. Geo prefixes (us|eu|apac|ca|sa|global) match
  # idp_common.bda.bda_ocr._PROFILE_GEO_PREFIXES; a full ARN passes through
  # verbatim. Keyed by the distinct resolved IDs so it computes once per ID.
  _bedrock_geo_prefix_re = "^(us|eu|apac|ca|sa|global)\\."

  bedrock_model_statements = {
    for id in toset([for _, mid in local.bedrock_step_model_ids : mid if mid != null]) :
    id => {
      is_arn          = startswith(id, "arn:")
      is_cross_region = !startswith(id, "arn:") && can(regex(local._bedrock_geo_prefix_re, id))
      base_model_id   = can(regex(local._bedrock_geo_prefix_re, id)) ? replace(id, "/${local._bedrock_geo_prefix_re}/", "") : id

      # Foundation-model grant (prefix stripped); a non-profile ARN used verbatim.
      foundation_statement = {
        effect = "Allow"
        actions = [
          "bedrock:InvokeModel*",
          "bedrock:GetFoundationModel"
        ]
        resources = [
          startswith(id, "arn:") && !contains(split(":", id), "inference-profile") ?
          id :
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${can(regex(local._bedrock_geo_prefix_re, id)) ? replace(id, "/${local._bedrock_geo_prefix_re}/", "") : id}"
        ]
      }

      # Inference-profile grant (prefix kept), only for a cross-region ID or a profile ARN.
      inference_profile_statement = (!startswith(id, "arn:") && can(regex(local._bedrock_geo_prefix_re, id))) || (startswith(id, "arn:") && contains(split(":", id), "inference-profile")) ? {
        effect = "Allow"
        actions = [
          "bedrock:GetInferenceProfile",
          "bedrock:InvokeModel*"
        ]
        resources = [
          startswith(id, "arn:") ? id : "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/${id}"
        ]
      } : null
    }
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
