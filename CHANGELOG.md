# Changelog

All notable changes to the Terraform implementation are documented here.

Format: `vX.Y.Z-tf.N` where `X.Y.Z` is the upstream IDP version and `tf.N` is the Terraform iteration.

---

## [0.5.12-tf.2] - 2026-07-07

### Summary

Adds a set of low risk parity features on top of the existing processor façade
and consolidated `var.api` wiring. Everything new is default off, so with the new
inputs unset the deployment behaves identically to the previous release. The only
change on upgrade is an additive `TypeDateIndex` GSI on the tracking table, which
DynamoDB adds in place (no table replacement). See [Breaking Changes](#breaking-changes).

No file under `sources/` is modified.

### Added

- **Per attribute / per section schema flags.** The `x-aws-idp-extraction-model`,
  `x-aws-idp-exclude-from-processing` (with optional reason), and
  `x-aws-idp-page-types` / `x-aws-idp-source-page-types` keys are carried through
  the configuration seeder unchanged. The runtime enforces them; the wrapper only
  guarantees faithful pass through, so this adds no new resources. Absence changes
  nothing.
- **Version check resolver.** A `getLatestPublishedVersion` AppSync query backed by
  a Lambda that reads the latest published IDP version from a public artifacts S3
  bucket, so the web UI can show an "update available" indicator. Input gated on
  `var.api.public_artifacts_bucket` (default empty, so nothing is created), with a
  least privilege read role scoped to exactly that bucket.
- **W2 dataset deployer.** A Test Studio dataset deployer that mirrors the existing
  FCC deployer, gated by `var.api.enable_w2_dataset` (default false) and only when
  Test Studio is enabled.
- **`TypeDateIndex` GSI on the tracking table.** Lets the list resolvers query
  documents, test runs, and test sets by type and time range instead of scanning
  the whole table. Created by default; new and updated items populate it
  automatically.
- **Tracking GSI backfill.** An operator triggered Step Functions backfill that
  populates the new GSI attributes on items that predate the index. Gated by
  `var.tracking.enable_gsi_backfill` (default false), least privilege scoped, and
  never runs on `apply`: the operator starts it explicitly.

### Approach

All feature toggles live on the consolidated `var.api` object (plus a small
`var.tracking` object for the backfill), default off, so existing tfvars keep
planning unchanged. New Lambdas reuse the established patterns (source zipped from
`sources/`, shared layers via `compact([...])`, least privilege roles, the
`time_sleep` IAM propagation guard). No `sources/` edits.

### Breaking Changes

- **Tracking table `TypeDateIndex` GSI added in place.** Adding the GSI (and its
  `ItemType` / `InitialEventTime` attributes) to the tracking table is a
  non destructive, in place update in the AWS provider, so no resource is replaced
  and no `moved {}` block is needed. Still, confirm the table reports
  0 destroy / 0 create before applying:

  ```bash
  terraform state pull > backup.tfstate   # back up state first
  terraform plan                          # tracking table must show "update in place"
  terraform apply                         # DynamoDB builds the index online
  ```

  If the plan shows the table being destroyed or recreated, stop and reconcile
  before applying.

- **GSI backfill is operator triggered.** For items that predate the GSI to appear
  in `TypeDateIndex` queries, opt in and run the backfill. `apply` provisions the
  machinery but never starts a run, so the upgrade does not mutate tracking data
  unattended:

  ```bash
  # tfvars:  tracking = { enable_gsi_backfill = true }
  terraform apply
  aws stepfunctions start-execution \
    --state-machine-arn <state_machine_arn> \
    --input '{"tableName":"<tracking_table_name>","totalSegments":10}'
  ```

  The backfill is idempotent and resumes past the Lambda timeout, so it is safe to
  re run.

---

## [0.5.12-tf.1] - 2026-06-23

### Summary

Adds the production-readiness subsystems on top of the existing architecture: the
per-pattern **processor façade** over a single shared `unified-processor` engine,
and **feature-plugin** wiring composed by `modules/processing-environment-api`
through the `enabled_feature_contracts` contract (`{ enabled, resolvers,
iam_statements, environment, schema_additions }`). This release adds two
feature-plugin submodules (RBAC, IdP federation), one standalone building-block
module (`vpc-endpoints`), and three additive drop-ins (AppSyncVisibility,
BedrockHubRoleArn, managed_config).

All new subsystems are **default-off / backward-compatible**: with the new root
variables unset, the deployment behaves identically to the previous release. The
only material breaking change is the VPC-endpoints example refactor, which ships
`moved {}` blocks so a normal upgrade plans **0 destroy / 0 create**; see
[Breaking Changes](#breaking-changes) below.

No file under `sources/` is modified.

### New Features & Changes

#### RBAC + `Users` table feature-plugin submodule (C2)

- New self-contained feature-plugin submodule `modules/features/rbac/` (instantiated
  independently and composed into `processing-environment-api` via the
  feature-plugin contract — mirrors the CDK `api.enable(userManagement)` idiom).
- Provisions the four Cognito user-pool groups (`Admin`, `Author`, `Reviewer`,
  `Viewer`) with default-or-override names, a `Users` DynamoDB table (KMS-encrypted
  via `encryption_key_arn`, point-in-time recovery enabled — consistent with the
  other IDP tables) storing user id, email, persona, status, timestamps, and
  `allowedConfigVersions`, and a least-privilege user-management Lambda.
- Server-side **Reviewer document filtering** and **`allowedConfigVersions` scoping**
  enforced in the resolver/Lambda layer (not the web UI), so the restriction cannot
  be bypassed by a direct API call; the profile query exposes `allowedConfigVersions`.
- The user-management role grants only `dynamodb:{GetItem,PutItem,UpdateItem,DeleteItem,
  Query,Scan}` on the `Users` table (+ its KMS key) and the Cognito admin actions
  required for group membership, scoped to the user-pool ARN — and no broader.
- Default-off: with `var.rbac` unset, no RBAC resources are created and the
  pre-existing single-tenant Cognito authorization behavior is preserved.

#### External SAML/OIDC IdP federation feature-plugin submodule (C6)

- New self-contained feature-plugin submodule `modules/features/idp-federation/`
  (composed through the same contract as RBAC).
- Configures the Cognito identity provider (SAML via metadata URL/file, OIDC via
  issuer + client) on the user pool, additively appending the external provider to
  the user-pool client's `supported_identity_providers` while keeping `COGNITO`.
- **OIDC client-secret resolver**: the secret is supplied only as a reference
  (Secrets Manager ARN / SSM name), resolved at apply time and passed solely into
  `provider_details.client_secret` — never stored as a plaintext module input or a
  non-sensitive output.
- Provisions a **group-mapping trigger Lambda** that maps external IdP groups/claims
  to the four RBAC group names (Requirement 1) at sign-in.
- Default-off: with `var.idp_federation` unset, no federation resources are created
  and the user pool stays configured for direct Cognito authentication.

#### Private Network Deployment + standalone `vpc-endpoints` module (C7)

- New standalone module `modules/vpc-endpoints/` provisioning ~16 interface
  endpoints (ssm, ssmmessages, ec2messages, logs, monitoring, kms, sts, sqs, states,
  bedrock, bedrock-runtime, bedrock-agent-runtime, appsync-api, codebuild, lambda,
  events, textract) plus the S3 and DynamoDB gateway endpoints. Each endpoint is
  **individually toggleable**, and `service_name` is built from the current region
  (`com.amazonaws.${region}.${service}`) so the module is **partition-aware**
  (incl. `us-gov-*`).
- Root **private-network wiring**: `var.vpc_subnet_ids` / `var.vpc_security_group_ids`
  thread VPC-capable resources into the supplied private subnets/SGs and instantiate
  `module.vpc_endpoints` for the services the enabled processors/features need.
- Root **PRIVATE endpoint-gap `check {}`**: fails the plan when
  `var.api.visibility == "PRIVATE"` and the `appsync-api` interface endpoint is not
  provisioned, plus a companion best-effort check surfacing an enabled feature's
  missing required endpoint with a remediation pointer.

#### AppSyncVisibility wired at the root API layer (B3)

- `var.api.visibility` (`GLOBAL` / `PRIVATE`) is threaded from the root into
  `modules/processing-environment-api`, which sets `aws_appsync_graphql_api.visibility`
  and validates the value. Unset defaults to `GLOBAL`, preserving current behavior;
  any value other than `GLOBAL`/`PRIVATE` fails validation with an error naming the
  allowed values.

#### BedrockHubRoleArn cross-account assume-role (B8)

- Optional cross-account assume-role for a centralized Bedrock "hub" account, added
  on the **unified-processor engine** execution role(s) so all three façades inherit
  it. When `var.bedrock_hub_role_arn` is set, the engine grants `sts:AssumeRole`
  scoped to exactly that ARN (and no other) and wires the hub role ARN into the
  processing Lambdas' environment.
- Fully additive: when unset/empty, no `sts:AssumeRole` grant and no env var are
  rendered, and same-account Bedrock access is identical to pre-Round-2 behavior.

#### managed_config baselines seeded as `managed: true` rows (B11)

- The configuration seeder now seeds the baselines under
  `sources/config_library/managed_config/*/config.yaml` into the configuration
  DynamoDB table as rows carrying `Managed = true` (non-editable through the normal
  config-edit path; enforcement stays upstream). Additive: new managed rows only —
  consumer-authored non-managed rows are never overwritten or deleted.

### Breaking Changes

- **`vpc-endpoints` example refactor (module internal address change).** The
  `bedrock-llm-processor-vpc` example now consumes `modules/vpc-endpoints/` in place
  of its inline `aws_vpc_endpoint.*` resources, and sets `AppSyncVisibility =
  "PRIVATE"` to demonstrate B3 + private networking. The change ships `moved {}`
  blocks mapping each old inline endpoint address into the module, so a normal
  `terraform plan`/`apply` shows **0 destroy / 0 create** for the moved endpoints.

  New root variables `var.rbac`, `var.idp_federation`, `var.private_network`, and
  `var.api.visibility` are introduced — all **default-off / backward-compatible**;
  no tfvars changes are required to keep existing deployments planning unchanged.

  Migration (review the plan and confirm 0/0 before applying):

  ```bash
  # 1. Upgrade the module and review the plan. The bundled moved {} blocks remap the
  #    inline endpoint addresses into module.vpc_endpoints automatically — no manual
  #    terraform state mv is required.
  terraform plan

  # 2. Confirm the move is non-destructive. The moved endpoints (the ~16 interface
  #    endpoints + the S3/DynamoDB gateways) MUST report 0 destroy / 0 create before
  #    you apply. If they show destroy/create, stop and re-check the moved {} mapping
  #    against your state addresses (terraform state list | grep vpc_endpoint).
  terraform state pull > backup.tfstate   # back up state before applying

  # 3. Apply only after confirming the 0 destroy / 0 create plan.
  terraform apply
  ```

### Tooling

- **`make security` (tfsec) reworked to a per-module scan.** tfsec 1.28.x cannot
  parse Terraform 1.5+ `check {}` / `removed {}` blocks — such a block anywhere in
  a scanned root module is a *fatal parse abort that happens before result
  filtering*, so the previous `tfsec . --exclude-path main.tf` invocation never
  actually skipped those files (the flag only filters findings, it does not skip
  parsing) and `make security` had in fact been aborting since before
  `v0.4.16-tf.2`. The target now scans each module directory individually (the only
  exclusion form that works in 1.28.x), skipping the directories whose `.tf` files
  carry `check {}`/`removed {}` glue (the repo root and
  `processing-environment-api`, neither of which holds scannable resources beyond
  already-excluded IAM glue). `make all` now completes green.
- **The new modules pass tfsec strictly** (`rbac`, `idp-federation`,
  `vpc-endpoints`, `processor-configuration`): the `sts:AssumeRole` statement is
  scoped to exactly `var.bedrock_hub_role_arn` and the user-management role is
  least-privilege — both produce zero findings.
- **Pre-existing findings are scanned with `--soft-fail`** (findings still printed,
  non-blocking) for a fixed allowlist of modules that carried MEDIUM/HIGH findings
  before the v0.5.12 work (`assets-bucket`, `web-ui`, `user-identity`, `reporting`,
  `chat-with-document`, `agent-analytics`, `discovery`, and the `kms:Encrypt`
  wildcard in the four processor modules — all present at `v0.4.16-tf.2`). Every
  module not on that allowlist is scanned strictly, so a new finding in current
  work fails the gate. Remediating the allowlisted debt is tracked separately.

### Migration

See the breaking-change notes in this changelog entry
for enabling RBAC (incl. the Cognito-required constraint), configuring SAML/OIDC
federation, adopting `modules/vpc-endpoints/` (the `moved {}` mapping + the
0-destroy/0-create plan gate), and the `BedrockHubRoleArn` opt-in. All new
subsystems are default-off; no action is required to keep an existing deployment
planning unchanged.

---

## [0.5.12-tf.0] - 2026-06-09

### Summary

Upstream IDP v0.5.12 snapshot reconciliation. The vendored `sources/`
snapshot is refreshed to v0.5.12 and the three version markers are realigned
(`IDP_VERSION` → `0.5.12`, `sources/VERSION` → `0.5.12`, `VERSION` →
`0.5.12-tf.0`). The headline change is the **per-pattern processor façade**
model: a single shared internal engine (`modules/processors/unified-processor`)
with three thin public façades that delegate to it, mirroring the CDK
accelerator's `UnifiedDocumentProcessor` + per-pattern processor constructs.
Auxiliary features are restructured as **feature-plugins** wired through an
`enabled_feature_contracts` contract, with the legacy `var.api.*` flags still
forwarded for a transition window. Plus a batch of additive parity drop-ins
(inference-profile IAM, reporting column, model enablement, MCP rename,
chat-with-document streaming, Python 3.12 runtimes).

This release carries breaking changes to module internal addresses; see
[Breaking Changes](#breaking-changes-1) below and the full
migration notes.

### New Features & Changes

#### Processor façades over a shared engine (A4, A3)

- New internal engine `modules/processors/unified-processor/` wires all Lambda
  archives, state machine, and config from `sources/patterns/unified/...`. It is
  not a public input surface — façades instantiate it as a nested
  `module "engine"` and route on a required `use_bda` input (BDA invoke/completion
  steps gated on `use_bda = true`; the LLM pipeline branch is always present).
- `bda-processor`, `bedrock-llm-processor`, and `sagemaker-udop-processor` are now
  thin façades delegating to the engine:
  - `bda-processor` creates BDA Blueprints + Data Automation Project and delegates
    with `use_bda = true` + `bda_project_arn`.
  - `bedrock-llm-processor` creates no BDA resources and delegates with
    `use_bda = false`.
  - `sagemaker-udop-processor` (Pattern 3 **retained**) delegates with
    `use_bda = false` and bridges classification to a consumer-supplied SageMaker
    endpoint via a `LambdaHook` (sets `config.classification.model = "LambdaHook"`
    + `model_lambda_hook_arn`). It provisions the classification-hook bridge
    Lambda and grants `sagemaker:InvokeEndpoint` + S3 read; it creates no
    SageMaker hosting/training.
- Root wiring instantiates the three façades count-gated from
  `var.bda_processor` / `var.bedrock_llm_processor` / `var.sagemaker_udop_processor`,
  with an exactly-one-façade validation replacing the old
  `check "single_processor_required"`.

#### Feature-plugin wiring (B / Requirement 3)

- Self-contained feature submodules — `modules/features/mcp-integration`,
  `modules/features/chat-with-document`, and `modules/features/hitl` — are composed
  into `processing-environment-api` via an `enabled_feature_contracts` contract
  (resolvers, IAM statement fragments, env wiring, optional GraphQL SDL) using
  `for_each`. This mirrors the CDK `api.enable(feature)` idiom.
- Legacy `var.api.*` flags (`enable_mcp`, the chat flag, `enable_hitl`, …) are
  forwarded via root `locals` to enable the matching feature submodule. Default-off
  behavior is preserved (transition path; `var.api.*` still accepted).

#### Additive parity drop-ins

- **B1**: Bedrock inference-profile IAM (`bedrock:GetInferenceProfile` +
  `application-inference-profile/*`) added to the unified engine IAM.
- **B2**: Glue reporting table gains an additive `config_version` column.
- **B5**: Default extraction model bumped off the retired Claude 3.5 Sonnet to
  `us.anthropic.claude-sonnet-4-5-20250929-v1:0` across modules and examples.
- **B6**: Claude Opus 4.7 enabled in model picklists/validation/pricing; added an
  Opus 4.7 sample tfvars.
- **C5**: MCP integration submodule renames `agentcore_analytics_processor` →
  `agentcore_mcp_handler`, provisions the OAuth resource server, preserves the
  GovCloud guard, and stays default-off.
- **C13**: Chat-with-Document async streaming resolver(s); honors a `chat:` config
  block with `summarization.*` fallback and default
  `us.anthropic.claude-opus-4-7:1m`.
- **E5/E6**: Lambda runtimes moved to Python 3.12; layer builds use pypdfium2
  (PyMuPDF removed) via buildspec-only changes (no `sources/` edits).

### Breaking Changes

- **Processor façade refactor (module internal address change).** Per-pattern
  processor internals now live under
  `module.<facade>[0].module.engine.*`. `moved {}` blocks are provided to remap the
  old `module.bda_processor.*` / `module.bedrock_llm_processor.*` /
  `module.sagemaker_udop_processor.*` addresses into the new façade→engine nested
  addresses (SQS, DDB, ECR, CloudWatch) — target **0 destroy / 0 create** for the
  moved resources. Some BDA/UDOP-only resources (ECR/CodeBuild and other
  pattern-specific resources) are **unavoidable recreates**.
- **Pattern 3 monolith replaced.** The former monolithic SageMaker-UDOP module is
  replaced by the new `sagemaker-udop-processor` façade (the `LambdaHook`
  classification-bridge recipe).
- **MCP Lambda rename.** `agentcore_analytics_processor` →
  `agentcore_mcp_handler`. A `moved {}` block preserves the resource (and its
  `function_name`) into the feature-submodule address.
- **`var.api` flags object → feature-plugin wiring.** Auxiliary features are now
  enabled through the feature-plugin contract. `var.api.*` flags are still
  forwarded during the transition window.
- **Removed orphaned `pattern2-hitl` trio.** The
  `pattern2-hitl-{process,wait,status-update}` handlers in `modules/human-review/`
  referenced `sources/` paths that never existed upstream; they are removed (HITL
  is the feature-plugin submodule + `complete_section_review`).
- **Removed legacy synchronous chat module.** The in-API
  `modules/processing-environment-api/chat-with-document/` submodule is removed and
  replaced by the self-contained `modules/features/chat-with-document/`
  feature-plugin (async streaming, composed via `enabled_feature_contracts`).
  Chat is still enabled through the forwarded `var.api` chat flag during the
  transition window.
- **Removed standalone Error Analyzer Lambdas.** The `error_analyzer` and
  `error_analyzer_resolver` Lambdas (and their IAM roles, log groups, VPC
  attachments, and AppSync datasource) in `processing-environment-api` were
  removed upstream at v0.5.12 — their `sources/src/lambda/error_analyzer{,_resolver}`
  directories no longer exist in the snapshot, and v0.5.12 ships no replacement
  Lambda/resolver/schema field. Error analysis is now provided by the unified
  **agents framework** (`Error-Analyzer-Agent`, a library agent in
  `sources/lib/idp_common_pkg/idp_common/agents/error_analyzer/`, surfaced via the
  generic agent resolvers). `removed {}` blocks (with `destroy = false`) drop the
  orphaned resources from state without destroying real infrastructure;
  `var.enable_error_analyzer` is retained as a deprecated no-op so existing
  consumer tfvars keep planning.

### Migration

See the breaking-change notes in this changelog entry
for the full migration steps, the complete `moved {}` mapping, the SageMaker-UDOP
façade `LambdaHook` recipe, the MCP rename, and the `var.api` → feature-plugin
shift (with `var.api.*` forwarding).

Key steps (summary — the guide has the exhaustive list):

1. **Upgrade the module** and run `terraform plan`. The bundled `moved {}` blocks
   remap the per-pattern processor internals into the new façade→engine addresses
   (`module.<facade>[0].module.engine.*`) and the renamed MCP Lambda
   (`agentcore_analytics_processor` → `agentcore_mcp_handler`) automatically — no
   manual `terraform state mv` is required for the preservable resources.
2. **Confirm the move is non-destructive.** The moved resources (SQS, DynamoDB
   wiring, ECR repo, CloudWatch resources, MCP Lambda) MUST report **0 destroy /
   0 create** in the plan before you apply. If they show destroy/create, stop and
   re-check the `moved {}` mapping against your state addresses.
3. **Accept the unavoidable recreates.** Some BDA/UDOP-only resources
   (ECR/CodeBuild and other pattern-specific resources) are recreated; the guide
   lists each with its impact and a rollback note. Back up state
   (`terraform state pull > backup.tfstate`) before applying.
4. **No tfvars changes required for the transition.** `var.api.*` flags
   (`enable_mcp`, the chat flag, `enable_hitl`, …) are still forwarded to the new
   feature-plugins, so existing tfvars keep working; migrate to feature-plugin
   wiring at your own pace.

Run a `terraform plan` after upgrading and confirm the moved resources report 0
destroy / 0 create before applying.

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
  `complete_section_review` Lambda. See the migration notes for
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
