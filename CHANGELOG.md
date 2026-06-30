# Changelog

All notable changes to the Terraform implementation are documented here.

Format: `vX.Y.Z-tf.N` where `X.Y.Z` is the upstream IDP version and `tf.N` is the Terraform iteration.

---

## [Unreleased]

### Summary

Adds the `var.build` object, introducing an opt-in path that builds
Lambda layers and processor container images locally on the deploy host
using Docker / Podman / Finch, replacing AWS CodeBuild for those steps.
Non-breaking: defaults preserve the historical CodeBuild path
bit-for-bit. Set `build.lambda_local = true` to opt in.

### Added

- **`var.build` (root)** — new object with fields:
  - `lambda_local` (bool, default `false`) — when `true`, all Lambda
    layers and processor container images build locally on the deploy
    host; AWS CodeBuild infrastructure collapses to `count = 0`.
  - `lambda_architecture` (string, default `"x86_64"`, validated against
    `["x86_64", "arm64"]`) — target Lambda architecture, honored by
    both CodeBuild and local-build paths. The CodeBuild path now gains
    arm64 support (previously hardcoded x86_64).
  - `container_runtime` (string, default `"auto"`, validated against
    `["auto", "docker", "podman", "finch"]`) — runtime selector when
    `lambda_local = true`. `"auto"` probes docker → podman → finch.
  - `ui_local` (bool, default `false`) — reserved for a follow-up UI
    local-build change; no behavior in this release.
- **New modules**:
  - `modules/build-runtime-check` — probes the host for an available
    container runtime via a `data "external"` invocation of
    `scripts/detect-container-runtime.sh`; fails plan with per-OS
    install instructions when `lambda_local = true` and no runtime
    is detected.
  - `modules/lambda-layer-local-build` — provider-driven local builder
    for Python pip Lambda layers. Used internally by
    `modules/lambda-layer-codebuild` when `lambda_local = true`.
  - `modules/lambda-image-local-build` — provider-driven local builder
    for OCI Lambda container images using `kreuzwerker/docker ~> 3.0`.
    Currently unused at root (preserved as a building block for future
    single-image consumers).
- **New output `build_mode`** — added to layer and processor modules.
  Returns `"codebuild"` or `"local"`. Lets consumers see which path is
  active.
- **Documentation page** `docs/content/deployment-guides/local-lambda-build.md`
  covering prerequisites per OS, architecture selection, migration
  plan, and troubleshooting.
- **Local-dev example tfvars** `examples/bedrock-llm-processor/terraform.tfvars.local-dev.example`
  showing a typical local-build dev-loop configuration.
- **Detection script** `scripts/detect-container-runtime.sh` plus
  `tests/validate-build-runtime-check.sh` unit test.

### Changed

- **CodeBuild path now respects `var.build.lambda_architecture`.**
  Previously hardcoded to x86_64; setting `arm64` now switches the
  CodeBuild image to `aws/codebuild/amazonlinux2-aarch64-standard:3.0`
  and sets `environment.type = "ARM_CONTAINER"`. Applies to both
  layer-build and processor-image-build CodeBuild projects.
- **CodeBuild-specific outputs return `null` when `lambda_local = true`.**
  Affects `codebuild_project_name`,
  `codebuild_trigger_lambda_function_name`, `build_result`,
  `build_success` on `lambda-layer-codebuild`;
  `codebuild_project`, `build_trigger_lambda`, `build_result` on
  `lambda-layer-codebuild-idp`. Mode-agnostic outputs (`layer_arns`,
  `s3_bucket`, `layer_suffix`, …) are populated in both modes.
- **Module READMEs** for `lambda-layer-codebuild`,
  `lambda-layer-codebuild-idp`, BDA and SageMaker UDOP processors gain
  preambles documenting the two build modes. terraform-docs Inputs /
  Outputs tables regenerated.
- **Top-level README** Prerequisites section now lists container
  runtime as optional; Configuration Options section gains a
  `build = { ... }` example and a "Local Lambda Build" subsection
  linking to the dedicated docs page.

### Migration

**No action required for users keeping the default.** With
`build.lambda_local = false` (or omitted), plan shows no diff beyond the
new variable.

**Opting into local builds** on an existing deployment produces a
destroy plan for the CodeBuild infrastructure (CodeBuild projects,
trigger Lambdas, IAM roles, log groups, buildspec S3 objects) and a
replace plan for `aws_lambda_layer_version` resources (the S3 key
changes between paths). `aws_ecr_repository` resources are preserved
across the switch. `aws_lambda_function` resources update in place to
reference the new layer/image; the functions themselves are not
replaced. Lambda hot-swaps layer references on the next cold start, so
the replacement is zero-downtime.

