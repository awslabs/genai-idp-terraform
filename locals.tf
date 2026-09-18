# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local values for the GenAI IDP Accelerator module

#
# API Configuration - Backward Compatibility Logic
#
locals {
  # Merge new api variable with deprecated individual variables for backward compatibility
  # New api variable takes precedence when both are provided

  # Core API enabled flag
  # Deprecated var.enable_api takes precedence if explicitly set (non-null), otherwise use api.enabled
  api_enabled = var.enable_api != null ? var.enable_api : var.api.enabled

  # Agent Analytics configuration
  # Deprecated var.agent_analytics takes precedence if explicitly set (non-null), otherwise use api.agent_analytics
  agent_analytics_config = var.agent_analytics != null ? var.agent_analytics : var.api.agent_analytics

  # Discovery configuration
  # Deprecated var.discovery takes precedence if explicitly set (non-null), otherwise use api.discovery
  discovery_config = var.discovery != null ? var.discovery : var.api.discovery

  # Chat with Document configuration
  # Deprecated var.chat_with_document takes precedence if explicitly set (non-null), otherwise use api.chat_with_document
  chat_with_document_config = var.chat_with_document != null ? var.chat_with_document : var.api.chat_with_document

  # Process Changes configuration
  # Deprecated var.process_changes takes precedence if explicitly set (non-null), otherwise use api.process_changes
  process_changes_config = var.process_changes != null ? var.process_changes : var.api.process_changes

  # Knowledge Base configuration
  # Deprecated var.knowledge_base takes precedence if explicitly set (non-null), otherwise use api.knowledge_base
  knowledge_base_config = var.knowledge_base != null ? var.knowledge_base : var.api.knowledge_base

  # ---------------------------------------------------------------------------
  # REST API visibility (v0.6.4 rename)
  # ---------------------------------------------------------------------------
  # Upstream renamed AppSyncVisibility -> ApiGatewayVisibility when the
  # transport moved to API Gateway. `api.visibility` is the deprecated spelling;
  # it still takes precedence when explicitly set (matching the established
  # deprecated-wins convention above), so existing configurations keep working.
  # check "api_visibility_deprecated" surfaces the rename.
  api_gateway_visibility = coalesce(var.api.visibility, var.api.api_gateway_visibility)

  # PRIVATE => the REST API is VPC-only. Derived unless explicitly overridden,
  # mirroring upstream UsePrivateApi.
  api_use_private = coalesce(var.api.use_private_api, local.api_gateway_visibility == "PRIVATE")
}

#
# User Identity Configuration - Handle both internal and external user identity
#
locals {
  # Use external user identity config if provided, otherwise use internal module (if created)
  user_pool_arn = var.user_identity != null ? var.user_identity.user_pool_arn : (
    length(module.user_identity) > 0 ? module.user_identity[0].user_pool_arn : null
  )

  # Extract user_pool_id from user_pool_arn
  # ARN format: arn:{partition}:cognito-idp:region:account-id:userpool/user_pool_id
  user_pool_id = local.user_pool_arn != null ? split("/", local.user_pool_arn)[1] : null

  user_pool_client_id = var.user_identity != null ? var.user_identity.user_pool_client_id : (
    length(module.user_identity) > 0 ? module.user_identity[0].user_pool_client_id : null
  )

  identity_pool_id = var.user_identity != null ? var.user_identity.identity_pool_id : (
    length(module.user_identity) > 0 ? module.user_identity[0].identity_pool.identity_pool_id : null
  )

  authenticated_role_arn = var.user_identity != null ? var.user_identity.authenticated_role_arn : (
    length(module.user_identity) > 0 ? module.user_identity[0].identity_pool.authenticated_role_arn : null
  )

  # Whether an authenticated Cognito Identity Pool role exists at all.
  #
  # Derived from CONFIGURATION ONLY — a supplied `var.user_identity`, or the
  # count of the module we create — never from `local.authenticated_role_arn`.
  # That ARN is a computed module attribute, so on a fresh deploy it is unknown
  # at plan time and `authenticated_role_arn != null` is unknown too. Using it to
  # gate `count`/`for_each` fails the plan outright with "Invalid for_each
  # argument ... known only after apply". This boolean is safe as a gate.
  user_identity_available = var.user_identity != null || length(module.user_identity) > 0

  # Only enable authenticated user permissions when user identity exists and API/UI is enabled
  enable_authenticated_user_permissions = (local.api_enabled || var.web_ui.enabled) && local.user_identity_available

  # Chat token-streaming endpoint (v0.6.4) enablement, derived from STATIC config
  # (never from the module's computed arn) so it is safe as a for_each gate.
  # Mirrors the API module's local.chat_stream_enabled gate.
  chat_stream_enabled = try(var.api.enable_agent_companion_chat, false) || try(var.api.chat_with_document.enabled, false)

  # Grant the authenticated Cognito role invoke on the stream Function URL only
  # when the API is enabled, the role exists, and chat streaming is on.
  enable_chat_stream_invoke_grant = local.api_enabled && local.chat_stream_enabled && local.user_identity_available
}

