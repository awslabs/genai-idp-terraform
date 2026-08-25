# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# HTTP API dispatcher — the AppSync-free transport backend.
#
# Mirrors sources/nested/api-resolvers/template.yaml:
#   HttpApiFieldFunctionMapParam / HttpApiDispatcherFunction / HttpApiDispatcherLogGroup.
#
# The dispatcher (sources/.../http_api_dispatcher/index.py) is the single Lambda
# behind `POST /op/{field}`. It normalizes the API Gateway request into the
# AppSync resolver event shape and either (a) synchronously invokes the SAME
# resolver Lambda AppSync used, or (b) serves the field in-process via
# ddb_direct.py (the former VTL DynamoDB resolvers: getDocument, the date-shard
# document lists, and the discovery/agent job reads/writes).

locals {
  # ---------------------------------------------------------------------------
  # Field -> resolver-function-ARN map (the authoritative dispatch table).
  #
  # Keyed by the CANONICAL field name — the value produced by the dispatcher's
  # FIELD_ALIASES table (index.py). Many GraphQL fields share one resolver
  # Lambda (e.g. all 10 configuration fields route to ConfigurationResolver);
  # the dispatcher aliases those shared fields onto a single canonical key, so
  # the map carries ONE entry per unique resolver Lambda rather than one per
  # field. Keying by anything other than the canonical name would break the
  # alias lookup (`FIELD_FUNCTION_MAP.get(FIELD_ALIASES.get(field, field))`).
  #
  # Fields the dispatcher serves in-process via ddb_direct.py are intentionally
  # ABSENT here. That set is EXACTLY `ddb_direct._HANDLED` — do not widen it from
  # memory:
  #   getDocument, listDocumentsDateHour, listDocumentsDateShard (TrackingTable);
  #   listDiscoveryJobs, updateDiscoveryJobStatus, deleteDiscoveryJob;
  #   getAgentJobStatus, listAgentJobs, updateAgentJobStatus, deleteAgentJob;
  #   getCircuitBreakerStatus (only as the feature-disabled fallback).
  #
  # `listDocuments` is NOT in that set, despite the family resemblance to the
  # listDocumentsDate* entries. FIELD_ALIASES folds it onto `getDocumentCount`,
  # which must be mapped to a real Lambda below. An earlier revision of this
  # comment wrongly listed listDocuments (and createDocument/updateDocument) as
  # ddb_direct-served, which is why the Document List 404'd with
  # "unknown operation: listDocuments" on a live deployment.
  field_function_map = merge(
    {
      # Core document + configuration resolvers (always present)
      uploadDocument           = aws_lambda_function.upload_resolver.arn
      deleteDocument           = aws_lambda_function.delete_document_resolver.arn
      reprocessDocument        = aws_lambda_function.reprocess_document_resolver.arn
      getFileContents          = aws_lambda_function.get_file_contents_resolver.arn
      deleteConfigVersion      = aws_lambda_function.configuration_resolver.arn
      getStepFunctionExecution = aws_lambda_function.get_stepfunction_execution_resolver.arn

      # Document listing / versions / samples (see document-resolvers.tf).
      # `getDocumentCount` is the CANONICAL key the dispatcher's FIELD_ALIASES
      # folds `listDocuments` onto, so this entry is what makes the Web UI's
      # Document List work. `compareDocumentVersions` likewise absorbs
      # getDocumentVersion / listDocumentVersions / deleteDocumentVersion.
      getDocumentCount         = aws_lambda_function.document_resolver["list_documents_gsi_resolver"].arn
      listDocumentsByDateRange = aws_lambda_function.document_resolver["list_documents_range_resolver"].arn
      compareDocumentVersions  = aws_lambda_function.document_resolver["document_versions_resolver"].arn
      getSampleDocumentUrl     = aws_lambda_function.document_resolver["get_sample_document_resolver"].arn
      abortWorkflow            = aws_lambda_function.abort_workflow.arn
      syncBdaIdp               = aws_lambda_function.sync_bda_idp.arn
    },
    var.knowledge_base.enabled ? {
      queryKnowledgeBase = aws_lambda_function.query_knowledge_base_resolver["enabled"].arn
    } : {},
    var.evaluation_enabled ? {
      copyToBaseline = aws_lambda_function.copy_to_baseline_resolver["enabled"].arn
    } : {},
    var.enable_hitl ? {
      claimReview = aws_lambda_function.complete_section_review[0].arn
    } : {},
    var.enable_capacity_planning ? {
      calculateCapacity = aws_lambda_function.calculate_capacity_resolver[0].arn
    } : {},
    var.enable_test_studio ? {
      # Canonical Test Studio keys (aliases fold the rest onto these — see
      # index.py FIELD_ALIASES: getTestRun*/getTestRuns -> compareTestRuns;
      # addTestSet*/getTestSets/updateTestSet/... -> addDocumentsToTestSet;
      # deleteTestSets -> addDocumentsToTestSet).
      startTestRun          = aws_lambda_function.test_runner[0].arn
      addDocumentsToTestSet = aws_lambda_function.test_set_resolver[0].arn
      compareTestRuns       = aws_lambda_function.test_results_resolver[0].arn
      deleteTests           = aws_lambda_function.delete_tests[0].arn
    } : {},
    local.version_check_enabled ? {
      getLatestPublishedVersion = aws_lambda_function.version_check_resolver[0].arn
    } : {},
    var.agent_analytics.enabled ? {
      submitAgentQuery    = module.agent_analytics[0].agent_request_handler_function_arn
      listAvailableAgents = module.agent_analytics[0].list_available_agents_function_arn
    } : {},
    var.discovery.enabled ? {
      autoDetectSections = module.discovery[0].discovery_upload_resolver_function_arn
    } : {},
    var.enable_edit_sections ? {
      processChanges = module.process_changes[0].process_changes_resolver_function_arn
    } : {},
    # Feature-plugin contributions (Chat-with-Document, Feature Platform, …).
    # Composed in feature-plugins.tf from each enabled contract's
    # `field_functions`. Empty by default. Merged last so a feature can override a
    # core field if it deliberately takes it over.
    local.feature_field_functions,
    var.enable_agent_companion_chat ? {
      sendAgentChatMessage   = aws_lambda_function.agent_chat_resolver[0].arn
      listChatSessions       = aws_lambda_function.list_agent_chat_sessions_resolver[0].arn
      getChatMessages        = aws_lambda_function.get_agent_chat_messages_resolver[0].arn
      getAgentChatMessages   = aws_lambda_function.get_agent_chat_messages_resolver[0].arn
      deleteChatSession      = aws_lambda_function.delete_agent_chat_session_resolver[0].arn
      updateChatSessionTitle = aws_lambda_function.create_chat_session_resolver[0].arn
    } : {},
  )

  # Distinct resolver ARNs the dispatcher role must be allowed to invoke.
  dispatcher_invoke_arns = distinct(values(local.field_function_map))

  # ddb_direct tables the dispatcher serves in-process. Empty string when the
  # owning feature is disabled (the dispatcher only touches them for the
  # relevant fields, which are then unreachable anyway).
  dispatcher_discovery_table_name = var.discovery.enabled ? module.discovery[0].discovery_tracking_table_name : ""
  dispatcher_agent_table_name     = var.agent_analytics.enabled ? module.agent_analytics[0].agent_table_name : ""

  # DynamoDB table ARNs the dispatcher role gets CRUD on (ddb_direct).
  dispatcher_ddb_arns = compact([
    local.tracking_table_arn,
    var.discovery.enabled ? module.discovery[0].discovery_tracking_table_arn : null,
    var.agent_analytics.enabled ? module.agent_analytics[0].agent_table_arn : null,
  ])
}

