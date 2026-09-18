# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local values for Processing Environment API

locals {
  # Presigned-URL-via-VPCE: inject S3_ENDPOINT_URL into presigner/dataset
  # Lambdas only when an endpoint URL is supplied (opt-in). Empty map is a
  # no-op merge, so public deployments keep the global regional S3 endpoint.
  s3_endpoint_url_env = var.s3_endpoint_url != null ? { S3_ENDPOINT_URL = var.s3_endpoint_url } : {}

  # Least-privilege resource scope for the getStepFunctionExecution resolver's
  # states:DescribeExecution / states:GetExecutionHistory grant.
  #
  # Upstream (SAM) scopes this to `execution:${StackName}-*:*`. The Terraform
  # port previously granted `Resource = "*"`, which let the resolver describe
  # ANY Step Functions execution in the account — the account-wide reach behind
  # the reported IDOR. We restore least privilege by scoping to this
  # deployment's own document-processing executions.
  #
  # A state machine ARN (…:stateMachine:<name>) becomes an execution ARN scope
  # (…:execution:<name>:*). When the processor (and thus the ARN) is not wired
  # in, fall back to an account/region-scoped prefix wildcard rather than "*",
  # so the grant is never account-wide.
  #
  # `var.name` defaults to null, and interpolating null into a string template is
  # a hard error, so the fallback prefix is guarded. With neither the ARN nor a
  # name available the scope stays partition/region/account bound — still never
  # the bare "*" this local exists to eliminate.
  stepfunction_execution_name_prefix = var.name != null ? "${var.name}-*" : "*"
  stepfunction_execution_resource    = var.state_machine_arn != null ? "${replace(var.state_machine_arn, ":stateMachine:", ":execution:")}:*" : "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:execution:${local.stepfunction_execution_name_prefix}:*"

  # Helper function to generate model permissions for knowledge base model_id
  # This follows the same pattern as bedrock-llm-processor
  knowledge_base_model_permissions = var.knowledge_base.enabled && var.knowledge_base.model_id != null ? {
    # Parse model information. The prefix set includes `global` for IDP v0.6
    # (`global.anthropic.claude-sonnet-4-6`) plus `ca`/`sa`; see the matching note
    # in modules/processors/unified-processor/locals.tf.
    is_arn          = startswith(var.knowledge_base.model_id, "arn:")
    is_cross_region = !startswith(var.knowledge_base.model_id, "arn:") && can(regex("^(us|eu|apac|ca|sa|global)\\.", var.knowledge_base.model_id))
    base_model_id   = can(regex("^(us|eu|apac|ca|sa|global)\\.", var.knowledge_base.model_id)) ? replace(var.knowledge_base.model_id, "/^(us|eu|apac|ca|sa|global)\\./", "") : var.knowledge_base.model_id

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
        "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${can(regex("^(us|eu|apac|ca|sa|global)\\.", var.knowledge_base.model_id)) ? replace(var.knowledge_base.model_id, "/^(us|eu|apac|ca|sa|global)\\./", "") : var.knowledge_base.model_id}",
        # For cross-region inference profiles, also include the profile as a foundation model ARN
        # (some Bedrock operations may reference it this way)
        (!startswith(var.knowledge_base.model_id, "arn:") && can(regex("^(us|eu|apac|ca|sa|global)\\.", var.knowledge_base.model_id))) ?
        "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.knowledge_base.model_id}" : null
      ])
    }

    # Inference profile statement (only for cross-region inference profiles)
    inference_profile_statement = (!startswith(var.knowledge_base.model_id, "arn:") && can(regex("^(us|eu|apac|ca|sa|global)\\.", var.knowledge_base.model_id))) || (startswith(var.knowledge_base.model_id, "arn:") && contains(split(":", var.knowledge_base.model_id), "inference-profile")) ? {
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

locals {
  # CodeBuild needs vpc_id, which the Lambda vpc_config does not require.
  codebuild_has_network = try(var.vpc_config.vpc_id, null) != null && length(try(var.vpc_config.subnet_ids, [])) > 0 && length(try(var.vpc_config.security_group_ids, [])) > 0
}
