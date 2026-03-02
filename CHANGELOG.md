# Changelog

All notable changes to the Terraform implementation are documented here.

Format: `vX.Y.Z-tf.N` where `X.Y.Z` is the upstream IDP version and `tf.N` is the Terraform iteration.

---

## [0.4.8-tf.0] - 2026-02-26

### Summary

Major upgrade from v0.3.18-tf.1 to v0.4.8-tf.0, spanning 10 upstream IDP versions (v0.3.19–v0.4.8).
Introduces Agent Companion Chat, Test Studio, Error Analyzer, MCP Integration, Agentic Extraction,
Docker image deployment for Pattern 1 and Pattern 3, evaluation integrated into Step Functions,
and the Vite-based Web UI build system.

### Breaking Changes

- **Configuration format**: Upstream IDP now uses JSON Schema Draft 2020-12 for extraction schemas.
  Existing YAML configs continue to work via auto-migration in `idp_common_pkg`. No HCL changes required.
  See `docs/json-schema-migration.md` in the upstream repo for details.

- **Evaluation moved to Step Functions**: Pattern 1, 2, and 3 evaluation functions are now invoked
  as a Step Functions workflow step (`EvaluateDocument` state) rather than via EventBridge.
  Any existing EventBridge rules for evaluation must be removed before upgrading.

- **Pattern 1 and Pattern 3 Lambda → Docker**: `bda-processor` and `sagemaker-udop-processor`
  now build and deploy Lambda functions as Docker images via ECR + CodeBuild.
  Requires Docker available in the CodeBuild environment. First `terraform apply` will trigger
  a CodeBuild build; subsequent applies only rebuild when source changes.

- **Web UI environment variables**: All `REACT_APP_*` CodeBuild environment variables renamed to
  `VITE_*` prefix. `VITE_CLOUDFRONT_DOMAIN` added. If you have custom buildspec overrides
  referencing `REACT_APP_*` variables, update them before upgrading.

### New Features

#### Agent Companion Chat (`processing-environment-api`)

- DynamoDB `agent_chat_sessions` table with TTL, KMS encryption, and PITR
- 6 Lambda functions: `agent_chat_processor`, `agent_chat_resolver`, `create_chat_session_resolver`,
  `list_agent_chat_sessions_resolver`, `get_agent_chat_messages_resolver`, `delete_agent_chat_session_resolver`
- AppSync resolvers for all chat operations
- Controlled by `enable_agent_companion_chat` variable (default: `true`)

#### Test Studio (`processing-environment-api`)

- S3 `test_sets` bucket with versioning and KMS encryption
- DynamoDB `test_sets` table with KMS encryption and PITR
- 7 Lambda functions: `test_runner`, `test_results_resolver`, `test_set_resolver`,
  `test_set_zip_extractor`, `test_file_copier`, `test_set_file_copier`, `delete_tests`
- Optional `fcc_dataset_deployer` Lambda (controlled by `enable_fcc_dataset`, default: `false`)
- AppSync resolvers for all test studio operations
- Controlled by `enable_test_studio` variable (default: `true`)

#### Error Analyzer (`processing-environment-api`)

- `error_analyzer` Lambda with CloudWatch Logs, X-Ray, Step Functions, and Bedrock IAM
- `error_analyzer_resolver` Lambda for AppSync integration
- AppSync resolver for `analyzeError` query
- Controlled by `enable_error_analyzer` variable (default: `true`)

#### MCP Integration (`processing-environment-api`)

- `agentcore_analytics_processor` Lambda with Athena/Glue/S3/Bedrock IAM
- `agentcore_gateway_manager` Lambda for gateway lifecycle management
- Bedrock AgentCore Gateway via `aws_cloudformation_stack` fallback
- Cognito external app client for OAuth 2.0 (`client_credentials` flow)
- GovCloud guard: automatically disabled in `us-gov-*` regions
- Outputs: `mcp_gateway_endpoint`, `mcp_oauth_client_id`, `mcp_oauth_client_secret`
- Controlled by `enable_mcp` variable (default: `false`, requires explicit opt-in)

#### Agentic Extraction (`bedrock-llm-processor`)

- `enable_agentic_extraction` variable (default: `false`)
- When enabled, wires `ENABLE_AGENTIC_EXTRACTION=true` into extraction Lambda config override
- Strands agent framework support bundled in `idp_common_pkg[agentic_idp]`

#### Section Splitting Strategy (`bedrock-llm-processor`)

- `section_splitting_strategy` variable with validation: `disabled` | `page` | `llm_determined`
- Default: `disabled`

#### Review Agent Model (`bedrock-llm-processor`)

- `review_agent_model` variable (default: `""` — uses extraction model)
- Wired as `REVIEW_AGENT_MODEL` config override in extraction Lambda

#### Post-Processing Decompressor (`processing-environment`)

