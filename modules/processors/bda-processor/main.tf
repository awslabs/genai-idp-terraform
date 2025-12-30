# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # BDA Processor Module
 *
 * This module implements the BDA document processor using Amazon Bedrock Data Automation.
 * It provides a managed solution for extracting structured data from documents with
 * minimal custom code.
 * 
 * This implementation matches the AWS CDK approach by reading configuration from the
 * config.yaml file and allowing model overrides through variables.
 */

data "aws_region" "current" {}

# Local variables to extract resource names from ARNs
locals {
  # Extract resource names from ARNs
  # S3 bucket names (format: arn:${data.aws_partition.current.partition}:s3:::bucket-name)

  output_bucket_name  = element(split(":", var.output_bucket_arn), 5)
  working_bucket_name = element(split(":", var.working_bucket_arn), 5)

  # DynamoDB table names (format: arn:${data.aws_partition.current.partition}:dynamodb:region:account:table/table-name)
  configuration_table_name = element(split("/", var.configuration_table_arn), 1)
  tracking_table_name      = element(split("/", var.tracking_table_arn), 1)


  # KMS key (format: arn:${data.aws_partition.current.partition}:kms:region:account:key/key-id)
  encryption_key_id = var.encryption_key_arn != null ? element(split("/", var.encryption_key_arn), 1) : null

  # VPC config
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null
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

# Configuration logic (moved from configuration/definition.tf)
locals {
  # Use the config passed from parent module (from sources/config_library/)
  base_config = var.config

  # Apply model overrides if provided, similar to CDK transforms
  config_with_overrides = merge(
    local.base_config,
    # Only override evaluation if evaluation_model_id is provided
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
    # Only override summarization if summarization_model_id is provided
    var.summarization_model_id != null ? {
      summarization = merge(
        local.base_config.summarization,
        {
          model = var.summarization_model_id
        }
      )
    } : {}
  )
}

# Local function to filter out relative path references from requirements.txt
locals {
  # Filter out empty requirements files
  clean_requirements = {
    bda_invoke_function = fileexists("${path.module}/../../../sources/patterns/pattern-1/src/bda_invoke_function/requirements.txt") ? join("\n", [
      for line in split("\n", file("${path.module}/../../../sources/patterns/pattern-1/src/bda_invoke_function/requirements.txt")) :
      line if !can(regex("^\\s*\\.+/", line)) && !can(regex("idp_common_pkg", line)) && trimspace(line) != "" && !startswith(trimspace(line), "#")
    ]) : ""
    bda_completion_function = fileexists("${path.module}/../../../sources/patterns/pattern-1/src/bda_completion_function/requirements.txt") ? join("\n", [
      for line in split("\n", file("${path.module}/../../../sources/patterns/pattern-1/src/bda_completion_function/requirements.txt")) :
      line if !can(regex("^\\s*\\.+/", line)) && !can(regex("idp_common_pkg", line)) && trimspace(line) != "" && !startswith(trimspace(line), "#")
    ]) : ""
    processresults_function = fileexists("${path.module}/../../../sources/patterns/pattern-1/src/processresults_function/requirements.txt") ? join("\n", [
      for line in split("\n", file("${path.module}/../../../sources/patterns/pattern-1/src/processresults_function/requirements.txt")) :
      line if !can(regex("^\\s*\\.+/", line)) && !can(regex("idp_common_pkg", line)) && trimspace(line) != "" && !startswith(trimspace(line), "#")
    ]) : ""
  }

  # Filter out empty requirements files
  requirements_files = {
    for k, v in local.clean_requirements : k => v if trimspace(v) != "" && length(split("\n", trimspace(v))) > 0
  }
}

# Create Lambda layers for functions with external dependencies
module "lambda_layers" {
  source = "../../lambda-layer-codebuild"

  name_prefix              = "bda-processor-${random_string.suffix.result}"
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn

  requirements_files = local.requirements_files

  # Calculate hash of all cleaned requirements files to use as trigger
  requirements_hash = md5(join("", [
    for k, v in local.requirements_files : v
  ]))

  # Don't force rebuild unless requirements change
  force_rebuild = false

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Determine if summarization is enabled based on config.yaml or variable override
locals {
  # Read config.yaml to check if summarization model is defined
  config_yaml_content = file("${path.module}/../../../sources/config_library/pattern-1/lending-package-sample/config.yaml")
  config_yaml_parsed  = yamldecode(local.config_yaml_content)

  # Summarization is enabled if either:
  # 1. A summarization_model_id variable is provided, OR
  # 2. The config.yaml has a summarization.model defined
  is_summarization_enabled = var.summarization_model_id != null || can(local.config_yaml_parsed.summarization.model)
}

# Create the Step Functions state machine for document processing
resource "aws_sfn_state_machine" "document_processing" {
  name     = "${var.name}-state-machine-${random_string.suffix.result}"
  role_arn = aws_iam_role.state_machine_role.arn

  definition = templatefile("${path.module}/../../../sources/patterns/pattern-1/statemachine/workflow.asl.json", {
    InvokeBDALambdaArn          = aws_lambda_function.invoke_bda.arn
    ProcessResultsLambdaArn     = aws_lambda_function.process_results.arn
    HITLWaitFunctionArn         = aws_lambda_function.hitl_wait.arn
    HITLStatusUpdateFunctionArn = aws_lambda_function.hitl_status_update.arn
    IsSummarizationEnabled      = local.is_summarization_enabled ? "true" : "false"
    SummarizationLambdaArn      = aws_lambda_function.summarization.arn
    OutputBucket                = local.output_bucket_name
    WorkingBucket               = local.working_bucket_name
    BDAProjectArn               = var.data_automation_project_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  # Ensure IAM policy attachment is complete before creating the state machine
  depends_on = [
    aws_iam_role_policy_attachment.state_machine_policy_attachment
  ]

  tags = var.tags
}

# CloudWatch Log Group for Step Functions state machine
resource "aws_cloudwatch_log_group" "state_machine_logs" {
  name              = "/aws/vendedlogs/states/${var.name}-state-machine-${random_string.suffix.result}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Attach the processor to the processing environment
# This is done by creating the necessary event rules and permissions
# to connect the processor to the processing environment

# EventBridge rule for BDA events
resource "aws_cloudwatch_event_rule" "bda_event_rule" {
  name        = "${var.name}-bda-event-rule-${random_string.suffix.result}"
  description = "Rule for Bedrock Data Automation events"

  event_pattern = jsonencode({
    source = ["aws.bedrock"]
    "detail-type" = [
      "Bedrock Data Automation Job Succeeded",
      "Bedrock Data Automation Job Failed With Client Error",
      "Bedrock Data Automation Job Failed With Service Error"
    ]
  })

  tags = var.tags
}

# EventBridge target for BDA events
resource "aws_cloudwatch_event_target" "bda_event_target" {
  rule      = aws_cloudwatch_event_rule.bda_event_rule.name
  target_id = "SendToBDACompletionFunction"
  arn       = aws_lambda_function.bda_completion.arn

  retry_policy {
    maximum_event_age_in_seconds = 7200 # 2 hours
    maximum_retry_attempts       = 3
  }
}

# Lambda permission for EventBridge to invoke BDA completion function
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_bda_completion" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bda_completion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bda_event_rule.arn
}

# Create evaluation function and rule if evaluation baseline bucket is provided
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_cloudwatch_event_rule" "evaluation_function_rule" {
#   count       = var.evaluation_baseline_bucket != null ? 1 : 0
#   name        = "${var.name}-evaluation-function-rule-${random_string.suffix.result}"
#   description = "Rule for triggering evaluation function on successful document processing"
# 
#   event_pattern = jsonencode({
#     source        = ["aws.states"]
#     "detail-type" = ["Step Functions Execution Status Change"]
#     detail = {
#       stateMachineArn = {
#         name = [aws_sfn_state_machine.document_processing.arn]
#       }
#       status = ["SUCCEEDED"]
#     }
#   })
# 
#   tags = var.tags
# }

# resource "aws_cloudwatch_event_target" "evaluation_function_target" {
#   count     = var.evaluation_baseline_bucket != null ? 1 : 0
#   rule      = aws_cloudwatch_event_rule.evaluation_function_rule[0].name
#   target_id = "SendToEvaluationFunction"
#   arn       = aws_lambda_function.evaluation[0].arn
# }

# resource "aws_lambda_permission" "allow_eventbridge_to_invoke_evaluation" {
#   count         = var.evaluation_baseline_bucket != null ? 1 : 0
#   statement_id  = "AllowExecutionFromEventBridge"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.evaluation[0].function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.evaluation_function_rule[0].arn
# }