#
# Processor Configuration Validation
#
locals {
}

#
# Processor Type and Validation
#
locals {
  processor_type = var.processor.type

  # Feature enablement is config-authoritative: derived at plan time to match
  # exactly what the seeder Lambda computes at apply time, which is the operator
  # config file DEEP-MERGED OVER the upstream system defaults. The example config
  # files are sparse (they omit whole sections), so a plain
  # try(config.<section>.enabled, false) would resolve false for a section the
  # config omits even though the seeder's merge enables it from the system
  # default — the exact drift that left the summarization Lambda unbuilt while
  # the runtime config had summarization.enabled=true. Resolution therefore
  # mirrors the model resolution in unified-processor/locals.tf:
  #   config file value  ->  system-default value
  # reading the same sources/.../system_defaults/base-*.yaml the seeder merges.
  # path.module (not path.root): the root module is consumed as a child module
  # (e.g. source = "../.." from an example), so path.root is the EXAMPLE dir,
  # where sources/ does not exist. path.module is this repo-root module dir,
  # which contains the vendored sources/ tree.
  _system_defaults_dir = "${path.module}/sources/lib/idp_common_pkg/idp_common/config/system_defaults"

  _default_summarization_enabled   = try(yamldecode(file("${local._system_defaults_dir}/base-summarization.yaml")).summarization.enabled, false)
  _default_evaluation_enabled      = try(yamldecode(file("${local._system_defaults_dir}/base-evaluation.yaml")).evaluation.enabled, false)
  _default_rule_validation_enabled = try(yamldecode(file("${local._system_defaults_dir}/base-rule-validation.yaml")).rule_validation.enabled, false)
  _default_hitl_enabled            = try(yamldecode(file("${local._system_defaults_dir}/base-confidence.yaml")).hitl.enabled, false)
  _default_ocr_backend             = try(yamldecode(file("${local._system_defaults_dir}/base-ocr.yaml")).ocr.backend, "textract")

  summarization_enabled = try(var.processor.config.summarization.enabled, local._default_summarization_enabled)

  # Evaluation is the one flag with a hard infrastructure dependency the config
  # cannot express: the baseline S3 bucket. Evaluation runs only when the config
  # enables it (behaviour, config-authoritative) AND a baseline bucket ARN is
  # supplied (infrastructure, Terraform-owned). The upstream system default
  # enables evaluation, so most merged configs report enabled=true; without this
  # infra AND-gate that would force every deployment to provision a baseline
  # bucket. This matches observed runtime behaviour: a deployment whose config
  # enables evaluation but supplies no baseline bucket simply does not run
  # evaluation (it cannot score against a baseline that does not exist).
  # Gates count/for_each, so it must be plan-time known: baseline_bucket_arn is
  # computed and unknown on a fresh deploy. ARN fallback for older callers.
  _config_evaluation_enabled = try(var.processor.config.evaluation.enabled, local._default_evaluation_enabled)
  evaluation_enabled = local._config_evaluation_enabled && (
    var.evaluation.enabled != null ? var.evaluation.enabled : var.evaluation.baseline_bucket_arn != null
  )

  rule_validation_enabled = try(var.processor.config.rule_validation.enabled, local._default_rule_validation_enabled)

  # Processor-pipeline HITL enablement (config.hitl.enabled). NOTE: this is the
  # PROCESSOR pipeline's HITL branch (Step Functions states), distinct from the
  # API-side HITL feature gated by var.api.enable_hitl.
  hitl_enabled = try(var.processor.config.hitl.enabled, local._default_hitl_enabled)

  # BDA-as-OCR backend is config-authoritative: it is provisioned iff the config
  # selects ocr.backend = "bda". Deriving from the config (instead of a separate
  # bool) means a config that selects the BDA OCR backend always gets its
  # per-stack BDA project, and one that does not never pays for it. Region
  # availability of Bedrock Data Automation remains the operator's
  # responsibility, exactly as with the previous explicit toggle.
  bda_ocr_backend_enabled = try(var.processor.config.ocr.backend, local._default_ocr_backend) == "bda"

  # All processor façades share one unified engine and one idp-common layer, so
  # the layer carries the same extras for every processor type. `ocr` brings
  # pypdfium2, required by the OCR step on all paths.
  idp_common_layer_extras = local.processor_type != null ? [
    "core", "appsync", "ocr", "classification", "extraction", "assessment", "docs_service"
  ] : ["core", "appsync"]

  # Determine name prefix
  name_prefix = var.prefix != "" ? "${var.prefix}-${random_string.suffix.result}" : "genai-idp-${random_string.suffix.result}"

  # IDP Pattern mapping for Web UI
  idp_pattern_mapping = {
    "bda"            = "Pattern1 - Packet or Media processing with Bedrock Data Automation (BDA)"
    "bedrock-llm"    = "Pattern2 - Packet processing with Textract and Bedrock"
    "sagemaker-udop" = "Pattern3 - Packet processing with Textract, SageMaker(UDOP), and Bedrock"
  }

  # Processor configuration mapping for processor attachment
  processor_config = local.processor_type != null ? {
    bedrock-llm = {
      state_machine_arn          = try(module.bedrock_llm_processor[0].state_machine_arn, null)
      max_processing_concurrency = try(module.bedrock_llm_processor[0].max_processing_concurrency, null)
    }
    bda = {
      state_machine_arn          = try(module.bda_processor[0].state_machine_arn, null)
      max_processing_concurrency = try(module.bda_processor[0].max_processing_concurrency, null)
    }
    sagemaker-udop = {
      state_machine_arn          = try(module.sagemaker_udop_processor[0].state_machine_arn, null)
      max_processing_concurrency = try(module.sagemaker_udop_processor[0].max_processing_concurrency, null)
    }
  }[local.processor_type] : null

  # IAM policy condition for authenticated user permissions - moved to user identity section above

  # Extract resource names from ARNs
  input_bucket_name   = element(split(":", var.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", var.output_bucket_arn), 5)
  working_bucket_name = element(split(":", var.working_bucket_arn), 5)

  # Optional bucket names
  logging_bucket_name             = var.web_ui.logging_enabled ? element(split(":", var.web_ui.logging_bucket_arn), 5) : null
  evaluation_baseline_bucket_name = local.evaluation_enabled ? element(split(":", var.evaluation.baseline_bucket_arn), 5) : null
  reporting_bucket_name           = var.reporting.enabled && var.reporting.bucket_arn != null ? try(regex("arn:(aws|aws-us-gov):s3:::([^/]+)", var.reporting.bucket_arn)[1], "") : ""
  web_ui_reporting_bucket_name    = local.reporting_bucket_name
  web_ui_evaluation_bucket_name   = local.evaluation_enabled && var.evaluation.baseline_bucket_arn != null ? try(regex("arn:(aws|aws-us-gov):s3:::([^/]+)", var.evaluation.baseline_bucket_arn)[1], "") : ""

  # Presigned-URL-via-VPCE (v0.5.16). When opted in AND a VPC-endpoint DNS name
  # is supplied, presigner Lambdas point at the S3 interface endpoint using the
  # "https://bucket.<dns>" form (boto3 virtual-host addressing). Supplied as a
  # user input (S3VpcEndpointDnsNameOverride equivalent) because the endpoint is
  # owned by the caller's VPC wiring; deriving it from a web-UI-side resource
  # would create an api -> web_ui -> api dependency cycle. Null (default) =>
  # presigned URLs use the global S3 endpoint.
  web_ui_s3_endpoint_url = (
    var.web_ui.s3_presigned_url_via_vpc_endpoint && var.web_ui.s3_vpc_endpoint_dns_name_override != null
    ? "https://bucket.${var.web_ui.s3_vpc_endpoint_dns_name_override}"
    : null
  )

  # Web-app bucket name for APIGateway hosting, derived at the ROOT from a
  # root-owned random suffix (random_string.web_ui_bucket_suffix in main.tf).
  #
  # The S3-proxy integration in the API module needs the bucket NAME, but the
  # web-ui module already consumes the API module's outputs (api_url,
  # stream_url). Reading the name off module.web_ui would close the loop into a
  # module-to-module cycle. Deriving it here makes the graph
  # root -> random_string -> {web_ui, api} with no edge between the two modules.
  #
  # Only used in APIGateway mode. In CloudFront mode the override passed to the
  # web-ui module is null and the module keeps naming the bucket from its OWN
  # internal random_string.suffix, so existing deployments see no replacement.
  web_ui_apigw_bucket_name = "${var.prefix}-webapp-${random_string.web_ui_bucket_suffix.result}"
}

#
# IAM Permissions for Authenticated Users
#
locals {
  # Base IAM statements that are always included
  base_authenticated_statements = [
    # S3 permissions for input bucket
    {
      Effect = "Allow"
      Action = [
        # Read operations
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetObjectAttributes",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:ListBucket",
        "s3:ListBucketVersions",
        # Write operations
        "s3:PutObject",
        "s3:PutObjectAcl",
        # Delete operations
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ]
      Resource = [
        var.input_bucket_arn,
        "${var.input_bucket_arn}/*"
      ]
    },
    # S3 permissions for output bucket (read-only)
    {
      Effect = "Allow"
      Action = [
        # Read operations
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetObjectAttributes",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:ListBucket",
        "s3:ListBucketVersions"
      ]
      Resource = [
        var.output_bucket_arn,
        "${var.output_bucket_arn}/*"
      ]
    },
    # Step Functions permissions for authenticated users
    {
      Effect = "Allow"
      Action = [
        "states:StartExecution",
        "states:DescribeExecution",
        "states:ListExecutions",
        "states:StopExecution"
      ]
      Resource = [
        "arn:${data.aws_partition.current.partition}:states:${var.region}:${data.aws_caller_identity.current.account_id}:execution:${local.name_prefix}-*:*",
        "arn:${data.aws_partition.current.partition}:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.name_prefix}-*"
      ]
    },
    # AppSync permissions for authenticated users
    {
      Effect = "Allow"
      Action = [
        "appsync:GraphQL"
      ]
      Resource = [
        "arn:${data.aws_partition.current.partition}:appsync:${var.region}:${data.aws_caller_identity.current.account_id}:apis/*/types/Query/*",
        "arn:${data.aws_partition.current.partition}:appsync:${var.region}:${data.aws_caller_identity.current.account_id}:apis/*/types/Mutation/*",
        "arn:${data.aws_partition.current.partition}:appsync:${var.region}:${data.aws_caller_identity.current.account_id}:apis/*/types/Subscription/*"
      ]
    }
  ]

  # Human review statements (conditional)
  human_review_a2i_statement = var.human_review.enabled ? [
    {
      # SageMaker A2I human loop operations do not support resource-level permissions - service limitation
      Effect = "Allow"
      Action = [
        "sagemaker:CreateHumanLoop",
        "sagemaker:ListHumanLoops",
        "sagemaker:DescribeHumanLoop",
        "sagemaker:StopHumanLoop"
      ]
      Resource = "*"
    }
  ] : []

  human_review_ssm_statement = var.human_review.enabled ? [
    {
      Effect = "Allow"
      Action = [
        "ssm:GetParameter"
      ]
      Resource = [
        "arn:${data.aws_partition.current.partition}:ssm:*:*:parameter/${local.name_prefix}/human-review/*"
      ]
    }
  ] : []

  # Processing Environment API statements (conditional)
  processing_environment_api_statements = local.api_enabled ? [
    {
      Effect = "Allow"
      Action = [
        "execute-api:Invoke"
      ]
      Resource = [
        "${module.processing_environment_api[0].api_arn}/*"
      ]
    }
  ] : []

  # Web UI statements (conditional)
  web_ui_statements = var.web_ui.enabled ? [
    {
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameterHistory"
      ]
      Resource = module.web_ui[0].settings_parameter.parameter_arn
    }
  ] : []

  # API statements (conditional)
  api_statements = local.api_enabled ? [
    {
      Effect = "Allow"
      Action = [
        "appsync:GraphQL"
      ]
      Resource = [
        "${module.processing_environment_api[0].api_arn}/*"
      ]
    }
  ] : []

  # Evaluation statements (conditional)
  evaluation_statements = local.evaluation_enabled ? [
    {
      Effect = "Allow"
      Action = [
        # Read operations for evaluation baseline bucket
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetObjectAttributes",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:ListBucket",
        "s3:ListBucketVersions"
      ]
      Resource = [
        var.evaluation.baseline_bucket_arn,
        "${var.evaluation.baseline_bucket_arn}/*"
      ]
    }
  ] : []

  # Human review SageMaker statement (conditional)
  human_review_sagemaker_statement = var.human_review.enabled ? [
    {
      # SageMaker workteam and human loop operations do not support resource-level permissions - service limitation
      Effect = "Allow"
      Action = [
        "sagemaker:DescribeWorkteam",
        "sagemaker:ListWorkteams",
        "sagemaker:ListHumanLoops",
        "sagemaker:DescribeHumanLoop",
        "sagemaker:StopHumanLoop"
      ]
      Resource = "*"
    }
  ] : []
}