- `post_processing_decompressor` Lambda for decompressing documents before custom hooks
- Provides backward compatibility for custom post-processor integrations
- `custom_post_processor_arn` variable to wire in external hook Lambda
- `post_processing_decompressor_arn` output for use by `processing-environment-api`

#### HITL Docker Fix (`human-review`)

- `hitl_wait` and `hitl_status_update` Lambda functions now support Docker image deployment
- `hitl_wait_image_uri` and `hitl_status_update_image_uri` variables added
- Falls back to zip deployment when image URI is not provided

#### Web UI Updates (`web-ui`)

- CodeBuild image updated to `amazonlinux2-x86_64-standard:5.0` (Node 22.x)
- Build timeout increased to 30 minutes
- All `REACT_APP_*` env vars renamed to `VITE_*`
- `VITE_CLOUDFRONT_DOMAIN` added
- Version string updated to `0.4.8`

#### ECR + CodeBuild for Pattern 1 and Pattern 3

- `bda-processor` and `sagemaker-udop-processor` now create ECR repositories
- CodeBuild projects build and push Docker images for Lambda functions
- `enable_ecr_image_scanning` variable controls `scan_on_push` on ECR repos

#### Evaluation Function for All Patterns

- Pattern 1 (`bda-processor`): evaluation Lambda created when `evaluation_baseline_bucket_arn` provided
- Pattern 2 (`bedrock-llm-processor`): evaluation Lambda with `TRACKING_TABLE` env var fix
- Pattern 3 (`sagemaker-udop-processor`): evaluation Lambda always created (no-op when not configured)

### Bug Fixes

- **TRACKING_TABLE env var** (`bedrock-llm-processor`): evaluation Lambda was missing `TRACKING_TABLE`
  environment variable, causing evaluation results to be silently lost (upstream fix #132)
- **ECR race condition** (`bda-processor`, `sagemaker-udop-processor`): CodeBuild now verifies
  image availability before completing (upstream fix #133)

### Source Sync

- `sources/` synced from upstream CloudFormation v0.4.8
- 19 new Lambda directories in `sources/src/lambda/`
- `evaluation_function` added to `sources/patterns/pattern-1/src/` and `sources/patterns/pattern-3/src/`
- All three `patterns/*/statemachine/workflow.asl.json` updated
- `sources/src/api/schema.graphql` updated with Agent Chat, Test Studio, Error Analyzer, MCP types
- `sources/src/ui/` updated to Vite 7 + React 18 + Amplify v6
- `sources/lib/idp_common_pkg/` updated with `agentic_idp.py`, `bedrock_utils.py`, evaluation updates

### Variables Added

| Module | Variable | Default | Description |
|--------|----------|---------|-------------|
| `bedrock-llm-processor` | `section_splitting_strategy` | `"disabled"` | Section splitting mode |
| `bedrock-llm-processor` | `enable_agentic_extraction` | `false` | Enable Strands agentic extraction |
| `bedrock-llm-processor` | `review_agent_model` | `""` | Override model for review agent |
| `bedrock-llm-processor` | `evaluation_baseline_bucket_arn` | `null` | Baseline bucket for evaluation |
| `bda-processor` | `enable_ecr_image_scanning` | `true` | ECR scan on push |
| `sagemaker-udop-processor` | `enable_ecr_image_scanning` | `true` | ECR scan on push |
| `processing-environment` | `custom_post_processor_arn` | `null` | Custom hook Lambda ARN |
| `human-review` | `hitl_wait_image_uri` | `null` | Docker image for HITL wait Lambda |
| `human-review` | `hitl_status_update_image_uri` | `null` | Docker image for HITL status update Lambda |
| `processing-environment-api` | `enable_agent_companion_chat` | `true` | Agent Companion Chat feature |
| `processing-environment-api` | `enable_test_studio` | `true` | Test Studio feature |
| `processing-environment-api` | `enable_fcc_dataset` | `false` | FCC dataset deployer |
| `processing-environment-api` | `enable_error_analyzer` | `true` | Error Analyzer feature |
| `processing-environment-api` | `enable_mcp` | `false` | MCP Integration |
| `processing-environment-api` | `post_processing_decompressor_arn` | `null` | Decompressor Lambda ARN |
| `processing-environment-api` | `state_machine_arn` | `null` | Step Functions ARN for Error Analyzer |
| `processing-environment-api` | `user_pool_id` | `null` | Cognito pool for MCP OAuth |

---

## [0.3.18-tf.1] - Initial Release

Initial Terraform implementation based on upstream IDP v0.3.18.

### Features

- Pattern 1 (BDA), Pattern 2 (Bedrock LLM), Pattern 3 (SageMaker UDOP) processors
- Web UI (CloudFront + S3 + CodeBuild)
- GraphQL API (AppSync)
- Human review (SageMaker A2I)
- Reporting (Glue/Athena)
- User identity (Cognito)
- Security scanning (TFLint, TFSec, Checkov)
- Pre-commit hooks
