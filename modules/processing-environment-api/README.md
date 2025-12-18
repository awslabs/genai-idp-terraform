<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.26.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appsync_api_key.api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_api_key) | resource |
| [aws_appsync_datasource.configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.copy_to_baseline_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.delete_document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.get_file_contents_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.get_stepfunction_execution_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.process_changes_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.publish_stepfunction_update_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.query_knowledge_base_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.reprocess_document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.tracking_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.upload_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_graphql_api.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_graphql_api) | resource |
| [aws_appsync_resolver.copy_to_baseline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.create_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.delete_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.get_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.get_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.get_file_contents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.get_stepfunction_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.list_documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.list_documents_date_hour](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.list_documents_date_shard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.process_changes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.publish_stepfunction_update](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.query_knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.reprocess_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.update_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.update_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_appsync_resolver.upload_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver) | resource |
| [aws_iam_policy.appsync_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.appsync_invoke_configuration_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.appsync_invoke_get_stepfunction_execution_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.appsync_invoke_process_changes_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.appsync_invoke_publish_stepfunction_update_resolver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.appsync_lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.configuration_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.copy_to_baseline_resolver_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
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
| [aws_iam_policy.process_changes_resolver_appsync_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.process_changes_resolver_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.process_changes_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.process_changes_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.process_changes_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.process_changes_resolver_sqs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.process_changes_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.publish_stepfunction_update_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.publish_stepfunction_update_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_bedrock_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_knowledge_base_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reprocess_document_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.upload_resolver_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.appsync_dynamodb_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.appsync_lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.configuration_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.copy_to_baseline_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.delete_document_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.get_file_contents_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.get_stepfunction_execution_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.process_changes_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.publish_stepfunction_update_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.query_knowledge_base_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.reprocess_document_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.upload_resolver_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.appsync_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.appsync_invoke_configuration_resolver_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.appsync_invoke_get_stepfunction_execution_resolver_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.appsync_invoke_process_changes_resolver_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.appsync_invoke_publish_stepfunction_update_resolver_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.appsync_lambda_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.configuration_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_self_invoke_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.copy_to_baseline_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.delete_document_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_file_contents_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_stepfunctions_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.get_stepfunction_execution_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_appsync_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_dynamodb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_sqs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.process_changes_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.publish_stepfunction_update_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.publish_stepfunction_update_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_bedrock_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.query_knowledge_base_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reprocess_document_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_s3_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.upload_resolver_vpc_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.configuration_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.copy_to_baseline_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.delete_document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.get_file_contents_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.get_stepfunction_execution_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.process_changes_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.publish_stepfunction_update_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.query_knowledge_base_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.reprocess_document_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.upload_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [null_resource.create_module_build_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.build_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.configuration_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.copy_to_baseline_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.delete_document_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.get_file_contents_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.get_stepfunction_execution_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.process_changes_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.publish_stepfunction_update_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.query_knowledge_base_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.reprocess_document_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.upload_resolver_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authorization_config"></a> [authorization\_config](#input\_authorization\_config) | Authorization configuration for the GraphQL API | <pre>object({<br/>    default_authorization = object({<br/>      authorization_type = string<br/>      user_pool_config = optional(object({<br/>        user_pool_id        = string<br/>        app_id_client_regex = optional(string)<br/>        aws_region          = optional(string)<br/>        default_action      = optional(string, "ALLOW")<br/>      }))<br/>      openid_connect_config = optional(object({<br/>        auth_ttl  = optional(number)<br/>        client_id = optional(string)<br/>        iat_ttl   = optional(number)<br/>        issuer    = string<br/>      }))<br/>      lambda_authorizer_config = optional(object({<br/>        authorizer_result_ttl_seconds  = optional(number)<br/>        authorizer_uri                 = string<br/>        identity_validation_expression = optional(string)<br/>      }))<br/>    })<br/>    additional_authorization_modes = optional(list(object({<br/>      authorization_type = string<br/>      user_pool_config = optional(object({<br/>        user_pool_id        = string<br/>        app_id_client_regex = optional(string)<br/>        aws_region          = optional(string)<br/>        default_action      = optional(string, "ALLOW")<br/>      }))<br/>      openid_connect_config = optional(object({<br/>        auth_ttl  = optional(number)<br/>        client_id = optional(string)<br/>        iat_ttl   = optional(number)<br/>        issuer    = string<br/>      }))<br/>      lambda_authorizer_config = optional(object({<br/>        authorizer_result_ttl_seconds  = optional(number)<br/>        authorizer_uri                 = string<br/>        identity_validation_expression = optional(string)<br/>      }))<br/>    })))<br/>  })</pre> | `null` | no |
| <a name="input_configuration_table"></a> [configuration\_table](#input\_configuration\_table) | The DynamoDB table for storing configuration settings (Legacy format - use configuration\_table\_arn instead) | <pre>object({<br/>    table_name = string<br/>    table_arn  = string<br/>  })</pre> | `null` | no |
| <a name="input_configuration_table_arn"></a> [configuration\_table\_arn](#input\_configuration\_table\_arn) | ARN of the DynamoDB table for storing configuration settings | `string` | `null` | no |
| <a name="input_data_retention_in_days"></a> [data\_retention\_in\_days](#input\_data\_retention\_in\_days) | Data retention period in days for processed documents | `number` | `7` | no |
| <a name="input_document_queue_arn"></a> [document\_queue\_arn](#input\_document\_queue\_arn) | ARN of the SQS queue for document processing (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_document_queue_url"></a> [document\_queue\_url](#input\_document\_queue\_url) | URL of the SQS queue for document processing (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name configuration for the GraphQL API | <pre>object({<br/>    certificate_arn = string<br/>    domain_name     = string<br/>  })</pre> | `null` | no |
| <a name="input_enable_edit_sections"></a> [enable\_edit\_sections](#input\_enable\_edit\_sections) | Whether to enable the Edit Sections feature for selective reprocessing | `bool` | `false` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key for encryption | `string` | `null` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | A map containing the list of resources with their properties and environment variables | `map(string)` | `{}` | no |
| <a name="input_evaluation_baseline_bucket"></a> [evaluation\_baseline\_bucket](#input\_evaluation\_baseline\_bucket) | Optional S3 bucket name for storing evaluation baseline documents (Legacy format - use evaluation\_baseline\_bucket\_arn instead) | <pre>object({<br/>    bucket_name = string<br/>    bucket_arn  = string<br/>  })</pre> | `null` | no |
| <a name="input_evaluation_baseline_bucket_arn"></a> [evaluation\_baseline\_bucket\_arn](#input\_evaluation\_baseline\_bucket\_arn) | ARN of the S3 bucket for storing evaluation baseline documents | `string` | `null` | no |
| <a name="input_evaluation_enabled"></a> [evaluation\_enabled](#input\_evaluation\_enabled) | Whether evaluation functionality is enabled | `bool` | `false` | no |
| <a name="input_guardrail"></a> [guardrail](#input\_guardrail) | Optional Bedrock guardrail to apply to model interactions | <pre>object({<br/>    guardrail_id  = string<br/>    guardrail_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_idp_common_layer_arn"></a> [idp\_common\_layer\_arn](#input\_idp\_common\_layer\_arn) | ARN of the IDP Common Lambda layer (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents are stored | `string` | `null` | no |
| <a name="input_introspection_config"></a> [introspection\_config](#input\_introspection\_config) | A value indicating whether the API to enable (ENABLED) or disable (DISABLED) introspection | `string` | `"ENABLED"` | no |
| <a name="input_knowledge_base"></a> [knowledge\_base](#input\_knowledge\_base) | Knowledge base configuration object | <pre>object({<br/>    enabled                  = bool<br/>    knowledge_base_arn       = optional(string)<br/>    model_id                 = optional(string)<br/>    guardrail_id_and_version = optional(string)<br/>  })</pre> | <pre>{<br/>  "enabled": false,<br/>  "guardrail_id_and_version": null,<br/>  "knowledge_base_arn": null,<br/>  "model_id": null<br/>}</pre> | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_config"></a> [log\_config](#input\_log\_config) | Logging configuration for this API | <pre>object({<br/>    cloudwatch_logs_role_arn = optional(string)<br/>    exclude_verbose_content  = optional(bool, false)<br/>    field_log_level          = string<br/>  })</pre> | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Log retention period in days | `number` | `7` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the GraphQL API | `string` | `null` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed document outputs are stored | `string` | `null` | no |
| <a name="input_owner_contact"></a> [owner\_contact](#input\_owner\_contact) | The owner contact information for an API resource | `string` | `null` | no |
| <a name="input_query_depth_limit"></a> [query\_depth\_limit](#input\_query\_depth\_limit) | A number indicating the maximum depth resolvers should be accepted when handling queries | `number` | `0` | no |
| <a name="input_resolver_count_limit"></a> [resolver\_count\_limit](#input\_resolver\_count\_limit) | A number indicating the maximum number of resolvers that should be accepted when handling queries | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tracking_table"></a> [tracking\_table](#input\_tracking\_table) | The DynamoDB table for tracking document processing status (Legacy format - use tracking\_table\_arn instead) | <pre>object({<br/>    table_name = string<br/>    table_arn  = string<br/>  })</pre> | `null` | no |
| <a name="input_tracking_table_arn"></a> [tracking\_table\_arn](#input\_tracking\_table\_arn) | ARN of the DynamoDB table for tracking document processing status | `string` | `null` | no |
| <a name="input_visibility"></a> [visibility](#input\_visibility) | A value indicating whether the API is accessible from anywhere (GLOBAL) or can only be access from a VPC (PRIVATE) | `string` | `"GLOBAL"` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | VPC configuration for Lambda functions | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket for working files (required for Edit Sections feature) | `string` | `null` | no |
| <a name="input_xray_enabled"></a> [xray\_enabled](#input\_xray\_enabled) | A flag indicating whether or not X-Ray tracing is enabled for the GraphQL API | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_arn"></a> [api\_arn](#output\_api\_arn) | The ARN of the AppSync GraphQL API |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | The ID of the AppSync GraphQL API |
| <a name="output_api_key"></a> [api\_key](#output\_api\_key) | The API key for the GraphQL API (if API key authentication is enabled) |
| <a name="output_api_name"></a> [api\_name](#output\_api\_name) | The name of the AppSync GraphQL API |
| <a name="output_edit_sections_enabled"></a> [edit\_sections\_enabled](#output\_edit\_sections\_enabled) | Whether the Edit Sections feature is enabled |
| <a name="output_graphql_url"></a> [graphql\_url](#output\_graphql\_url) | The URL endpoint for the GraphQL API |
| <a name="output_lambda_functions"></a> [lambda\_functions](#output\_lambda\_functions) | Map of Lambda function names and ARNs |
| <a name="output_process_changes_resolver"></a> [process\_changes\_resolver](#output\_process\_changes\_resolver) | Process Changes Resolver Lambda function details (Edit Sections feature) |
| <a name="output_realtime_url"></a> [realtime\_url](#output\_realtime\_url) | The URL endpoint for the Realtime API |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