To roll back, flip the flag back to `false` and apply again.

### Skipped (documented deviations)

- The root config does **not** declare the `kreuzwerker/docker`
  provider as a `configuration_aliases` optional provider (design.md
  Decision 4). The processor image build path landed using
  `null_resource + local-exec docker buildx` rather than the docker
  provider's `docker_image` / `docker_registry_image` resources,
  because the multi-image-per-repo pattern (5 BDA images, 7 UDOP
  images) doesn't fit the docker provider's single-tag-per-resource
  model cleanly. `modules/lambda-image-local-build` (which DOES use the
  docker provider) is preserved as a building block for future
  single-image consumers; the root provider declaration can land
  alongside the first such consumer.
- Lambda layer local builds use **`null_resource + local-exec`** running
  `scripts/build-layer.sh` (or `scripts/build-idp-layer.sh`) inside the
  AWS SAM build image, rather than `terraform-aws-modules/lambda ~> 7.0`
  with `build_in_docker = true` as originally proposed (design.md
  Decision 2). Reason: the dispatcher pattern has the wrapper module
  (`lambda-layer-codebuild`) owning the `aws_lambda_layer_version`
  resource — we only need build+upload from the local-build module.
  Hand-rolled HCL matches the existing CodeBuild module's style and
  avoids adding a third-party module dependency. The SAM build image
  produces the same hermetic environment either way.

---

## [0.4.16-tf.2] - 2026-05-27

### Summary

Patch release fixing five bugs in the `examples/sagemaker-udop-processor`
example that prevented it from planning, applying, and running
end-to-end. Verified against a fresh AWS account: 446 resources
provisioned cleanly, sample document processed by Step Functions to
completion. No upstream IDP version change.

### Fixes

- **`config_file_path` default repaired.** Pointed at
  `pattern-3/rvl-cdip-package-sample/` which doesn't exist; renamed to
  `pattern-3/rvl-cdip/` (the real directory). Same path corrected in
  `terraform.tfvars.example` and the docs reference.
- **`extraction_model_id` wired end-to-end.** The slim `rvl-cdip`
  config carries no `extraction` block, so reading
  `local.config_with_overrides.extraction.model` crashed plan. Added
  an `extraction_model_id` input on the example (default Claude 3.5
  Sonnet), a matching optional field on the root
  `sagemaker_udop_processor` variable, stopped hardcoding `null` at
  the root → module call, and made the env-var read defensive with
  `try(...)`.
- **CodeBuild IAM propagation guarded.**
  `null_resource.trigger_udop_build` started the CodeBuild project
  immediately after the role policy attachment, racing IAM eventual
  consistency. The build failed during QUEUED with `ACCESS_DENIED on
  logs:CreateLogStream`. Added a `time_sleep.wait_for_iam_propagation`
  (30s) gating the trigger — same pattern as
  `lambda-layer-codebuild-idp`, `lambda-layer-codebuild`, and
  `web-ui`.
- **Step Functions IAM propagation guarded.**
  `aws_sfn_state_machine.document_processing` validates log-destination
  access synchronously, racing the inline policy. Failed with
  `AccessDeniedException: The state machine IAM Role is not authorized
  to access the Log Destination`. Same `time_sleep` guard added.
- **Retired Bedrock model bumped in `terraform.tfvars.example`.**
  `agent_analytics.model_id` was pinned to
  `us.anthropic.claude-3-5-sonnet-20241022-v2:0` which AWS retired in
  2026; Converse calls fail with `ResourceNotFoundException`. Bumped
  to `us.anthropic.claude-haiku-4-5-20251001-v1:0`.

### Migration

No action required. This is a patch release covering the
`examples/sagemaker-udop-processor` flow only. Existing deployments
running other examples are unaffected. If you previously copied the
broken `terraform.tfvars.example` model ID into your own tfvars,
update it to a current Bedrock inference profile.

---

## [0.4.16-tf.1] - 2026-03-12

### Summary

Upgrade from v0.4.8-tf.0 to v0.4.16-tf.1, spanning 8 upstream IDP versions (v0.4.9–v0.4.16).
Introduces built-in HITL (replacing SageMaker A2I), shared Lambda layers, configuration versioning,
pricing management, capacity planning, rule validation, Lambda hook inference, BDA sync, abort
workflow, dataset deployers, and Pattern 3 deprecation.

### Breaking Changes

