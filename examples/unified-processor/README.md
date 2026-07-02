# Unified Processor Example — dual-mode runtime routing (BDA + Bedrock-LLM)

This example answers a single question:

> **What if one deployment has TWO configurations — one running on Bedrock Data
> Automation (BDA), and the other on Bedrock-LLM?**

That is the dual-mode routing story. This example stands up **one processor, one
Step Functions state machine**, and seeds **two configuration versions** that
route documents down **different branches at runtime**:

| Configuration version | `use_bda` | Routes to | Served by |
|---|---|---|---|
| `default` | `false` | `OCRStep` → Classification → Extraction → … | **Bedrock-LLM** branch |
| `bda` (`var.bda_version_name`) | `true` | `BDA_InvokeDataAutomation` → `BDA_ProcessResultsStep` | **BDA** branch |

Both versions live in the **same deployment** and the **same state machine**.
The engine's `RouteByProcessingMode` Choice state inspects each document's
injected `use_bda` flag and sends it down the matching branch. Nothing about the
branch is decided at `terraform apply` time — it is chosen **per document**.

## Why the `bedrock-llm-processor` façade?

The wrapper's engine (`modules/processors/unified-processor/`) always deploys
**both** branches (BDA and Bedrock-LLM) on every façade, mirroring the CDK
`UnifiedDocumentProcessor`. So any façade can reach BDA purely through
configuration. This example uses the `bedrock-llm-processor` façade so the
**default** version is the Bedrock-LLM path — exactly the "one on Bedrock-LLM,
one on BDA" framing. The `bda-processor` façade would instead default to BDA.

## How the BDA link is declared (no manual DynamoDB write)

A version routes to BDA only if it both sets `use_bda: true` **and** is linked to
a BDA project. The link is the `BdaProjectArn` attribute on the version's
DynamoDB row, which upstream `queue_processor` reads (`get_bda_project_arn`).

This example declares that link through the `additional_configurations` catalog
top-level `bda_project_arn` key:

```hcl
# main.tf (locals) — the bda version
bda_mode_config = merge(
  {
    use_bda = true
    notes   = "Dual-mode demo: routes documents to the BDA branch."
  },
  # Lifted out of the config body by processor-configuration and seeded as the
  # version's BdaProjectArn. Never persisted as config data.
  local.effective_bda_project_arn != "" ? { bda_project_arn = local.effective_bda_project_arn } : {}
)
```

`processor-configuration` lifts the `bda_project_arn` key out of the config body
and writes it as the seeded version's `BdaProjectArn` (plus `BdaSyncStatus =
"synced"` and a `BdaLastSyncedAt` timestamp). No manual `aws dynamodb update-item`.

> **Precedence** (per version): per-version catalog `bda_project_arn` >
> façade-level fallback `bda_project_arn` > none (routes to Bedrock-LLM at runtime).

## The BDA project

Pick one (in `terraform.tfvars`):

- **Clean account:** set `create_bda_project = true` and this example creates the
  BDA project and links it — no pre-existing project needed. You do **not** need
  to deploy `bda-processor` first.
- **Existing project:** set `create_bda_project = false` and pass
  `bda_project_arn = "arn:aws:bedrock:...:data-automation-project/..."`.

## Prerequisites

- AWS CLI configured; Terraform ≥ 1.0; access to Amazon Bedrock in your region.
- Bedrock model access for the Bedrock-LLM models (e.g. `us.amazon.nova-2-lite-v1:0`).

## Deploy

```bash
cd genai-idp-terraform/examples/unified-processor

cp terraform.tfvars.example terraform.tfvars
#   edit terraform.tfvars -> create_bda_project = true  (or supply bda_project_arn)

terraform init
terraform plan
terraform apply
```

`terraform.tfvars` is gitignored (this directory's `.gitignore` plus the
repo-level `*.tfvars` rule).

> If neither `create_bda_project` nor `bda_project_arn` is set, the `bda` version
> is still seeded and shows in the UI, but upstream routes it to Bedrock-LLM
> until a project is linked. Link one and re-apply to activate BDA routing.

## Route a document to each branch (the `config-version` metadata)

A document is routed by the `config-version` **S3 object metadata** you set on
upload. Upstream `queue_sender` reads it, loads the named configuration version,
and `queue_processor` injects its `use_bda` flag (and linked `BdaProjectArn`) so
`RouteByProcessingMode` can route it.

```bash
INPUT_BUCKET=$(terraform output -json input_bucket | jq -r .name)
```

### Route to Bedrock-LLM (`default`)

```bash
aws s3 cp ./sample.pdf "s3://${INPUT_BUCKET}/bedrock-llm/sample.pdf" \
  --metadata config-version=default
