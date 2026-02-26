# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Bedrock LLM Processor
# This processor implements an intelligent document processing workflow that uses Amazon Bedrock
# with Nova or Claude models for both page classification/grouping and information extraction.
#
# Note: The deprecated nested 'processing_environment' variable has been removed.
# All resources now use flat variables directly, following Terraform best practices.

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  name_prefix = var.name

  # Use flat variables directly
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
  # Format for S3 bucket ARN: arn:${data.aws_partition.current.partition}:s3:::bucket-name
  input_bucket_name   = element(split(":", local.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", local.output_bucket_arn), 5)
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # DynamoDB table names (format: arn:${data.aws_partition.current.partition}:dynamodb:region:account:table/table-name)
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
  # Format for KMS key ARN: arn:${data.aws_partition.current.partition}:kms:region:account-id:key/key-id
  encryption_key_id = local.encryption_key_arn != null ? element(split("/", local.encryption_key_arn), 1) : null

  # Build directory and instance ID for Lambda functions
  module_build_dir   = "${path.module}/build"
  module_instance_id = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"

  # Common tags
  common_tags = merge(var.tags, {
    Component = "BedrockLlmProcessor"
  })
}

# Create the configuration components using the processor-configuration module
module "processor_configuration" {
  source = "../../processor-configuration"

  name_prefix              = var.name
  configuration_table_name = local.configuration_table_name
  encryption_key_arn       = var.encryption_key_arn

  # Use the config passed from parent module (from config_library YAML files)
  configuration = local.config_with_overrides
  schema        = jsondecode(file("${path.module}/schema.json"))

  vpc_config          = local.vpc_config
  lambda_tracing_mode = var.lambda_tracing_mode
  tags                = var.tags
}

# Configuration logic (moved from configuration/main.tf)
locals {
  # Use the config passed from parent module (from sources/config_library/)
  base_config = var.config

  # Apply model overrides if provided, similar to CDK transforms
  config_with_overrides = merge(
    local.base_config,
    # Only override classification model if provided
    var.classification_model_id != null ? {
      classification = merge(
        local.base_config.classification,
        {
          model = var.classification_model_id
        }
      )
    } : {},
    # Override extraction: model, section_splitting_strategy, agentic extraction, review_agent_model
    {
      extraction = merge(
        local.base_config.extraction,
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
    # Only override summarization model if provided
    var.summarization_model_id != null ? {
      summarization = merge(
        local.base_config.summarization,
        {
          model = var.summarization_model_id
        }
      )
    } : {},
    # Only override evaluation model if provided
    var.evaluation_model_id != null ? {
      evaluation = merge(
        local.base_config.evaluation,
        {
          llm_method = merge(
            local.base_config.evaluation.llm_method,
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
        local.base_config.assessment,
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
  hitl_enabled       = var.enable_hitl
  summ_enabled       = var.is_summarization_enabled
  eval_enabled       = var.evaluation_enabled && var.evaluation_baseline_bucket_arn != null

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

  # The state after ProcessResultsStep / HITLStatusUpdate depends on whether summarization is enabled
  post_hitl_next = local.summ_enabled ? "SummarizationStep" : (local.eval_enabled ? "EvaluationStep" : "WorkflowComplete")

  # The state after SummarizationStep depends on whether evaluation is enabled
  post_summ_next = local.eval_enabled ? "EvaluationStep" : "WorkflowComplete"

  # CheckHITLRequired default (when HITL not triggered) — same logic as post_hitl_next
  check_hitl_default = local.post_hitl_next

  # Build the optional states map entries
  hitl_states = local.hitl_enabled ? {
    HITLReview = {
      Type     = "Task"
      Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
      Parameters = {
        FunctionName    = aws_lambda_function.hitl_wait[0].arn
        "Payload" = {
          "taskToken.$" = "$.Task.Token"
          "Payload.$"   = "$"
        }
      }
      ResultPath = "$.HITLWaitResult"
      Retry      = local.standard_retry
      Next       = "HITLStatusUpdate"
    }
    HITLStatusUpdate = {
      Type     = "Task"
      Resource = aws_lambda_function.hitl_status_update[0].arn
      Parameters = {
        "Result.$"         = "$.Result"
        "HITLWaitResult.$" = "$.HITLWaitResult"
      }
      ResultPath = "$.HITLStatusResult"
      Retry      = local.standard_retry
      Next       = local.post_hitl_next
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
            Next          = "HITLReview"
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
    local.eval_states
  )
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "document_processing" {
  name     = "${local.name_prefix}-document-processing"
  role_arn = aws_iam_role.state_machine.arn

  definition = jsonencode({
    StartAt = "OCRStep"
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
