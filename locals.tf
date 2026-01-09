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
  api_enabled = var.api.enabled != null ? var.api.enabled : (
    var.enable_api != null ? var.enable_api : true
  )

  # Agent Analytics configuration
  agent_analytics_config = var.api.agent_analytics != null ? var.api.agent_analytics : (
    var.agent_analytics != null ? var.agent_analytics : { enabled = false }
  )

  # Discovery configuration
  discovery_config = var.api.discovery != null ? var.api.discovery : (
    var.discovery != null ? var.discovery : { enabled = false }
  )

  # Chat with Document configuration
  chat_with_document_config = var.api.chat_with_document != null ? var.api.chat_with_document : (
    var.chat_with_document != null ? var.chat_with_document : { enabled = false }
  )

  # Process Changes configuration
  process_changes_config = var.api.process_changes != null ? var.api.process_changes : (
    var.process_changes != null ? var.process_changes : { enabled = false }
  )

  # Knowledge Base configuration
  knowledge_base_config = var.api.knowledge_base != null ? var.api.knowledge_base : (
    var.knowledge_base != null ? var.knowledge_base : { enabled = false }
  )
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

  # Only enable authenticated user permissions when user identity exists and API/UI is enabled
  enable_authenticated_user_permissions = (local.api_enabled || var.web_ui.enabled) && (var.user_identity != null || length(module.user_identity) > 0)
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
  # processor_type is determined from the configured processor objects
  processor_type = (
    var.bedrock_llm_processor != null ? "bedrock-llm" :
    var.bda_processor != null ? "bda" :
    var.sagemaker_udop_processor != null ? "sagemaker-udop" :
    null
  )

  # Determine IDP common layer extras based on processor type
  # Keep the common layer lightweight - heavy dependencies should be in function-specific layers
  base_extras = ["core", "appsync"]
  processor_extras = {
    "bda"            = local.processor_type == "bda" && try(var.bda_processor.summarization.enabled, false) ? ["docs_service"] : [] # Use docs_service instead of summarization
    "bedrock-llm"    = ["ocr", "classification", "extraction", "assessment", "docs_service"]                                        # Include all extras needed by bedrock-llm processor functions based on CDK implementation
    "sagemaker-udop" = ["ocr", "docs_service"]                                                                                      # Use ocr instead of sagemaker, docs_service for API integration
  }

  idp_common_layer_extras = concat(
    local.base_extras,
    local.processor_type != null ? local.processor_extras[local.processor_type] : []
  )

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
  evaluation_baseline_bucket_name = var.evaluation.enabled ? element(split(":", var.evaluation.baseline_bucket_arn), 5) : null
  reporting_bucket_name           = var.reporting.enabled && var.reporting.bucket_arn != null ? try(regex("arn:(aws|aws-us-gov):s3:::([^/]+)", var.reporting.bucket_arn)[1], "") : ""
  web_ui_reporting_bucket_name    = local.reporting_bucket_name
  web_ui_evaluation_bucket_name   = var.evaluation.enabled && var.evaluation.baseline_bucket_arn != null ? try(regex("arn:(aws|aws-us-gov):s3:::([^/]+)", var.evaluation.baseline_bucket_arn)[1], "") : ""
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
  evaluation_statements = var.evaluation.enabled ? [
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