```

Routes `RouteByProcessingMode → OCRStep → Classification → …` (Bedrock-LLM).

### Route to BDA (`bda`)

```bash
aws s3 cp ./sample.pdf "s3://${INPUT_BUCKET}/bda/sample.pdf" \
  --metadata config-version=bda
```

Routes `RouteByProcessingMode → BDA_InvokeDataAutomation → BDA_ProcessResultsStep`
(Bedrock Data Automation). If you changed `bda_version_name`, use that value
(`terraform output -raw bda_config_version`).

### Watch both branches run in the one state machine

```bash
SM_ARN=$(terraform output -raw step_function_arn)
aws stepfunctions list-executions --state-machine-arn "$SM_ARN"
aws stepfunctions describe-execution --execution-arn <execution-arn>
```

Upload one document each way and you will see two executions in the **same**
state machine: one that entered `OCRStep` (Bedrock-LLM) and one that entered
`BDA_InvokeDataAutomation` (BDA).

## Verify the seeded BDA link (optional)

```bash
CONFIG_TABLE=$(terraform output -raw configuration_table_arn | awk -F/ '{print $NF}')
aws dynamodb get-item \
  --table-name "$CONFIG_TABLE" \
  --key '{"Configuration":{"S":"Config#bda"}}'
# The item carries BdaProjectArn = <project ARN>, BdaSyncStatus = "synced".
```

## Cleanup

```bash
terraform destroy
```

## Notes

- The **default** version stays Bedrock-LLM. The catalog/fallback linking never
  relinks the default configuration.
- Add more BDA-linked versions via another `additional_config_files` entry that
  sets `use_bda: true` and carries its own `bda_project_arn`.
- `use_bda: true` **without** a linked project degrades safely to Bedrock-LLM
  (upstream fallback), so a missing ARN never errors.

## Knowledge Base & Chat

This example turns on the two API features behind the Web UI's **Agent Companion
Chat** / **Document KB** tools, both **enabled by default**:

- **Chat with document** (`chat_with_document_enabled = true`) — per-document
  Q&A. Ask questions about a single processed document; answers are generated by
  Bedrock, optionally grounded by the Knowledge Base.
- **Knowledge Base** (`create_knowledge_base = true`) — the retrieval backend
  behind the "Document KB" tool. When enabled this example provisions an
  OpenSearch Serverless vector collection + index, a Bedrock Knowledge Base, and
  an S3 data source whose bucket is the **input** bucket, so **uploaded documents
  get ingested** and can be queried across the corpus. An ingestion Lambda kicks
  off a sync job on new uploads; it is folded into the input bucket's single S3
  notification alongside the processor's EventBridge hook (Terraform allows only
  one notification per bucket). The KB ARN is wired into the root module's
  `api.knowledge_base`.

> **The KB generation model must be a cross-region inference-profile id.**
> `knowledge_base_model_id` (default `us.amazon.nova-pro-v1:0`) feeds the KB's
> `RetrieveAndGenerate` call; the query resolver builds an inference-profile ARN
> from it, so use a `us.`/`eu.`/`apac.`-prefixed id — `us.amazon.nova-pro-v1:0`,
> **not** the bare `amazon.nova-pro-v1:0`. `knowledge_base_embedding_model_id`
> (default `amazon.titan-embed-text-v1`) is the plain foundation-model id used to
> index documents. (The Bedrock-LLM branch models above use the same `us.`
> inference-profile prefixes.)

Set `create_knowledge_base = false` to drop the OpenSearch/KB backend entirely
(chat-with-document then runs without retrieval). The KB is created in-region and
adds an OpenSearch Serverless collection, so expect a few extra minutes on the
first `apply`.

```hcl
# terraform.tfvars (these are the defaults)
create_knowledge_base      = true
chat_with_document_enabled = true
knowledge_base_model_id    = "us.amazon.nova-pro-v1:0"
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.70.0 |
| <a name="requirement_opensearch"></a> [opensearch](#requirement\_opensearch) | 2.2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.90.0 |
| <a name="provider_opensearch"></a> [opensearch](#provider\_opensearch) | 2.2.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_genai_idp_accelerator"></a> [genai\_idp\_accelerator](#module\_genai\_idp\_accelerator) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_bedrockagent_data_source.knowledge_base_data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_data_source) | resource |
| [aws_bedrockagent_knowledge_base.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_knowledge_base) | resource |
| [aws_cognito_identity_pool.identity_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool) | resource |
| [aws_cognito_identity_pool_roles_attachment.identity_pool_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool_roles_attachment) | resource |
| [aws_cognito_user.admin_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user) | resource |
| [aws_cognito_user_group.admin_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_in_group.admin_user_in_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_in_group) | resource |
| [aws_cognito_user_pool.user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.user_pool_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_iam_role.authenticated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.knowledge_base_ingestion_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.knowledge_base_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.unauthenticated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.knowledge_base_bedrock_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.knowledge_base_ingestion_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.knowledge_base_opensearch_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.knowledge_base_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.knowledge_base_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_s3_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_opensearchserverless_access_policy.knowledge_base_data_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_opensearchserverless_collection.knowledge_base_collection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_collection) | resource |
| [aws_opensearchserverless_security_policy.knowledge_base_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_security_policy) | resource |
| [aws_opensearchserverless_security_policy.knowledge_base_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_security_policy) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.output_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.working_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_notification.input_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_ownership_controls.logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [awscc_bedrock_data_automation_project.bda_project](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/bedrock_data_automation_project) | resource |
| [opensearch_index.knowledge_base_index](https://registry.terraform.io/providers/opensearch-project/opensearch/2.2.0/docs/resources/index) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.iam_consistency_delay](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_before_index_creation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [archive_file.knowledge_base_ingestion_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_config_files"></a> [additional\_config\_files](#input\_additional\_config\_files) | Optional extra config versions to seed alongside the default and the BDA version, as version\_name => path to a YAML file (relative to this example dir or absolute). Each shows in the UI version dropdown as an editable, non-active version. A top-level bda\_project\_arn key inside a file links that version to a BDA project. | `map(string)` | `{}` | no |
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Optional email address for the admin user. If provided, an admin user will be created in the Cognito User Pool. | `string` | `null` | no |
| <a name="input_bda_project_arn"></a> [bda\_project\_arn](#input\_bda\_project\_arn) | ARN of an existing Bedrock Data Automation project to link to the BDA configuration version. Ignored when create\_bda\_project = true. Leave empty to seed the BDA version unlinked (it degrades to the Bedrock-LLM branch until a project is linked). | `string` | `""` | no |
| <a name="input_bda_version_name"></a> [bda\_version\_name](#input\_bda\_version\_name) | Name of the BDA-linked configuration version seeded alongside the Bedrock-LLM default. Upload a document with S3 object metadata config-version=<this value> to route it through the BDA branch. | `string` | `"bda"` | no |
| <a name="input_chat_with_document_enabled"></a> [chat\_with\_document\_enabled](#input\_chat\_with\_document\_enabled) | Enable the per-document Q&A 'chat with document' feature in the API/Web UI. Does not require a Knowledge Base (calls Bedrock directly). | `bool` | `true` | no |
| <a name="input_classification_model_id"></a> [classification\_model\_id](#input\_classification\_model\_id) | Model ID for document classification (Bedrock-LLM branch) | `string` | `"us.amazon.nova-2-lite-v1:0"` | no |
| <a name="input_config_file_path"></a> [config\_file\_path](#input\_config\_file\_path) | Path to the default (Bedrock-LLM) configuration YAML file. The lending package sample does not set use\_bda, so the default version routes through the Bedrock-LLM branch. | `string` | `"../../sources/config_library/unified/lending-package-sample/config.yaml"` | no |
| <a name="input_create_bda_project"></a> [create\_bda\_project](#input\_create\_bda\_project) | Create a Bedrock Data Automation project in this example (self-contained on a clean account) and link it to the BDA config version. When false, supply an existing project via bda\_project\_arn. | `bool` | `false` | no |
| <a name="input_create_discovery"></a> [create\_discovery](#input\_create\_discovery) | Enable the Discovery feature (Web UI 'Discovery' tab). Provisions the discovery S3 bucket, tracking table, SQS queue, upload/processor Lambdas, and AppSync resolvers, and populates the UI's DiscoveryBucket setting. Discovery uses Bedrock to auto-detect document classes/schemas from uploaded samples; with no discovery.* model configured it defaults to global.anthropic.claude-sonnet-4-6 (must be enabled in Bedrock for this region). Default on. | `bool` | `true` | no |
| <a name="input_create_knowledge_base"></a> [create\_knowledge\_base](#input\_create\_knowledge\_base) | Create the optional Bedrock Knowledge Base backend (OpenSearch Serverless collection, vector index, KB + S3 data source ingesting from the output bucket, and ingestion Lambda) and wire its ARN into the API's knowledge\_base feature. Default on. | `bool` | `true` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | The retention period for document tracking data in days | `number` | `365` | no |
| <a name="input_extraction_model_id"></a> [extraction\_model\_id](#input\_extraction\_model\_id) | Model ID for information extraction (Bedrock-LLM branch) | `string` | `"us.amazon.nova-2-lite-v1:0"` | no |
| <a name="input_knowledge_base_embedding_model_id"></a> [knowledge\_base\_embedding\_model\_id](#input\_knowledge\_base\_embedding\_model\_id) | Foundation-model id used to embed documents into the Knowledge Base vector index. Must match the vector index dimension (titan-embed-text-v2:0 => 1024, as configured in knowledge-base.tf). | `string` | `"amazon.titan-embed-text-v2:0"` | no |
| <a name="input_knowledge_base_model_id"></a> [knowledge\_base\_model\_id](#input\_knowledge\_base\_model\_id) | Inference-profile id used by the Knowledge Base for RetrieveAndGenerate (query/generation). Use a cross-region inference-profile id (e.g. us.amazon.nova-pro-v1:0); the resolver builds the inference-profile ARN from it. nova-pro is only invokable via its cross-region profile, so the us. prefix is required. | `string` | `"us.amazon.nova-pro-v1:0"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | The log level for the document processing components | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | The retention period for CloudWatch logs generated by the document processing components in days | `number` | `7` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add to resource names | `string` | `"idp-unified"` | no |
| <a name="input_rbac"></a> [rbac](#input\_rbac) | Configuration for the RBAC feature plugin. Default-off. When enabled, wires module.rbac through the feature-plugin path. | <pre>object({<br>    enabled = optional(bool, false)<br>    group_names = optional(object({<br>      admin    = optional(string, "Admin")<br>      author   = optional(string, "Author")<br>      reviewer = optional(string, "Reviewer")<br>      viewer   = optional(string, "Viewer")<br>    }), {})<br>    allowed_signup_email_domains = optional(string, "")<br>  })</pre> | <pre>{<br>  "enabled": false<br>}</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_summarization_enabled"></a> [summarization\_enabled](#input\_summarization\_enabled) | Enable document summarization for the Bedrock-LLM branch | `bool` | `false` | no |
| <a name="input_summarization_model_id"></a> [summarization\_model\_id](#input\_summarization\_model\_id) | Model ID for document summarization | `string` | `"us.amazon.nova-2-lite-v1:0"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_web_ui"></a> [web\_ui](#input\_web\_ui) | Web UI configuration object | <pre>object({<br>    enabled                    = optional(bool, true)<br>    create_infrastructure      = optional(bool, true)<br>    bucket_name                = optional(string, null)<br>    cloudfront_distribution_id = optional(string, null)<br>    logging_enabled            = optional(bool, false)<br>    logging_bucket_arn         = optional(string, null)<br>    enable_signup              = optional(string, "")<br>  })</pre> | <pre>{<br>  "enabled": true<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bda_config_version"></a> [bda\_config\_version](#output\_bda\_config\_version) | Name of the BDA-linked configuration version. Tag an upload with config-version=<this> to route it through the BDA branch. |
| <a name="output_bda_project_arn"></a> [bda\_project\_arn](#output\_bda\_project\_arn) | BDA project ARN linked to the BDA configuration version (empty if unlinked). |
| <a name="output_config_versions"></a> [config\_versions](#output\_config\_versions) | Configuration versions seeded on this deployment and their routing branch. |
| <a name="output_configuration_table_arn"></a> [configuration\_table\_arn](#output\_configuration\_table\_arn) | ARN of the DynamoDB table that stores configuration versions (incl. BdaProjectArn) |
| <a name="output_encryption_key"></a> [encryption\_key](#output\_encryption\_key) | KMS key for encryption |
| <a name="output_input_bucket"></a> [input\_bucket](#output\_input\_bucket) | S3 bucket for input documents. Upload here with config-version metadata to route. |
| <a name="output_knowledge_base_arn"></a> [knowledge\_base\_arn](#output\_knowledge\_base\_arn) | ARN of the optional Bedrock Knowledge Base (null when create\_knowledge\_base = false). |
| <a name="output_knowledge_base_id"></a> [knowledge\_base\_id](#output\_knowledge\_base\_id) | ID of the optional Bedrock Knowledge Base (null when create\_knowledge\_base = false). |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix used for all resources |
| <a name="output_output_bucket"></a> [output\_bucket](#output\_output\_bucket) | S3 bucket for processed output documents |
| <a name="output_processor_type"></a> [processor\_type](#output\_processor\_type) | Type of document processor used |
| <a name="output_step_function_arn"></a> [step\_function\_arn](#output\_step\_function\_arn) | ARN of the single Step Functions state machine that routes both branches |
| <a name="output_web_ui_url"></a> [web\_ui\_url](#output\_web\_ui\_url) | Web UI URL (if enabled) |
| <a name="output_working_bucket"></a> [working\_bucket](#output\_working\_bucket) | S3 bucket for working files |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
