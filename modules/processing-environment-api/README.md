## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_agent_analytics"></a> [agent\_analytics](#module\_agent\_analytics) | ./agent-analytics | n/a |
| <a name="module_chat_stream_deps_layer"></a> [chat\_stream\_deps\_layer](#module\_chat\_stream\_deps\_layer) | ../lambda-layer-codebuild | n/a |
| <a name="module_discovery"></a> [discovery](#module\_discovery) | ./discovery | n/a |
| <a name="module_process_changes"></a> [process\_changes](#module\_process\_changes) | ./process-changes | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_account) | resource |
| [aws_api_gateway_authorizer.cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_authorizer) | resource |
| [aws_api_gateway_deployment.http_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_gateway_response.default_4xx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_gateway_response) | resource |
| [aws_api_gateway_gateway_response.default_5xx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_gateway_response) | resource |
| [aws_api_gateway_integration.op_options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration.op_post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration.web_ui_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration.web_ui_root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration_response.op_options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_integration_response.web_ui_proxy_200](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_integration_response.web_ui_proxy_404](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_integration_response.web_ui_proxy_500](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_integration_response.web_ui_root_200](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_integration_response.web_ui_root_404](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_integration_response.web_ui_root_500](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_method.op_options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method.op_post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method.web_ui_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method.web_ui_root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_response.op_options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_response.web_ui_proxy_200](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_response.web_ui_proxy_404](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_response.web_ui_proxy_500](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_response.web_ui_root_200](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_response.web_ui_root_404](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_response.web_ui_root_500](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_settings.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_resource.op](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.op_field](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.web_ui_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.http_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudformation_stack.fcc_dataset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_cloudformation_stack.w2_dataset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_cloudwatch_log_group.abort_workflow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agent_chat_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agent_chat_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agent_chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.agent_chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.api_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.calculate_capacity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.calculate_capacity_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.chat_stream_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.complete_section_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.create_chat_session_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.delete_agent_chat_session_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.delete_tests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.docsplit_testset_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.fcc_dataset_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_deployment_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_job_creator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_job_status_checker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_jobs_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_list_documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_merge_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_pd_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_pd_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_process_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.finetuning_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.get_agent_chat_messages_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.http_api_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.list_agent_chat_sessions_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.ocr_benchmark_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.sync_bda_idp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_execution_aggregation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_file_copier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_results_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_runner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_set_file_copier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_set_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.test_set_zip_extractor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.version_check_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.w2_dataset_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_codebuild_project.agent_chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_codebuild_project.finetuning_process_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_dynamodb_table.agent_chat_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.agent_chat_messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.agent_chat_sessions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.test_sets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.configuration_resolver_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.copy_to_baseline_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.copy_to_baseline_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.copy_to_baseline_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.copy_to_baseline_resolver_self_invoke_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.copy_to_baseline_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.delete_document_resolver_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.delete_document_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.delete_document_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.delete_document_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.delete_document_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_file_contents_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_file_contents_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_file_contents_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_file_contents_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_stepfunction_execution_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_stepfunction_execution_resolver_stepfunctions_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.get_stepfunction_execution_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_bedrock_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_sqs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.abort_workflow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agent_chat_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agent_chat_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agent_chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.agent_chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.api_gateway_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.bedrock_finetuning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.capacity_planning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.chat_session_resolvers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.chat_stream_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.complete_section_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.configuration_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.copy_to_baseline_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dataset_deployers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.delete_document_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_deployment_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_job_creator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_job_status_checker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_jobs_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_list_documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_merge_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_pd_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_pd_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_process_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.finetuning_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.get_file_contents_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.get_stepfunction_execution_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.http_api_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.query_knowledge_base_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.reprocess_document_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sync_bda_idp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.test_studio_lambdas](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.upload_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.version_check_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.web_ui_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.abort_workflow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_chat_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_chat_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.bedrock_finetuning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.capacity_planning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.chat_session_resolvers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.chat_stream_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.complete_section_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.configuration_resolver_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dataset_deployers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.feature_contracts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_deployment_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_job_creator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_job_status_checker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_jobs_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_list_documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_merge_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_pd_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_pd_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_process_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.finetuning_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.http_api_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.sync_bda_idp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.test_studio_lambdas](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.version_check_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.web_ui_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.abort_workflow_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.abort_workflow_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_chat_codebuild_vpc_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_chat_processor_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_chat_processor_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.agent_chat_resolver_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.api_gateway_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.capacity_planning_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.capacity_planning_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.chat_session_resolvers_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.chat_stream_processor_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.chat_stream_processor_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.complete_section_review_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.complete_section_review_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_self_invoke_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.dataset_deployers_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.dataset_deployers_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.document_resolver_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.document_resolver_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.finetuning_pd_codebuild_vpc_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_stepfunctions_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.http_api_dispatcher_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_bedrock_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_sqs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sync_bda_idp_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sync_bda_idp_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.test_studio_lambdas_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.test_studio_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.test_file_copy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.test_result_cache_update](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.test_set_copy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.abort_workflow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.agent_chat_cb_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.agent_chat_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.agent_chat_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.calculate_capacity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.calculate_capacity_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.chat_stream_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.complete_section_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.configuration_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.copy_to_baseline_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.create_chat_session_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.delete_agent_chat_session_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.delete_document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.delete_tests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.docsplit_testset_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.fcc_dataset_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_deployment_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_job_creator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_job_status_checker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_jobs_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_list_documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_merge_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_pd_cb_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.finetuning_process_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.get_agent_chat_messages_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.get_file_contents_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.get_stepfunction_execution_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.http_api_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.list_agent_chat_sessions_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.ocr_benchmark_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.query_knowledge_base_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.reprocess_document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.sync_bda_idp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_execution_aggregation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_file_copier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_results_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_runner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_set_file_copier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_set_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.test_set_zip_extractor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.upload_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.version_check_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.w2_dataset_deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function_url.chat_stream](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) | resource |
| [aws_lambda_invocation.agent_chat_trigger_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.finetuning_pd_trigger_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_permission.chat_stream_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.http_api_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket.finetuning_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.test_sets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.finetuning_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.finetuning_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.finetuning_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.test_sets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.finetuning_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.test_sets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.finetuning_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.test_sets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.agent_chat_cb_idp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.agent_chat_cb_src](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.chat_stream_package](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.finetuning_pd_cb_idp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.finetuning_pd_cb_src](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_sfn_state_machine.finetuning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_sqs_queue.test_file_copy_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.test_file_copy_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.test_result_cache_update_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.test_result_cache_update_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.test_set_copy_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.test_set_copy_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_ssm_parameter.http_api_field_function_map](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_wafv2_ip_set.api_allow_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_web_acl.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [null_resource.agent_chat_cb_test_iam_permissions](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.build_agent_chat_processor](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.agent_chat_cb_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.agent_chat_cb_trigger_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.chat_stream_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.finetuning_pd_cb_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.finetuning_pd_cb_trigger_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.abort_workflow](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.agent_chat_cb_idp](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.agent_chat_cb_src](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.agent_chat_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.agent_chat_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.calculate_capacity](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.calculate_capacity_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.chat_stream_package](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.complete_section_review](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.configuration_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.copy_to_baseline_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.create_chat_session_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.delete_agent_chat_session_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.delete_document_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.delete_tests](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.docsplit_testset_deployer](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.document_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.fcc_dataset_deployer](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_deployment_handler](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_job_creator](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_job_status_checker](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_jobs_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_list_documents](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_merge_data](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_pd_cb_idp](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_pd_cb_src](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.finetuning_pd_cb_trigger_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.get_agent_chat_messages_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.get_file_contents_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.get_stepfunction_execution_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.http_api_dispatcher](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.list_agent_chat_sessions_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.ocr_benchmark_deployer](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.query_knowledge_base_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.reprocess_document_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.sync_bda_idp](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_execution_aggregation](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_file_copier](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_results_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_runner](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_set_file_copier](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_set_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.test_set_zip_extractor](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.upload_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.version_check_resolver](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.w2_dataset_deployer](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [local_file.agent_chat_processor_hash](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_analytics"></a> [agent\_analytics](#input\_agent\_analytics) | Agent analytics configuration | <pre>object({<br>    enabled                   = bool<br>    model_id                  = optional(string, "us.anthropic.claude-sonnet-4-5-20250929-v1:0")<br>    reporting_database_name   = optional(string)<br>    reporting_bucket_arn      = optional(string)<br>    allowed_bedrock_model_ids = optional(list(string), [])<br>  })</pre> | <pre>{<br>  "enabled": false<br>}</pre> | no |
| <a name="input_agents_layer_arn"></a> [agents\_layer\_arn](#input\_agents\_layer\_arn) | ARN of the IDP agents (strands) Lambda layer. Required by the chat token-streaming Function URL processor, which imports both processor modules (base + agents). Wired from module.idp\_agents\_layer.layer\_arn at the root. | `string` | `null` | no |
| <a name="input_api_gateway_vpc_endpoint_id"></a> [api\_gateway\_vpc\_endpoint\_id](#input\_api\_gateway\_vpc\_endpoint\_id) | VPC interface endpoint id for execute-api. Required when visibility=PRIVATE — the REST API becomes a PRIVATE endpoint reachable only through this VPC endpoint, with a matching resource policy restricting aws:SourceVpce. Empty (default) for a REGIONAL (public, Cognito-authorized) endpoint. | `string` | `""` | no |
| <a name="input_authorization_config"></a> [authorization\_config](#input\_authorization\_config) | Authorization configuration for the GraphQL API. Must be set explicitly; the module no longer defaults to API\_KEY because that exposes every mutation to anyone with the key. | <pre>object({<br>    default_authorization = object({<br>      authorization_type = string<br>      user_pool_config = optional(object({<br>        user_pool_id        = string<br>        app_id_client_regex = optional(string)<br>        aws_region          = optional(string)<br>        default_action      = optional(string, "ALLOW")<br>      }))<br>      openid_connect_config = optional(object({<br>        auth_ttl  = optional(number)<br>        client_id = optional(string)<br>        iat_ttl   = optional(number)<br>        issuer    = string<br>      }))<br>      lambda_authorizer_config = optional(object({<br>        authorizer_result_ttl_seconds  = optional(number)<br>        authorizer_uri                 = string<br>        identity_validation_expression = optional(string)<br>      }))<br>    })<br>    additional_authorization_modes = optional(list(object({<br>      authorization_type = string<br>      user_pool_config = optional(object({<br>        user_pool_id        = string<br>        app_id_client_regex = optional(string)<br>        aws_region          = optional(string)<br>        default_action      = optional(string, "ALLOW")<br>      }))<br>      openid_connect_config = optional(object({<br>        auth_ttl  = optional(number)<br>        client_id = optional(string)<br>        iat_ttl   = optional(number)<br>        issuer    = string<br>      }))<br>      lambda_authorizer_config = optional(object({<br>        authorizer_result_ttl_seconds  = optional(number)<br>        authorizer_uri                 = string<br>        identity_validation_expression = optional(string)<br>      }))<br>    })))<br>  })</pre> | `null` | no |
| <a name="input_base_layer_arn"></a> [base\_layer\_arn](#input\_base\_layer\_arn) | ARN of the base Lambda layer containing shared Python dependencies (from processing-environment module) | `string` | `null` | no |
| <a name="input_bda_project_arn"></a> [bda\_project\_arn](#input\_bda\_project\_arn) | ARN of the BDA Data Automation Project (used by sync\_bda\_idp resolver). Leave empty if not using BDA processor. | `string` | `""` | no |
| <a name="input_chat_with_document"></a> [chat\_with\_document](#input\_chat\_with\_document) | Chat with Document functionality configuration | <pre>object({<br>    enabled                  = bool<br>    guardrail_id_and_version = optional(string, null)<br>  })</pre> | <pre>{<br>  "enabled": false<br>}</pre> | no |
| <a name="input_configuration_table"></a> [configuration\_table](#input\_configuration\_table) | The DynamoDB table for storing configuration settings (Legacy format - use configuration\_table\_arn instead) | <pre>object({<br>    table_name = string<br>    table_arn  = string<br>  })</pre> | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table for storing configuration settings | `string` | `null` | no |
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Container runtime for local builds (auto\|docker\|podman\|finch). | `string` | `"auto"` | no |
| <a name="input_data_retention_in_days"></a> [data\_retention\_in\_days](#input\_data\_retention\_in\_days) | Data retention period in days for processed documents | `number` | `7` | no |
| <a name="input_discovery"></a> [discovery](#input\_discovery) | Discovery workflow configuration | <pre>object({<br>    enabled = bool<br>  })</pre> | <pre>{<br>  "enabled": false<br>}</pre> | no |
| <a name="input_discovery_allowed_cors_origins"></a> [discovery\_allowed\_cors\_origins](#input\_discovery\_allowed\_cors\_origins) | Allowed CORS origins for the discovery upload bucket (the web-UI / CloudFront app origin). Empty falls back to ["*"] (Wiz S3-036). | `list(string)` | `[]` | no |
| <a name="input_document_queue_arn"></a> [document\_queue\_arn](#input\_document\_queue\_arn) | ARN of the SQS queue for document processing (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_document_queue_url"></a> [document\_queue\_url](#input\_document\_queue\_url) | URL of the SQS queue for document processing (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name configuration for the GraphQL API | <pre>object({<br>    certificate_arn = string<br>    domain_name     = string<br>  })</pre> | `null` | no |
| <a name="input_enable_agent_companion_chat"></a> [enable\_agent\_companion\_chat](#input\_enable\_agent\_companion\_chat) | Enable Agent Companion Chat feature (multi-agent AI chat sessions) | `bool` | `true` | no |
| <a name="input_enable_capacity_planning"></a> [enable\_capacity\_planning](#input\_enable\_capacity\_planning) | Enable Capacity Planning feature (v0.4.13+). Deploys calculate\_capacity and calculate\_capacity\_resolver Lambdas. | `bool` | `false` | no |
| <a name="input_enable_docplit_poly_seq_dataset"></a> [enable\_docplit\_poly\_seq\_dataset](#input\_enable\_docplit\_poly\_seq\_dataset) | Enable DocSplit RVL-CDIP-NMP Packet dataset deployer (v0.4.15+). Requires enable\_test\_studio = true. | `bool` | `false` | no |
| <a name="input_enable_edit_sections"></a> [enable\_edit\_sections](#input\_enable\_edit\_sections) | Whether to enable the Edit Sections feature for selective reprocessing | `bool` | `false` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Enable encryption for resources | `bool` | `true` | no |
| <a name="input_enable_error_analyzer"></a> [enable\_error\_analyzer](#input\_enable\_error\_analyzer) | DEPRECATED (no-op as of v0.5.12). The standalone Error Analyzer Lambdas were removed upstream; error analysis is now provided by the unified agents framework (Error-Analyzer-Agent via the agent resolvers). Retained for backward compatibility; setting it has no effect. | `bool` | `false` | no |
| <a name="input_enable_fcc_dataset"></a> [enable\_fcc\_dataset](#input\_enable\_fcc\_dataset) | Enable FCC dataset deployer (deploys sample FCC dataset for Test Studio) | `bool` | `false` | no |
| <a name="input_enable_finetuning"></a> [enable\_finetuning](#input\_enable\_finetuning) | Enable fine-tuning / Custom Models subsystem (Bedrock model customization from Test Studio test sets). Requires enable\_test\_studio = true. | `bool` | `false` | no |
| <a name="input_enable_hitl"></a> [enable\_hitl](#input\_enable\_hitl) | Enable built-in HITL review via complete\_section\_review Lambda (v0.4.9+). Replaces SageMaker A2I. | `bool` | `true` | no |
| <a name="input_enable_omni_ai_dataset"></a> [enable\_omni\_ai\_dataset](#input\_enable\_omni\_ai\_dataset) | Enable OmniAI OCR Benchmark dataset deployer (v0.4.15+). Requires enable\_test\_studio = true. | `bool` | `false` | no |
| <a name="input_enable_test_studio"></a> [enable\_test\_studio](#input\_enable\_test\_studio) | Enable Test Studio feature (automated dataset testing) | `bool` | `true` | no |
| <a name="input_enable_w2_dataset"></a> [enable\_w2\_dataset](#input\_enable\_w2\_dataset) | Enable W2 dataset deployer (deploys the Fake W-2 Tax Form sample dataset for Test Studio). Requires enable\_test\_studio = true. | `bool` | `false` | no |
| <a name="input_enabled_feature_contracts"></a> [enabled\_feature\_contracts](#input\_enabled\_feature\_contracts) | Map of enabled feature-plugin contracts to compose into the API, mirroring<br>the CDK accelerator's `api.enable(feature)` mechanism. Each value is a<br>feature submodule's outputs contract with the shape:<br><br>  {<br>    enabled          = bool<br>    resolvers        = { <field> = { data\_source, request\_template, response\_template } }<br>    iam\_statements   = [ <policy statement objects> ]<br>    environment      = { <env-var name> = <value> }<br>    schema\_additions = optional(string)  # GraphQL SDL fragment<br>  }<br><br>Default `{}` is a no-op: no feature resolvers, IAM statements, or env vars<br>are composed (default-off preserved). | `any` | `{}` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | A map containing the list of resources with their properties and environment variables | `map(string)` | `{}` | no |
| <a name="input_evaluation_baseline_bucket"></a> [evaluation\_baseline\_bucket](#input\_evaluation\_baseline\_bucket) | Optional S3 bucket name for storing evaluation baseline documents (Legacy format - use evaluation\_baseline\_bucket\_arn instead) | <pre>object({<br>    bucket_name = string<br>    bucket_arn  = string<br>  })</pre> | `null` | no |
| <a name="input_evaluation_baseline_bucket_arn"></a> [evaluation\_baseline\_bucket\_arn](#input\_evaluation\_baseline\_bucket\_arn) | ARN of the S3 bucket for storing evaluation baseline documents | `string` | `null` | no |
| <a name="input_evaluation_enabled"></a> [evaluation\_enabled](#input\_evaluation\_enabled) | Whether evaluation functionality is enabled | `bool` | `false` | no |
| <a name="input_evaluation_layer_arn"></a> [evaluation\_layer\_arn](#input\_evaluation\_layer\_arn) | ARN of the evaluation Lambda layer (idp\_common with the evaluation extra). Required when evaluation\_enabled is true: the Test Studio aggregation function carries it as its only layer. | `string` | `null` | no |
| <a name="input_feature_platform_field_functions"></a> [feature\_platform\_field\_functions](#input\_feature\_platform\_field\_functions) | Feature Platform API field -> Lambda ARN map, merged into the REST<br>dispatcher's field-function map (IDP v0.6.4).<br><br>Supplied as its own input rather than through `enabled_feature_contracts`<br>because the Feature Platform module is wired at the root outside the<br>feature-contract map. Wire it from `module.feature_platform[0].field_functions`.<br><br>Replaces the AppSync data sources and per-field resolvers the Feature Platform<br>module used to create against the GraphQL API. Empty by default, so the<br>dispatcher is unchanged when the Feature Platform is disabled. | `map(string)` | `{}` | no |
| <a name="input_guardrail"></a> [guardrail](#input\_guardrail) | Optional Bedrock guardrail to apply to model interactions | <pre>object({<br>    guardrail_id  = string<br>    guardrail_arn = string<br>  })</pre> | `null` | no |
| <a name="input_has_feature_iam"></a> [has\_feature\_iam](#input\_has\_feature\_iam) | Whether an enabled feature contributes IAM statements to compose. | `bool` | `false` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP Common Lambda layer (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents are stored | `string` | `null` | no |
| <a name="input_introspection_config"></a> [introspection\_config](#input\_introspection\_config) | A value indicating whether the API to enable (ENABLED) or disable (DISABLED) introspection | `string` | `"ENABLED"` | no |
| <a name="input_knowledge_base"></a> [knowledge\_base](#input\_knowledge\_base) | Knowledge base configuration object | <pre>object({<br>    enabled                  = bool<br>    knowledge_base_arn       = optional(string)<br>    model_id                 = optional(string)<br>    guardrail_id_and_version = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "guardrail_id_and_version": null,<br>  "knowledge_base_arn": null,<br>  "model_id": null<br>}</pre> | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Target Lambda architecture (x86\_64 \| arm64). | `string` | `"arm64"` | no |
| <a name="input_lambda_layers_bucket_arn"></a> [lambda\_layers\_bucket\_arn](#input\_lambda\_layers\_bucket\_arn) | ARN of the S3 bucket for Lambda layers | `string` | `null` | no |
| <a name="input_lambda_local"></a> [lambda\_local](#input\_lambda\_local) | When true, build Lambda layers locally using a container runtime instead of via AWS CodeBuild. | `bool` | `false` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_lambda_web_adapter_layer_arn"></a> [lambda\_web\_adapter\_layer\_arn](#input\_lambda\_web\_adapter\_layer\_arn) | ARN of the AWS Lambda Web Adapter (LWA) layer attached to the chat token-streaming processor. When empty (default), the module constructs the upstream default (arn:<partition>:lambda:<region>:753240598075:layer:LambdaAdapterLayerX86:25). | `string` | `""` | no |
| <a name="input_log_config"></a> [log\_config](#input\_log\_config) | Logging configuration for this API | <pre>object({<br>    cloudwatch_logs_role_arn = optional(string)<br>    exclude_verbose_content  = optional(bool, false)<br>    field_log_level          = string<br>  })</pre> | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Log retention period in days | `number` | `7` | no |
| <a name="input_lookup_function_name"></a> [lookup\_function\_name](#input\_lookup\_function\_name) | Name of the LookupFunction Lambda (used by Agent Chat Processor to look up document info) | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the GraphQL API | `string` | `null` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed document outputs are stored | `string` | `null` | no |
| <a name="input_owner_contact"></a> [owner\_contact](#input\_owner\_contact) | The owner contact information for an API resource | `string` | `null` | no |
| <a name="input_post_processing_decompressor_arn"></a> [post\_processing\_decompressor\_arn](#input\_post\_processing\_decompressor\_arn) | ARN of the post\_processing\_decompressor Lambda function (from processing-environment module) | `string` | `null` | no |
| <a name="input_public_artifacts_bucket"></a> [public\_artifacts\_bucket](#input\_public\_artifacts\_bucket) | Name of the (optionally public / cross-account) S3 bucket the version\_check\_resolver Lambda lists for `<prefix>/idp-main_<version>.yaml` templates. When empty (default) the Lambda is still created and routed (matching upstream), but gets no S3 grant and reports `checkEnabled: false`, so the UI simply shows no update banner. | `string` | `""` | no |
| <a name="input_public_artifacts_prefix"></a> [public\_artifacts\_prefix](#input\_public\_artifacts\_prefix) | S3 key prefix under public\_artifacts\_bucket where versioned IDP templates live. Threaded into the resolver's PUBLIC\_ARTIFACTS\_PREFIX env var. Only used when public\_artifacts\_bucket is set. | `string` | `"artifacts/genai-idp"` | no |
| <a name="input_public_artifacts_region"></a> [public\_artifacts\_region](#input\_public\_artifacts\_region) | Region of public\_artifacts\_bucket, threaded into the resolver's PUBLIC\_ARTIFACTS\_REGION env var. When empty, the shipped resolver defaults to AWS\_REGION. Only used when public\_artifacts\_bucket is set. | `string` | `""` | no |
| <a name="input_query_depth_limit"></a> [query\_depth\_limit](#input\_query\_depth\_limit) | A number indicating the maximum depth resolvers should be accepted when handling queries | `number` | `0` | no |
| <a name="input_resolver_count_limit"></a> [resolver\_count\_limit](#input\_resolver\_count\_limit) | A number indicating the maximum number of resolvers that should be accepted when handling queries | `number` | `0` | no |
| <a name="input_s3_endpoint_url"></a> [s3\_endpoint\_url](#input\_s3\_endpoint\_url) | Optional S3 endpoint URL for presigner/dataset Lambdas. When set (e.g.<br>"https://bucket.vpce-abc123.s3.us-east-1.vpce.amazonaws.com"), those<br>Lambdas generate presigned URLs and issue S3 calls against the S3 interface<br>VPC endpoint using virtual-host addressing (private-network path). When<br>null (default), presigned URLs use the global regional S3 endpoint.<br>Mirrors upstream S3PresignedUrlViaVpcEndpoint / S3VpcEndpointDnsNameOverride. | `string` | `null` | no |
| <a name="input_serve_web_ui"></a> [serve\_web\_ui](#input\_serve\_web\_ui) | When true, serve the React SPA from web\_ui\_bucket\_name as an S3 proxy on this REST API (GET / -> index.html, GET /{proxy+} -> assets). Mirrors upstream ServeWebUI / WebUIHosting=APIGateway. The SPA then inherits the API's endpoint type (visibility) and stage WAF. Requires web\_ui\_bucket\_name. | `bool` | `false` | no |
| <a name="input_settings_parameter_name"></a> [settings\_parameter\_name](#input\_settings\_parameter\_name) | Deterministic SSM parameter name of the web-ui settings document (SETTINGS\_PARAMETER\_NAME for the chat token-streaming processor). Passed as a plain string from the root (never a module reference) to avoid a dependency cycle with the web-ui module. Empty when the web UI is disabled. | `string` | `""` | no |
| <a name="input_state_machine_arn"></a> [state\_machine\_arn](#input\_state\_machine\_arn) | ARN of the Step Functions state machine (used by Error Analyzer) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table"></a> [tracking\_table](#input\_tracking\_table) | The DynamoDB table for tracking document processing status (Legacy format - use tracking\_table\_arn instead) | <pre>object({<br>    table_name = string<br>    table_arn  = string<br>  })</pre> | `null` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table for tracking document processing status | `string` | `null` | no |
| <a name="input_tracking_table_available"></a> [tracking\_table\_available](#input\_tracking\_table\_available) | Plan-time-known override for whether the tracking table exists, used to gate<br>resources that would otherwise key their count/for\_each off<br>`tracking_table_arn`. Callers pass `tracking_table_arn` as a COMPUTED value<br>(a resource attribute created in the same apply), so `tracking_table_arn !=<br>null` is unknown at plan time and breaks a cold `terraform plan`. Set this to<br>a value the caller knows at plan time (e.g. "am I creating the tracking<br>table?"). Null (default) preserves the legacy behaviour of deriving the gate<br>from `tracking_table_arn != null`. | `bool` | `null` | no |
| <a name="input_users_table_name"></a> [users\_table\_name](#input\_users\_table\_name) | Name of the RBAC Users DynamoDB table (USERS\_TABLE\_NAME for the chat token-streaming processor). Threaded from module.rbac[0].users\_table\_name at the root when RBAC is enabled, else empty. | `string` | `""` | no |
| <a name="input_visibility"></a> [visibility](#input\_visibility) | A value indicating whether the API is accessible from anywhere (GLOBAL) or can only be access from a VPC (PRIVATE) | `string` | `"GLOBAL"` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | VPC configuration for Lambda functions. Supply vpc\_id to also place the CodeBuild projects in the VPC; those builds run `pip install`, so the subnets MUST have egress to the package index. | <pre>object({<br>    subnet_ids         = list(string)<br>    security_group_ids = list(string)<br>    vpc_id             = optional(string)<br>  })</pre> | `null` | no |
| <a name="input_waf_allowed_ipv4_ranges"></a> [waf\_allowed\_ipv4\_ranges](#input\_waf\_allowed\_ipv4\_ranges) | IPv4 CIDRs allowed to call the REST API. The allow-all default (["0.0.0.0/0"]) disables WAF; any other value attaches a REGIONAL WAFv2 WebACL (DefaultAction Block + IP allow-list) to the API stage that blocks non-listed source IPs. | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_web_ui_bucket_name"></a> [web\_ui\_bucket\_name](#input\_web\_ui\_bucket\_name) | Name of the web-app S3 bucket holding the built SPA, proxied by the GET routes when serve\_web\_ui = true. Must be supplied as a plain name derived by the caller (not read from the web-ui module) to keep the module graph acyclic. Empty (default) disables the S3-proxy routes. | `string` | `""` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket for working files (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_xray_enabled"></a> [xray\_enabled](#input\_xray\_enabled) | A flag indicating whether or not X-Ray tracing is enabled for the GraphQL API | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_processor_function_arn"></a> [agent\_processor\_function\_arn](#output\_agent\_processor\_function\_arn) | ARN of the Agent Processor Lambda function (if agent analytics is enabled) |
| <a name="output_agent_request_handler_function_arn"></a> [agent\_request\_handler\_function\_arn](#output\_agent\_request\_handler\_function\_arn) | ARN of the Agent Request Handler Lambda function (if agent analytics is enabled) |
| <a name="output_agent_table_arn"></a> [agent\_table\_arn](#output\_agent\_table\_arn) | ARN of the Agent Analytics DynamoDB table (if agent analytics is enabled) |
| <a name="output_agent_table_name"></a> [agent\_table\_name](#output\_agent\_table\_name) | Name of the Agent Analytics DynamoDB table (if agent analytics is enabled) |
| <a name="output_api_arn"></a> [api\_arn](#output\_api\_arn) | The execution ARN of the API Gateway REST API |
| <a name="output_api_base_url"></a> [api\_base\_url](#output\_api\_base\_url) | Base URL of the REST API transport (stage 'api'). |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | The ID of the API Gateway REST API |
| <a name="output_api_name"></a> [api\_name](#output\_api\_name) | The name of the API Gateway REST API |
| <a name="output_chat_stream_function_arn"></a> [chat\_stream\_function\_arn](#output\_chat\_stream\_function\_arn) | ARN of the chat token-streaming processor Lambda. Null when chat streaming is disabled. |
| <a name="output_chat_stream_function_url"></a> [chat\_stream\_function\_url](#output\_chat\_stream\_function\_url) | Function URL of the chat token-streaming processor (RESPONSE\_STREAM). Null when chat streaming is disabled. |
| <a name="output_discovery_bucket_arn"></a> [discovery\_bucket\_arn](#output\_discovery\_bucket\_arn) | ARN of the discovery S3 bucket (if discovery is enabled) |
| <a name="output_discovery_bucket_name"></a> [discovery\_bucket\_name](#output\_discovery\_bucket\_name) | Name of the discovery S3 bucket (if discovery is enabled) |
| <a name="output_edit_sections_enabled"></a> [edit\_sections\_enabled](#output\_edit\_sections\_enabled) | Whether the Edit Sections feature is enabled |
| <a name="output_http_api_dispatcher_function_arn"></a> [http\_api\_dispatcher\_function\_arn](#output\_http\_api\_dispatcher\_function\_arn) | ARN of the HTTP API dispatcher Lambda function. |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Map of Lambda function names and ARNs |
| <a name="output_list_available_agents_function_arn"></a> [list\_available\_agents\_function\_arn](#output\_list\_available\_agents\_function\_arn) | ARN of the List Available Agents Lambda function (if agent analytics is enabled) |
| <a name="output_test_set_bucket_arn"></a> [test\_set\_bucket\_arn](#output\_test\_set\_bucket\_arn) | ARN of the Test Studio test-set bucket (null when Test Studio is disabled) |
| <a name="output_test_set_bucket_name"></a> [test\_set\_bucket\_name](#output\_test\_set\_bucket\_name) | Name of the Test Studio test-set bucket (null when Test Studio is disabled) |
| <a name="output_web_ui_proxy_role_arn"></a> [web\_ui\_proxy\_role\_arn](#output\_web\_ui\_proxy\_role\_arn) | ARN of the IAM role API Gateway uses to read the web-app bucket for the Web UI S3 proxy (null unless serve\_web\_ui is enabled). |
