# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Unified Processor: shared internal engine that builds the document-processing
# Lambdas and Step Functions state machine from sources/patterns/unified/
# (mirrors CDK UnifiedDocumentProcessor). Not a public surface; instantiated only
# by the per-pattern façade modules.
#
# Dual-mode routing (how a document reaches BDA vs the pipeline):
#   1. Upload tags the object with `config-version` S3 metadata.
#   2. queue_sender resolves it; queue_processor loads that config version and
#      injects its `use_bda` flag and linked `BdaProjectArn` as $.document.*.
#   3. The state machine always starts at RouteByProcessingMode, which sends
#      use_bda=true to the BDA branch and everything else to OCRStep (the
#      Bedrock-LLM/SageMaker step-by-step pipeline).
# Both branches are always deployed; the config version alone selects the path.
# `BdaProjectArn` is written declaratively at seed time (see processor-configuration).

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  name_prefix = var.name

  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = var.working_bucket_arn
  configuration_table_arn = var.configuration_table_arn
  tracking_table_arn      = var.tracking_table_arn
  concurrency_table_arn   = var.concurrency_table_arn
  metric_namespace        = var.metric_namespace
  log_level               = var.log_level
  log_retention_days      = var.log_retention_days
  encryption_key_arn      = var.encryption_key_arn
  vpc_subnet_ids          = var.vpc_subnet_ids
  vpc_security_group_ids  = var.vpc_security_group_ids
  api_id                  = var.api_id
  api_arn                 = var.api_arn
  api_graphql_url         = var.api_graphql_url

  # Extract resource names from ARNs
  input_bucket_name   = element(split(":", local.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", local.output_bucket_arn), 5)
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # DynamoDB table names from ARNs
  configuration_table_name = element(split("/", local.configuration_table_arn), 1)
  tracking_table_name      = element(split("/", local.tracking_table_arn), 1)
  concurrency_table_name   = element(split("/", local.concurrency_table_arn), 1)

  # S3 bucket resource lists for IAM policies
  s3_bucket_arns = [
    local.input_bucket_arn,
    local.output_bucket_arn,
    local.working_bucket_arn
  ]

  s3_object_arns = [
    "${local.input_bucket_arn}/*",
    "${local.output_bucket_arn}/*",
    "${local.working_bucket_arn}/*"
  ]

  # Extract KMS key ID from ARN if provided
  encryption_key_id = local.encryption_key_arn != null ? element(split("/", local.encryption_key_arn), 1) : null

  # Build directory and instance ID for Lambda functions
  module_build_dir   = "${path.module}/build"
  module_instance_id = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"

  # Common tags
  common_tags = merge(var.tags, {
    Component = "UnifiedProcessor"
  })
}

# Configuration components (processor-configuration module)
module "processor_configuration" {
  source = "../../processor-configuration"

  name_prefix              = var.name
  configuration_table_name = local.configuration_table_name
  encryption_key_arn       = var.encryption_key_arn

  configuration = local.config_with_overrides
  schema        = jsondecode(file("${path.module}/schema.json"))

  # Extra non-active config versions seeded alongside the default.
  additional_configurations = var.additional_configurations
  seed_managed_configs      = var.seed_managed_configs

  # BDA project links, seeding inputs only (they do not gate the always-on BDA
  # branch): default_bda_project_arn links the `default` version; bda_project_arn
  # is the fallback for use_bda:true additional versions and never relinks default.
  default_bda_project_arn  = var.default_bda_project_arn
  fallback_bda_project_arn = var.bda_project_arn

  # Layers required so the seeder Lambda merges user config with system
  # defaults; without them the runtime crashes with "No system_prompt found".
  base_layer_arn       = var.base_layer_arn
  idp_common_layer_arn = var.idp_common_layer_arn

  vpc_config          = local.vpc_config
  lambda_tracing_mode = var.lambda_tracing_mode
  tags                = var.tags
}

# Configuration logic
locals {
  base_config = var.config

  # Apply model overrides. base_config may be sparse, so try() tolerates
  # missing sections rather than failing at plan time.
  config_with_overrides = merge(
    local.base_config,
    # Override classification model: per-step var → model_id default
    {
      classification = merge(
        try(local.base_config.classification, {}),
        { model = coalesce(var.classification_model_id, var.model_id) }
      )
    },
    # Override extraction: model, section_splitting_strategy, agentic extraction, review_agent_model
    {
      extraction = merge(
        try(local.base_config.extraction, {}),
        { model = coalesce(var.extraction_model_id, var.model_id) },
        var.section_splitting_strategy != "disabled" ? { section_splitting_strategy = var.section_splitting_strategy } : {},
        var.enable_agentic_extraction ? {
          agentic = merge(
            try(local.base_config.extraction.agentic, {}),
            {
              enabled            = true
              review_agent       = var.review_agent_model != "" ? true : false
              review_agent_model = var.review_agent_model
            }
          )
        } : {}
      )
    },
    # Override summarization model: per-step var → model_id default
    {
      summarization = merge(
        try(local.base_config.summarization, {}),
        { model = coalesce(var.summarization_model_id, var.model_id) }
      )
    },
    # Only override evaluation model if provided (evaluation uses a different config path)
    var.evaluation_model_id != null ? {
      evaluation = merge(
        try(local.base_config.evaluation, {}),
        {
          llm_method = merge(
            try(local.base_config.evaluation.llm_method, {}),
            {
              model = var.evaluation_model_id
            }
          )
        }
      )
    } : {},
    # Only override assessment model if provided
    var.assessment_model_id != null ? {
      assessment = merge(
        try(local.base_config.assessment, {}),
        {
          model = var.assessment_model_id
        }
      )
    } : {}
  )

  # VPC config
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null
}

# Local values for state machine definition
locals {
  # Determine which optional features are active
  hitl_enabled = var.enable_hitl
  summ_enabled = var.is_summarization_enabled
  eval_enabled = var.evaluation_enabled && var.evaluation_baseline_bucket_arn != null

  # Retry policy shared across most task states
  standard_retry = [
    {
      ErrorEquals = [
        "Sandbox.Timedout",
        "Lambda.ServiceException",
        "Lambda.AWSLambdaException",
        "Lambda.SdkClientException",
        "Lambda.TooManyRequestsException",
        "ServiceQuotaExceededException",
        "ThrottlingException",
        "ProvisionedThroughputExceededException",
        "RequestLimitExceeded",
        "ServiceUnavailableException"
      ]
      IntervalSeconds = 2
      MaxAttempts     = 10
      BackoffRate     = 2
    }
  ]

  # The state after process-results/HITL depends on whether summarization is enabled
  post_hitl_next = local.summ_enabled ? "SummarizationStep" : (local.eval_enabled ? "EvaluationStep" : "WorkflowComplete")

  # The state after summarization depends on whether evaluation is enabled
  post_summ_next = local.eval_enabled ? "EvaluationStep" : "WorkflowComplete"

  # CheckHITLRequired default (HITL not triggered), same as post_hitl_next
  check_hitl_default = local.post_hitl_next

  # HITL is async (v0.4.16): process_results marks the doc HITL_IN_PROGRESS and
  # the workflow continues without waiting; reviewers complete via AppSync.
  hitl_states = local.hitl_enabled ? {
    MarkHITLPending = {
      Type    = "Pass"
      Comment = "Document marked for async HITL review, workflow continues without waiting"
      Next    = local.post_hitl_next
    }
  } : {}

  summ_states = local.summ_enabled ? {
    SummarizationStep = {
      Type     = "Task"
      Resource = aws_lambda_function.summarization[0].arn
      Parameters = {
        "execution_arn.$" = "$$.Execution.Id"
        "document.$"      = "$.Result.document"
      }
      ResultPath = "$.Result"
      OutputPath = "$.Result.document"
      Retry      = local.standard_retry
      Next       = local.post_summ_next
    }
  } : {}

  eval_states = local.eval_enabled ? {
    EvaluationStep = {
      Type     = "Task"
      Resource = aws_lambda_function.evaluation_function[0].arn
      Parameters = {
        "execution_arn.$" = "$$.Execution.Id"
        "document.$"      = "$"
      }
      ResultPath = "$"
      Retry      = local.standard_retry
      Next       = "WorkflowComplete"
    }
  } : {}

  # Both branches always render. merge([for ...]) rather than a ternary: the BDA
  # states are heterogeneously shaped (Choice/Task/Fail), so a ternary against an
  # empty object fails type unification; the single-element comprehension folds
  # into the populated map.
  bda_states = merge([
    for _ in [1] : {
      RouteByProcessingMode = {
        Type    = "Choice"
        Comment = "Route to BDA or step-by-step pipeline based on use_bda flag in document config"
        Choices = [
          {
            Variable      = "$.document.use_bda"
            BooleanEquals = true
            Next          = "BDA_CheckExistingData"
          }
        ]
        Default = "OCRStep"
      }

      BDA_CheckExistingData = {
        Type    = "Choice"
        Comment = "Check if document already has pages/sections data (reprocessing scenario)"
        Choices = [
          {
            And = [
              {
                Variable           = "$.document.num_pages"
                NumericGreaterThan = 0
              },
              {
                Variable = "$.document.sections[0]"
                IsString = true
              }
            ]
            Comment = "Document has existing data with string section IDs - skip BDA invocation"
            Next    = "BDA_ProcessResultsSkip"
          },
          {
            And = [
              {
                Variable           = "$.document.num_pages"
                NumericGreaterThan = 0
              },
              {
                Variable  = "$.document.sections[0].section_id"
                IsPresent = true
              }
            ]
            Comment = "Document has existing data with section objects - skip BDA invocation"
            Next    = "BDA_ProcessResultsSkip"
          }
        ]
        Default = "BDA_InvokeDataAutomation"
      }

      BDA_InvokeDataAutomation = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke.waitForTaskToken"
        Parameters = {
          FunctionName = aws_lambda_function.bda_invoke[0].arn
          Payload = {
            "taskToken.$"     = "$$.Task.Token"
            "execution_arn.$" = "$$.Execution.Id"
            "working_bucket"  = local.working_bucket_name
            "BDAProjectArn.$" = "$.document.bda_project_arn"
            "document.$"      = "$.document"
          }
        }
        ResultPath = "$.BDAResponse"
        Retry      = local.standard_retry
        Next       = "BDA_ProcessResultsStep"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "FailState"
          }
        ]
      }

      BDA_ProcessResultsStep = {
        Type     = "Task"
        Resource = aws_lambda_function.bda_process_results[0].arn
        Parameters = {
          "execution_arn.$" = "$$.Execution.Id"
          "output_bucket"   = local.output_bucket_name
          "BDAResponse.$"   = "$.BDAResponse"
        }
        ResultPath = "$.Result"
        Retry      = local.standard_retry
        Next       = "CheckHITLRequired"
      }

      BDA_ProcessResultsSkip = {
        Type     = "Task"
        Comment  = "Process existing document data without BDA invocation (reprocessing scenario)"
        Resource = aws_lambda_function.bda_process_results[0].arn
        Parameters = {
          "execution_arn.$" = "$$.Execution.Id"
          "output_bucket"   = local.output_bucket_name
          "skip_bda"        = true
          "document.$"      = "$.document"
        }
        ResultPath = "$.Result"
        Retry      = local.standard_retry
        Next       = "CheckHITLRequired"
      }

      FailState = {
        Type  = "Fail"
        Cause = "Workflow Failed"
        Error = "WorkflowFailedException"
      }
    }
  ]...)

  # Assemble the full states map
  sfn_states = merge(
    {
      OCRStep = {
        Type     = "Task"
        Resource = aws_lambda_function.ocr.arn
        Parameters = {
          "execution_arn.$" = "$$.Execution.Id"
          "document.$"      = "$.document"
        }
        ResultPath = "$.OCRResult"
        Retry = [
          {
            ErrorEquals = [
              "Sandbox.Timedout",
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
              "Lambda.TooManyRequestsException",
              "ServiceQuotaExceededException",
              "ThrottlingException",
              "ProvisionedThroughputExceededException",
              "RequestLimitExceeded",
              "ServiceUnavailableException"
            ]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        Next = "ClassificationStep"
      }

      ClassificationStep = {
        Type     = "Task"
        Resource = aws_lambda_function.classification.arn
        Parameters = {
          "execution_arn.$" = "$$.Execution.Id"
          "OCRResult.$"     = "$.OCRResult"
        }
        ResultPath = "$.ClassificationResult"
        Retry      = local.standard_retry
        Next       = "ProcessSections"
      }

      ProcessSections = {
        Type      = "Map"
        ItemsPath = "$.ClassificationResult.document.sections"
        ItemSelector = {
          "execution_arn.$" = "$$.Execution.Id"
          "document.$"      = "$.ClassificationResult.document"
          "section_id.$"    = "$$.Map.Item.Value"
        }
        MaxConcurrency = 10
        Iterator = {
          StartAt = "ExtractionStep"
          States = {
            ExtractionStep = {
              Type     = "Task"
              Resource = aws_lambda_function.extraction.arn
              Retry    = local.standard_retry
              Next     = "AssessmentStep"
            }
            AssessmentStep = {
              Type     = "Task"
              Resource = aws_lambda_function.assessment.arn
              Parameters = {
                "execution_arn.$" = "$$.Execution.Id"
                "document.$"      = "$.document"
                "section_id.$"    = "$.section_id"
              }
              ResultPath = "$"
              Retry      = local.standard_retry
              Next       = "SectionComplete"
            }
            SectionComplete = {
              Type = "Pass"
              End  = true
            }
          }
        }
        ResultPath = "$.ExtractionResults"
        Next       = "ProcessResultsStep"
      }

      ProcessResultsStep = {
        Type     = "Task"
        Resource = aws_lambda_function.process_results.arn
        Parameters = {
          "execution_arn.$"        = "$$.Execution.Id"
          "ClassificationResult.$" = "$.ClassificationResult"
          "ExtractionResults.$"    = "$.ExtractionResults"
        }
        ResultPath = "$.Result"
        Retry      = local.standard_retry
        Next       = "CheckHITLRequired"
      }

      CheckHITLRequired = {
        Type = "Choice"
        Choices = local.hitl_enabled ? [
          {
            Variable      = "$.Result.hitl_triggered"
            BooleanEquals = true
            Next          = "MarkHITLPending"
          }
          ] : [
          {
            Variable      = "$.Result.hitl_triggered"
            BooleanEquals = false
            Next          = local.check_hitl_default
          }
        ]
        Default = local.check_hitl_default
      }

      WorkflowComplete = {
        Type = "Pass"
        End  = true
      }
    },
    local.hitl_states,
    local.summ_states,
    local.eval_states,
    local.bda_states
  )
}

# Wait for the Step Functions IAM role + policy to propagate before
# CreateStateMachine; otherwise AWS fails synchronously with AccessDeniedException
# on the log destination. Same 30s guard as sagemaker-udop-processor/codebuild.
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.state_machine,
    aws_iam_role_policy.state_machine,
    aws_cloudwatch_log_group.state_machine
  ]

  create_duration = "30s"
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "document_processing" {
  depends_on = [time_sleep.wait_for_iam_propagation]

  name     = "${local.name_prefix}-document-processing"
  role_arn = aws_iam_role.state_machine.arn

  definition = jsonencode({
    StartAt = "RouteByProcessingMode"
    States  = local.sfn_states
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = local.common_tags
}

# CloudWatch Log Group for State Machine
resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/vendedlogs/states/${local.name_prefix}-document-processing"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}