# =============================================================================
# SSM parameter: field -> resolver-function-ARN map (loaded once at cold start)
# =============================================================================
resource "aws_ssm_parameter" "http_api_field_function_map" {
  name  = "/${local.api_name}/http-api/field-function-map"
  type  = "String"
  tier  = "Advanced"
  value = jsonencode(local.field_function_map)
  tags  = var.tags
}

# =============================================================================
# IAM role for the dispatcher
# =============================================================================
resource "aws_iam_role" "http_api_dispatcher" {
  name = "${local.api_name}-http-api-dispatcher"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "http_api_dispatcher" {
  name = "http-api-dispatcher-policy"
  role = aws_iam_role.http_api_dispatcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
        },
        {
          # ddb_direct CRUD on tracking (+ discovery/agent when present)
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
            "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
            "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
          ]
          Resource = flatten([
            for arn in local.dispatcher_ddb_arns : [arn, "${arn}/index/*"]
          ])
        },
        {
          # Load the field->ARN map from SSM at cold start.
          Effect   = "Allow"
          Action   = "ssm:GetParameter"
          Resource = aws_ssm_parameter.http_api_field_function_map.arn
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = local.kms_policy_resource_arn
        },
      ],
      # Invoke every resolver Lambda in the field-function map.
      length(local.dispatcher_invoke_arns) > 0 ? [
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = local.dispatcher_invoke_arns
        }
      ] : [],
      # VPC ENI management when the dispatcher runs in a VPC.
      var.vpc_config != null ? [
        {
          Effect   = "Allow"
          Action   = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"]
          Resource = "*"
        }
      ] : [],
    )
  })
}

resource "aws_iam_role_policy_attachment" "http_api_dispatcher_xray" {
  role       = aws_iam_role.http_api_dispatcher.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# IAM eventual-consistency guard (project convention — see terraform-conventions
# steering). The dispatcher does not synchronously validate its role at create
# time the way CodeBuild/Step Functions do, but its invoke/DDB grants must
# propagate before first invocation; the guard keeps behaviour consistent with
# the other Lambda-provisioning modules in this repo.
resource "time_sleep" "wait_for_iam_propagation" {
  create_duration = "30s"

  triggers = {
    dispatcher_role_arn = aws_iam_role.http_api_dispatcher.arn
    dispatcher_policy   = aws_iam_role_policy.http_api_dispatcher.id
  }
}

# =============================================================================
# Dispatcher Lambda + log group
# =============================================================================
resource "aws_cloudwatch_log_group" "http_api_dispatcher" {
  name              = "/aws/lambda/${local.api_name}-http-api-dispatcher"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "http_api_dispatcher" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/http_api_dispatcher"
  output_path = "${path.module}/../../.terraform/archives/http_api_dispatcher.zip"
}

resource "aws_lambda_function" "http_api_dispatcher" {
  architectures    = [var.lambda_architecture]
  function_name    = "${local.api_name}-http-api-dispatcher"
  role             = aws_iam_role.http_api_dispatcher.arn
  filename         = data.archive_file.http_api_dispatcher.output_path
  source_code_hash = data.archive_file.http_api_dispatcher.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 512
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  description      = "HTTP API dispatcher — replaces AppSync for UI queries/mutations"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      TRACKING_TABLE_NAME      = local.tracking_table_name != null ? local.tracking_table_name : ""
      DISCOVERY_TABLE_NAME     = local.dispatcher_discovery_table_name
      AGENT_TABLE_NAME         = local.dispatcher_agent_table_name
      FIELD_FUNCTION_MAP_PARAM = aws_ssm_parameter.http_api_field_function_map.name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.http_api_dispatcher,
    time_sleep.wait_for_iam_propagation,
  ]

  tags = var.tags
}
