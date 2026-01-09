# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "name_prefix" {
  description = "Name prefix used for all resources"
  value       = local.name_prefix
}

output "assets_bucket" {
  description = "Shared assets bucket information"
  value = {
    bucket_name = module.assets_bucket.bucket_name
    bucket_arn  = module.assets_bucket.bucket_arn
  }
}

output "user_identity" {
  description = "User identity resources"
  value = {
    user_pool_id        = local.user_pool_id
    user_pool_client_id = local.user_pool_client_id
    identity_pool_id    = local.identity_pool_id
  }
}

output "api" {
  description = "API resources (if enabled)"
  value = local.api_enabled ? {
    api_id      = module.processing_environment_api[0].api_id
    graphql_url = module.processing_environment_api[0].graphql_url
  } : null
}

output "web_ui" {
  description = "Web UI resources (if enabled)"
  value = var.web_ui.enabled ? {
    cloudfront_distribution_id = module.web_ui[0].cloudfront_distribution_id
    bucket                     = module.web_ui[0].bucket
    url                        = module.web_ui[0].application_url
  } : null
}

output "processor_type" {
  description = "Type of document processor used"
  value       = local.processor_type
}

locals {
  # Base processor configuration shared across all types
  base_processor_config = {
    queue_processor_arn     = try(module.processor_attachment[0].queue_processor.function_arn, null)
    queue_sender_arn        = module.processing_environment.queue_sender_function_arn
    evaluation_function_arn = try(module.processor_attachment[0].evaluation_function.function_arn, null)
  }

  # Processor-specific configurations
  processor_modules = {
    bedrock-llm    = try(module.bedrock_llm_processor[0], null)
    bda            = try(module.bda_processor[0], null)
    sagemaker-udop = try(module.sagemaker_udop_processor[0], null)
  }

  # Combined processor details
  processor_details = {
    for type, module_ref in local.processor_modules : type => merge(
      local.base_processor_config,
      {
        type               = type
        state_machine_arn  = try(module_ref.state_machine_arn, null)
        state_machine_name = try(module_ref.state_machine_name, null)
      }
    ) if module_ref != null
  }
}

output "processor" {
  description = "Document processor details"
  value       = lookup(local.processor_details, local.processor_type, null)
}

output "agent_analytics" {
  description = "Agent analytics resources (if enabled)"
  value = local.agent_analytics_config.enabled && var.reporting.enabled && local.api_enabled ? {
    agent_table_name                   = module.processing_environment_api[0].agent_table_name
    agent_table_arn                    = module.processing_environment_api[0].agent_table_arn
    agent_request_handler_function_arn = module.processing_environment_api[0].agent_request_handler_function_arn
    agent_processor_function_arn       = module.processing_environment_api[0].agent_processor_function_arn
    list_available_agents_function_arn = module.processing_environment_api[0].list_available_agents_function_arn
  } : null
}

output "processing_environment" {
  description = "Processing environment resources"
  value = {
    configuration_table_arn = module.processing_environment.configuration_table_arn
    tracking_table_arn      = module.processing_environment.tracking_table_arn
    concurrency_table_arn   = module.processing_environment.concurrency_table_arn
    document_queue_arn      = module.processing_environment.document_queue_arn
    input_bucket_name       = module.processing_environment.input_bucket_name
    output_bucket_name      = module.processing_environment.output_bucket_name
    workflow_tracker_arn    = module.processing_environment.workflow_tracker_function_arn
  }
}
