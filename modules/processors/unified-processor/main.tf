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
  # The seeder must run on the same architecture the layers were built for,
  # otherwise idp_common's native deps (pydantic_core) fail to import.
  base_layer_arn       = var.base_layer_arn
  idp_common_layer_arn = var.idp_common_layer_arn
  lambda_architecture  = var.lambda_architecture

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
    # Model keys are YAML-authoritative: written ONLY when the per-step variable
    # is set, so the config library / system defaults are otherwise respected.
    var.classification_model_id != null ? {
      classification = merge(
        try(local.base_config.classification, {}),
        { model = var.classification_model_id }
      )
    } : {},
    # Extraction: model override conditional; the non-model overrides
    # (section_splitting_strategy, agentic) still apply unconditionally.
    {
      extraction = merge(
        try(local.base_config.extraction, {}),
        var.extraction_model_id != null ? { model = var.extraction_model_id } : {},
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
    # Summarization: written only when the variable is set AND the step is
    # enabled, so a disabled step gets no summarization.model key.
    var.summarization_model_id != null && var.is_summarization_enabled ? {
      summarization = merge(
        try(local.base_config.summarization, {}),
        { model = var.summarization_model_id }
      )
    } : {},
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

  # The state after process-results/HITL depends on whether summarization is
  # enabled. When neither summarization nor evaluation runs, the document still
  # has to reach the shared postprocessing tail, and at this point it lives at
  # `$.Result.document` rather than at `$` — hence the wrap state.
  #
  # When evaluation runs WITHOUT summarization we route through
  # NormalizeForEvaluation: EvaluationStep passes `"document.$" = "$"`, which is
  # only the document when arriving from summarization (SummarizationStep sets
  # OutputPath = "$.Result.document"). Arriving straight from CheckHITLRequired,
  # `$` is the full envelope, so the evaluation Lambda would receive the
  # envelope as its document. The normalizer makes both inbound edges agree.
  post_hitl_next = local.summ_enabled ? "SummarizationStep" : (
    local.eval_enabled ? "NormalizeForEvaluation" : "TailWrapResultDocument"
  )

  # The state after summarization depends on whether evaluation is enabled
  post_summ_next = local.eval_enabled ? "EvaluationStep" : "TailWrapSummarizedDocument"

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

  # merge([for ...]...) rather than a ternary: SummarizationStep and
  # PostSummarizationHook are heterogeneously shaped, so a ternary against an
  # empty object fails type unification; the single-element comprehension folds
  # into the populated map (same pattern as the BDA states below).
  summ_states = merge([for _ in(local.summ_enabled ? [1] : []) : {
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
      Next       = "PostSummarizationHook"
    }
    # Pipeline hook: postSummarization. ResultPath null so the summarized
    # document passes through unchanged to the next state.
    PostSummarizationHook = {
      Type     = "Task"
      Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
      Parameters = {
        FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
        Payload = {
          "hookPoint"      = "postSummarization"
          "executionArn.$" = "$$.Execution.Id"
          "document.$"     = "$"
        }
      }
      ResultPath = null
      Retry = [{
        ErrorEquals     = ["Lambda.ServiceException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
        IntervalSeconds = 2
        MaxAttempts     = 3
        BackoffRate     = 2
      }]
      Catch = [{
        ErrorEquals = ["States.ALL"]
        ResultPath  = null
        Next        = local.post_summ_next
      }]
      Next = local.post_summ_next
    }
  }]...)

  # The evaluation Lambda returns {"document": ...}, and ResultPath "$" makes
  # that the whole state payload — already the shape PostprocessingHook reads.
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
      Next       = "PostprocessingHook"
    }
  } : {}

  # ---------------------------------------------------------------------------
  # IDP v0.6 flat hook points: `preprocessing` and `postprocessing`.
  #
  # Unlike the six per-step `<step>.postHook` lists, these are single generic
  # hooks configured as standalone top-level config sections. Both are ALWAYS
  # rendered and are inert until a config version populates the section: the
  # dispatcher returns the inbound document verbatim after one config read.
  # Mirrors sources/patterns/unified/statemachine/workflow.asl.json.
  # ---------------------------------------------------------------------------
  hook_retry = [{
    ErrorEquals     = ["Lambda.ServiceException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
    IntervalSeconds = 2
    MaxAttempts     = 3
    BackoffRate     = 2
  }]

  # merge([for ...]) rather than a ternary: these states are heterogeneously
  # shaped (Task/Pass/Choice/Fail), so a ternary against an empty object fails
  # type unification.
  preprocessing_states = merge([for _ in [1] : {
    # Runs FIRST, before the BDA/pipeline routing decision, so it fires in both
    # processing modes and even when OCR is disabled. A hook may return
    # halt=true to short-circuit this execution (e.g. it spawned a redacted copy
    # that will be processed as its own document).
    #
    # A dispatcher/hook error is deliberately NOT caught to normal routing: a
    # failed preprocessing hook must STOP the execution rather than fall through
    # to processing the un-preprocessed original, which for PII redaction would
    # leak the original.
    PreprocessingHook = {
      Type     = "Task"
      Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
      Parameters = {
        FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
        Payload = {
          "hookPoint"      = "preprocessing"
          "executionArn.$" = "$$.Execution.Id"
          "document.$"     = "$.document"
        }
      }
      ResultPath = "$.HookResults.preprocessing"
      Retry      = local.hook_retry
      Catch = [{
        ErrorEquals = ["States.ALL"]
        ResultPath  = "$.HookResults.preprocessing.error"
        Next        = "PreprocessingHookFailed"
      }]
      Next = "ApplyPreprocessingHookDocument"
    }

    # Copy the (possibly hook-modified) document the dispatcher returned into
    # $.document, which routing and OCR read. The dispatcher ALWAYS returns a
    # document — the inbound one verbatim when no hook modified it — so this is
    # a no-op copy in the common case.
    ApplyPreprocessingHookDocument = {
      Type       = "Pass"
      InputPath  = "$.HookResults.preprocessing.Payload.document"
      ResultPath = "$.document"
      Next       = "CheckPreprocessingHalt"
    }

    PreprocessingHookFailed = {
      Type  = "Fail"
      Error = "PreprocessingHookFailed"
      Cause = "A preprocessing hook failed (e.g. a PII-redaction hook with onError:fail). The execution is stopped rather than continuing to process the un-preprocessed original."
    }

    # The dispatcher always returns a top-level halt flag, so this is safe even
    # with no hook registered (halt=false).
    CheckPreprocessingHalt = {
      Type = "Choice"
      Choices = [{
        Variable      = "$.HookResults.preprocessing.Payload.halt"
        BooleanEquals = true
        Next          = "MarkSupersededByRedacted"
      }]
      Default = "RouteByProcessingMode"
    }

    # Terminal path for a document intentionally not processed further because a
    # preprocessing hook produced a redacted copy. REDACTED_SUPERSEDED is set on
    # the compressed WRAPPER; the workflow tracker preserves it rather than
    # forcing COMPLETED, and deletes the superseded original.
    MarkSupersededByRedacted = {
      Type = "Pass"
      Parameters = {
        "document.$" = "$.document"
      }
      ResultPath = "$"
      Next       = "SetSupersededStatus"
    }

    SetSupersededStatus = {
      Type       = "Pass"
      Result     = "REDACTED_SUPERSEDED"
      ResultPath = "$.document.status"
      Next       = "WorkflowComplete"
    }
  }]...)

  # Shared tail. Every path that used to end at WorkflowComplete now funnels
  # through PostprocessingHook, so it fires in both processing modes. Each
  # inbound edge reaches it with the document in a different place, so the
  # per-edge Pass states below normalize to upstream's `{ document: ... }`
  # envelope first.
  #
  # Unlike PreprocessingHook, a dispatcher/hook error IS caught to the normal
  # terminal state: by this point every expensive step has succeeded and the
  # output objects are written, so a delivery-integration error must not discard
  # a good document. A hook that needs to gate sets onError:fail, which surfaces
  # as a failed execution.
  postprocessing_states = merge(
    merge([for _ in [1] : {
      PostprocessingHook = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
          Payload = {
            "hookPoint"      = "postprocessing"
            "executionArn.$" = "$$.Execution.Id"
            "document.$"     = "$.document"
          }
        }
        ResultPath = "$.HookResults.postprocessing"
        Retry      = local.hook_retry
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = null
          Next        = "WorkflowComplete"
        }]
        Next = "ApplyPostprocessingHookDocument"
      }

      # Rebuild $ as { document: <possibly hook-modified document> }, which
      # becomes the workflow's final output. Parameters + ResultPath "$" rather
      # than InputPath is deliberate: it unwraps the dispatcher result AND drops
      # the temporary $.HookResults key, keeping the output small (Step
      # Functions' 256KB limit) and in the shape the workflow tracker reads.
      ApplyPostprocessingHookDocument = {
        Type = "Pass"
        Parameters = {
          "document.$" = "$.HookResults.postprocessing.Payload.document"
        }
        ResultPath = "$"
        Next       = "WorkflowComplete"
      }
    }]...),

    # Neither summarization nor evaluation ran: the processed document is at
    # $.Result.document (the raw envelope is still $).
    !local.summ_enabled && !local.eval_enabled ? {
      TailWrapResultDocument = {
        Type = "Pass"
        Parameters = {
          "document.$" = "$.Result.document"
        }
        ResultPath = "$"
        Next       = "PostprocessingHook"
      }
    } : {},

    # Summarization ran but evaluation did not: SummarizationStep's OutputPath
    # already reduced $ to the bare document.
    local.summ_enabled && !local.eval_enabled ? {
      TailWrapSummarizedDocument = {
        Type = "Pass"
        Parameters = {
          "document.$" = "$"
        }
        ResultPath = "$"
        Next       = "PostprocessingHook"
      }
    } : {},

    # Evaluation runs without summarization: reduce the envelope to the bare
    # document so EvaluationStep's `"document.$" = "$"` means the same thing on
    # both of its inbound edges.
    local.eval_enabled && !local.summ_enabled ? {
      NormalizeForEvaluation = {
        Type      = "Pass"
        InputPath = "$.Result.document"
        Next      = "EvaluationStep"
      }
    } : {}
  )

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
        Next = "PostOcrHook"
      }

      # Pipeline hook: postOcr. Inert unless the active config defines
      # ocr.postHook. Catch-all so a hook failure never breaks the pipeline.
      PostOcrHook = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
          Payload = {
            "hookPoint"      = "postOcr"
            "executionArn.$" = "$$.Execution.Id"
            "document.$"     = "$.OCRResult.document"
          }
        }
        ResultPath = "$.HookResults.postOcr"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.HookResults.postOcr.error"
          Next        = "ClassificationStep"
        }]
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
        Next       = "PostClassificationHook"
      }

      # Pipeline hook: postClassification. Inert unless the active config
      # defines classification.postHook.
      PostClassificationHook = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
          Payload = {
            "hookPoint"      = "postClassification"
            "executionArn.$" = "$$.Execution.Id"
            "document.$"     = "$.ClassificationResult.document"
          }
        }
        ResultPath = "$.HookResults.postClassification"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.HookResults.postClassification.error"
          Next        = "ProcessSections"
        }]
        Next = "ProcessSections"
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
              Next     = "PostExtractionHook"
            }
            # Pipeline hook: postExtraction (per-section, inside the Map).
            PostExtractionHook = {
              Type     = "Task"
              Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
              Parameters = {
                FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
                Payload = {
                  "hookPoint"      = "postExtraction"
                  "executionArn.$" = "$$.Execution.Id"
                  "document.$"     = "$.document"
                  "section_id.$"   = "$.section_id"
                }
              }
              ResultPath = "$.HookResults.postExtraction"
              Retry = [{
                ErrorEquals     = ["Lambda.ServiceException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
                IntervalSeconds = 2
                MaxAttempts     = 3
                BackoffRate     = 2
              }]
              Catch = [{
                ErrorEquals = ["States.ALL"]
                ResultPath  = "$.HookResults.postExtraction.error"
                Next        = "AssessmentStep"
              }]
              Next = "AssessmentStep"
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
              Next       = "PostAssessmentHook"
            }
            # Pipeline hook: postAssessment (per-section, inside the Map).
            PostAssessmentHook = {
              Type     = "Task"
              Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
              Parameters = {
                FunctionName = aws_lambda_function.pipeline_hooks_dispatcher.arn
                Payload = {
                  "hookPoint"      = "postAssessment"
                  "executionArn.$" = "$$.Execution.Id"
                  "document.$"     = "$.document"
                }
              }
              ResultPath = "$.HookResults.postAssessment"
              Retry = [{
                ErrorEquals     = ["Lambda.ServiceException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
                IntervalSeconds = 2
                MaxAttempts     = 3
                BackoffRate     = 2
              }]
              Catch = [{
                ErrorEquals = ["States.ALL"]
                ResultPath  = "$.HookResults.postAssessment.error"
                Next        = "SectionComplete"
              }]
              Next = "SectionComplete"
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
    local.bda_states,
    local.preprocessing_states,
    local.postprocessing_states
  )

  # Every state name referenced as a transition target by a top-level state
  # (Next, Choice.Next, Choices[*].Next, Catch[*].Next, Default). Exposed as an
  # output so `terraform test` can prove the graph is closed — no state points at
  # a name that the current summarization/evaluation/HITL combination did not
  # render. Step Functions only reports that at CreateStateMachine time, which is
  # far too late. Derived purely from literal names, so it is known at plan.
  sfn_transition_targets = distinct(compact(concat(
    [for name, state in local.sfn_states : try(state.Next, "")],
    [for name, state in local.sfn_states : try(state.Default, "")],
    flatten([for name, state in local.sfn_states : [
      for choice in try(state.Choices, []) : try(choice.Next, "")
    ]]),
    flatten([for name, state in local.sfn_states : [
      for catcher in try(state.Catch, []) : try(catcher.Next, "")
    ]]),
  )))
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

  # StartAt is PreprocessingHook, not RouteByProcessingMode: the v0.6
  # preprocessing extension point runs before the BDA/pipeline routing decision
  # so it fires in both modes. It is inert until a config version populates the
  # `preprocessing` section.
  definition = jsonencode({
    StartAt = "PreprocessingHook"
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