- **SageMaker A2I removed**: All SageMaker A2I resources (`aws_sagemaker_flow_definition`,
  `aws_sagemaker_human_task_ui`, `create_a2i_resources` Lambda, `get-workforce-url` Lambda) have
  been removed from `modules/human-review/`. The `enable_hitl` and `private_workteam_arn` variables
  are also removed from that module. HITL is now built into `processing-environment-api` via the
  `complete_section_review` Lambda. See the [migration guide](docs/migration-guide.md) for
  `terraform state rm` commands.

- **`base_layer_arn` required**: All processor modules (`bda-processor`, `bedrock-llm-processor`,
  `sagemaker-udop-processor`) and `processing-environment-api` now require a `base_layer_arn` input
  variable. This is automatically wired from `module.processing_environment.base_layer_arn` in the
  root module. Direct module users must add this input.

### New Features

#### Built-in HITL (`processing-environment-api`)

- `complete_section_review` Lambda handles `claimReview`, `releaseReview`, `skipAllSectionsReview`,
  and `completeSectionReview` via fieldName dispatch
- AppSync resolvers for all four HITL operations
- Controlled by `enable_hitl` variable (default: `true`)
- `enable_hitl` variable removed from `human-review` module (now lives in `processing-environment-api`)

#### Shared Lambda Layers (`processing-environment`)

- Three new Lambda layer resources: `base`, `reporting`, and `agents` layers built from `sources/lib/`
- All Lambda functions in all modules now attach the base layer via `compact([var.base_layer_arn, ...])`
- Layer ARNs exposed as outputs: `base_layer_arn`, `reporting_layer_arn`, `agents_layer_arn`

#### Configuration Versioning + Pricing (`processing-environment-api`)

- `configuration_resolver` Lambda (sourced from CDK nested appsync tree) handles all 10 operations:
  `getConfiguration`, `updateConfiguration`, `getConfigVersions`, `getConfigVersion`,
  `setActiveVersion`, `deleteConfigVersion`, `getPricing`, `updatePricing`, `restoreDefaultPricing`,
  `listConfigurationLibrary`, `getConfigurationLibraryFile`
- AppSync resolvers for all configuration and pricing operations

#### Abort Workflow (`processing-environment-api`)

- `abort_workflow` Lambda (sourced from CDK nested appsync tree) with Step Functions `StopExecution`
  and DynamoDB `GetItem`/`UpdateItem` IAM permissions
- AppSync resolver for `abortWorkflow` mutation

#### BDA Sync (`processing-environment-api`)

- `sync_bda_idp` Lambda (sourced from CDK nested appsync tree) with Bedrock blueprint CRUD IAM
- AppSync resolver for `syncBdaIdp` mutation
- `bda_project_arn` input variable (default: `""`)

#### Capacity Planning (`processing-environment-api`)

- `calculate_capacity` and `calculate_capacity_resolver` Lambdas
- AppSync resolver for `calculateCapacity` query
- Controlled by `enable_capacity_planning` variable (default: `false`)

#### Dataset Deployers (`processing-environment-api`)

- `ocr_benchmark_deployer` Lambda for OmniAI OCR Benchmark dataset
- `docsplit_testset_deployer` Lambda for DocSplit RVL-CDIP-NMP Packet dataset
- Controlled by `enable_omni_ai_dataset` and `enable_docplit_poly_seq_dataset` (both default: `false`)

#### Rule Validation (`bedrock-llm-processor`)

- `rule_validation_function` and `rule_validation_orchestration_function` Lambdas
- Controlled by `enable_rule_validation` variable (default: `false`)

#### Lambda Hook Inference (`bedrock-llm-processor`)

- `lambda_hook_ocr`, `lambda_hook_classification`, `lambda_hook_extraction`,
  `lambda_hook_assessment`, `lambda_hook_summarization` variables
- All hook ARNs must start with `GENAIIDP-` prefix (validated)
- Step Functions execution role gets `lambda:InvokeFunction` for any non-empty hook ARNs

### Deprecations

- **Pattern 3 (SageMaker UDOP)**: Deprecated as of v0.4.16. Will be removed in v0.5.0.
  A `check` block emits a deprecation warning on every `terraform plan`/`apply`.
  Migrate to Pattern 1 (BDA) or Pattern 2 (Bedrock LLM).

### Other Changes

- Default `model_id` in `bedrock-llm-processor` updated to `us.amazon.nova-2-lite-v1:0`
- GovCloud config library entries added to `sources/config_library/`
- `bda-processor` exposes `data_automation_project_arn` output (consumed by BDA sync resolver)
- Root `api` variable extended with v0.4.16 feature flags:
  `enable_hitl`, `enable_capacity_planning`, `enable_omni_ai_dataset`, `enable_docplit_poly_seq_dataset`

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
