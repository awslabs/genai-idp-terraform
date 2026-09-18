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

  # The evaluation function's reporting fan-out is unconditional in the source
  # (it falls back to the literal name "SaveReportingData"), so only publish the
  # vars when there is a real writer to invoke.
  evaluation_reporting_enabled = (
    var.save_reporting_function_name != null && var.save_reporting_function_name != "" &&
    var.reporting_bucket_name != null && var.reporting_bucket_name != ""
  )

  evaluation_reporting_env = local.evaluation_reporting_enabled ? {
    REPORTING_BUCKET             = var.reporting_bucket_name
    SAVE_REPORTING_FUNCTION_NAME = var.save_reporting_function_name
  } : {}

  # System-default step models, read from the same upstream defaults the seeder
  # Lambda merges in at apply time. Terraform can't see that Lambda-side merge,
  # so without this the IAM allowlist would miss a step whose model comes only
  # from these defaults (the config omits it) — the AccessDenied this closes.
  # Reading sources/ is read-only (allowed); try() degrades to null if an
  # upstream key ever moves.
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

  # Per-step model of the ACTIVE (default) config, resolved from config CONTENT
  # only: config YAML -> upstream system default. There is no Terraform model
  # variable in the chain any more — the config is the single source of truth.
  # try() (not coalesce) so a step the config omits and the defaults don't cover
  # degrades to null (filtered out of the IAM set below) instead of erroring.
  bedrock_step_model_ids = {
    classification = try(
      local.config_with_overrides.classification.model,
      local._default_classification_model,
    )
    extraction = try(
      local.config_with_overrides.extraction.model,
      local._default_extraction_model,
    )
    summarization = try(
      local.config_with_overrides.summarization.model,
      local._default_summarization_model,
    )
    evaluation = try(
      local.config_with_overrides.evaluation.llm_method.model,
      local._default_evaluation_model,
    )
    # Assessment reads extraction.confidence.model (v0.6 location), falling back
    # to a top-level assessment.model for older configs, then the system default.
    assessment = try(
      local.config_with_overrides.extraction.confidence.model,
      local.config_with_overrides.assessment.model,
      local._default_assessment_model,
    )
    # Escalation model the assessment Lambda invokes on low-confidence sections.
    assessment_escalation = try(
      local.config_with_overrides.extraction.confidence.escalation_model,
      local._default_assessment_escalation_model,
    )
  }

  # Managed baseline configs (sources/config_library/managed_config/<name>/config.yaml)
  # are seeded by the processor-configuration module as activatable, non-active
  # rows whenever var.seed_managed_configs is true — so any of them can be made
  # the active config from the UI exactly like an additional version. We read the
  # same vendored files here (read-only; mirrors _system_defaults_dir) rather
  # than plumbing a computed set up from the seeding module, because that set
  # would be apply-time-unknown and cannot drive the IAM policy for_each. Gated
  # on the same var.seed_managed_configs so the harvested set matches exactly
  # what gets seeded.
  _managed_config_dir = "${path.module}/../../../sources/config_library/managed_config"
  _managed_config_models = [
    for f in fileset(local._managed_config_dir, "*/config.yaml") :
    yamldecode(file("${local._managed_config_dir}/${f}"))
    if var.seed_managed_configs
  ]

  # Every config seeded alongside the active default whose models must ALSO be
  # grantable, because any of them can be activated from the UI (only the active
  # config feeds bedrock_step_model_ids). Union of the operator's extra versions
  # and the managed baselines — harvested the SAME way from config content, so
  # activating any seeded version never fails with AccessDenied on InvokeModel.
  _other_seeded_configs = concat(
    [for _, c in var.additional_configurations : c],
    local._managed_config_models,
  )

  # Per-step model harvest across all OTHER seeded configs, reading the same key
  # paths the runtime invokes. (The ACTIVE config's per-step models come from
  # bedrock_step_model_ids above; these are unioned in below.)
  _seeded_config_models = {
    classification = [for c in local._other_seeded_configs : try(c.classification.model, null)]
    extraction     = [for c in local._other_seeded_configs : try(c.extraction.model, null)]
    summarization  = [for c in local._other_seeded_configs : try(c.summarization.model, null)]
    evaluation     = [for c in local._other_seeded_configs : try(c.evaluation.llm_method.model, null)]
    assessment = flatten([for c in local._other_seeded_configs : [
      try(c.extraction.confidence.model, null),
      try(c.assessment.model, null),
    ]])
    assessment_escalation = [for c in local._other_seeded_configs : try(c.extraction.confidence.escalation_model, null)]
  }

  # Terraform cannot see configs authored later in the UI, so an allowlist that
  # is derived is always incomplete. "*" opts into a wildcard grant; any other
  # list is declared by the operator and added to every step.
  bedrock_wildcard_access = contains(var.allowed_bedrock_model_ids, "*")
  _operator_model_ids     = local.bedrock_wildcard_access ? [] : var.allowed_bedrock_model_ids

  bedrock_step_model_id_sets = {
    for step, id in local.bedrock_step_model_ids :
    step => distinct([
      for m in concat([id], lookup(local._seeded_config_models, step, []), local._operator_model_ids) :
      m if m != null && m != ""
    ])
  }

  # Per-step lookup into the shared model->statements transform below, with each
  # step's resources merged across every model that step may invoke.
  bedrock_model_permissions = {
    for step, ids in local.bedrock_step_model_id_sets :
    step => local.bedrock_wildcard_access ? {
      foundation_statement = {
        effect    = "Allow"
        actions   = ["bedrock:InvokeModel*", "bedrock:GetFoundationModel"]
        resources = ["arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"]
      }
      inference_profile_statement = {
        effect  = "Allow"
        actions = ["bedrock:GetInferenceProfile", "bedrock:InvokeModel*"]
        resources = [
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:application-inference-profile/*",
        ]
      }
      } : (length(ids) == 0 ? null : {
        foundation_statement = {
          effect    = "Allow"
          actions   = ["bedrock:InvokeModel*", "bedrock:GetFoundationModel"]
          resources = distinct(flatten([for id in ids : local.bedrock_model_statements[id].foundation_statement.resources]))
        }
        inference_profile_statement = (
          length([for id in ids : id if local.bedrock_model_statements[id].inference_profile_statement != null]) == 0 ? null : {
            effect  = "Allow"
            actions = ["bedrock:GetInferenceProfile", "bedrock:InvokeModel*"]
            resources = distinct(flatten([
              for id in ids : local.bedrock_model_statements[id].inference_profile_statement.resources
              if local.bedrock_model_statements[id].inference_profile_statement != null
            ]))
          }
        )
    })
  }

  # Plan-time shape guard: a resolved ID (possibly from an unvalidated config
  # YAML string) must be a full ARN or a Bedrock model / inference-profile ID
  # before it flows into an IAM ARN. Enforced by terraform_data in iam.tf.
  _bedrock_model_id_re = "^(arn:[a-z0-9-]+:bedrock:.*|(us|eu|apac|ca|sa|global)\\.[a-zA-Z0-9][a-zA-Z0-9._:-]*\\.[a-zA-Z0-9][a-zA-Z0-9._:-]*|[a-zA-Z0-9][a-zA-Z0-9._-]*\\.[a-zA-Z0-9][a-zA-Z0-9._:-]*)$"

  bedrock_invalid_model_ids = distinct(flatten([
    for step, ids in local.bedrock_step_model_id_sets : [
      for id in ids : "${step}=${id}" if !can(regex(local._bedrock_model_id_re, id))
    ]
  ]))
}

locals {
  # Shared model-ID -> Bedrock IAM statement transform: ONE place turning an ID
  # into IAM resources, so variable- and config-sourced IDs are treated alike
  # and a geo-prefixed ID always gets both the foundation-model and
  # inference-profile grants. Geo prefixes (us|eu|apac|ca|sa|global) match
  # idp_common.bda.bda_ocr._PROFILE_GEO_PREFIXES; a full ARN passes through
  # verbatim. Keyed by the distinct resolved IDs so it computes once per ID.
  _bedrock_geo_prefix_re = "^(us|eu|apac|ca|sa|global)\\."

  # Bedrock authorizes the ID actually sent: idp_common strips a trailing :1m
  # into the context-1m beta header and a :flex/:priority tail into the service
  # tier, so the raw config value builds an ARN that matches nothing.
  _bedrock_ids_no_1m = {
    for id in toset(flatten(values(local.bedrock_step_model_id_sets))) :
    id => trimsuffix(id, ":1m")
  }

  # parse_model_id only treats the tail as a tier from the third segment on, so
  # "us.anthropic.claude-sonnet-5:flex" keeps its suffix on the wire.
  bedrock_invoked_model_ids = {
    for raw, trimmed in local._bedrock_ids_no_1m :
    raw => (
      length(split(":", trimmed)) >= 3 && contains(["flex", "priority"], element(split(":", trimmed), length(split(":", trimmed)) - 1)) ?
      join(":", slice(split(":", trimmed), 0, length(split(":", trimmed)) - 1)) :
      trimmed
    )
  }

  bedrock_model_statements = {
    for raw, id in local.bedrock_invoked_model_ids :
    raw => {
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
