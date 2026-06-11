# Migration Guide: v0.4.16-tf.2 → v0.5.12-tf.0

This guide covers the breaking changes introduced in v0.5.12-tf.0 (the Round 1
reconciliation of the upstream IDP v0.5.12 snapshot) and the steps required to
migrate existing deployments.

The headline change is the **per-pattern processor façade** refactor: the three
per-pattern processor modules now delegate document processing to a single
shared internal engine (`modules/processors/unified-processor/`). Most of the
migration work is `terraform state` address bookkeeping that the shipped
`moved {}` blocks handle for you — but a subset of BDA/UDOP-only resources are
unavoidable recreates, and the MCP Lambda rename, the `var.api` →
feature-plugin shift, and the SageMaker-UDOP façade rebuild all need attention.

See the [CHANGELOG](../CHANGELOG.md) `## [0.5.12-tf.0]` section for the full
feature list.

---

## Before You Begin

1. **Back up your Terraform state**:

   ```bash
   terraform state pull > state-backup-v0.4.16.json
   ```

2. **Review the full CHANGELOG** for all new variables and features.

3. **Preview the moves before applying.** The entire point of the `moved {}`
   blocks is that `terraform plan` should report **0 destroy / 0 create** for
   preserved resources. Run a plan first and read it carefully:

   ```bash
   terraform init -upgrade
   terraform plan -out=v0.5.12.plan
   ```

   Terraform prints each move as a line like:

   ```text
   # module.bedrock_llm_processor[0].aws_lambda_function.ocr has moved to
   # module.bedrock_llm_processor[0].module.engine.aws_lambda_function.ocr
   ```

   A move line with **no** accompanying `+ create` / `- destroy` for that
   address is the safe outcome. The only `+ create` / `- destroy` you should see
   are the documented unavoidable recreates (Breaking Change 1 below).

4. **Do not edit the `moved {}` blocks.** They ship in the wrapper's root
   `moved.tf` and are already wired to the new addresses. Consumers who use the
   root module inherit them automatically and get 0 destroy / 0 create for the
   preserved resources.

---

## Breaking Change 1: Processor Façade Refactor + `moved {}` Mapping

### What Changed

The per-pattern processor modules (`module.bda_processor`,
`module.bedrock_llm_processor`, `module.sagemaker_udop_processor`) were
refactored from monolithic modules into thin **public façades** that delegate the
document-processing engine to a shared internal submodule,
`module.engine` (`modules/processors/unified-processor/`).

Resources that previously lived directly under each façade now live one level
deeper:

```text
OLD: module.<facade>[0].aws_lambda_function.ocr
NEW: module.<facade>[0].module.engine.aws_lambda_function.ocr
```

All three façade modules are count-gated at the root (`count = ... ? 1 : 0`), so
both the old and new addresses carry the `[0]` instance index.

### Impact

| Façade | Address preservation |
|--------|----------------------|
| `bedrock-llm-processor` | **Clean 1:1.** The shared engine was derived from the former `bedrock-llm-processor`, so every former resource maps to the identically-named engine resource one level deeper. 0 destroy / 0 create. |
| `bda-processor` | **Stateful subset preserved.** SQS DLQ, the Step Functions state machine, the BDA-completion / process-results / summarization / evaluation Lambdas, and the shared KMS policy are remapped. BDA-only resources recreate (see below). |
| `sagemaker-udop-processor` | **Stateful subset preserved.** State machine, evaluation Lambda, and the assessment Lambda role/policies/log group are remapped. Pattern-3-only resources recreate (see below). |

### `moved {}` Accounting

The `moved {}` blocks ship in the wrapper's root `moved.tf`. They remap the OLD
per-pattern addresses (as they exist in a v0.4.16 state) to the NEW
façade→engine nested addresses, so `terraform apply` preserves real
infrastructure instead of destroy/recreating it.

- **`bedrock-llm-processor`** — every Lambda, IAM role/policy/attachment,
  CloudWatch log group, the state machine, and the build helpers
  (`null_resource.create_module_build_dir`, `random_id.build_id`) are remapped
  1:1 into `module.engine.*`. The engine only *adds*
  `time_sleep.wait_for_iam_propagation` (new resource, no prior address, so it
  has no `moved {}` block and is a benign create).
- **`bda-processor`** — the stateful/identity-preserved subset is remapped:
  `aws_sqs_queue.bda_completion_dlq`, `aws_sfn_state_machine.document_processing`,
  `aws_lambda_function.{bda_completion,process_results,summarization,evaluation_function}`,
  `aws_iam_policy.kms_policy`, and
  `aws_iam_role_policy_attachment.summarization_kms_attachment`. Where the engine
  gates a resource that the old module left ungated (e.g. `use_bda`,
  summarization, evaluation), the new target carries an explicit `[0]`.
- **`sagemaker-udop-processor`** — `aws_sfn_state_machine.document_processing`,
  `aws_lambda_function.evaluation_function`, and the assessment Lambda's
  role/inline-policies/log group/VPC attachment are remapped into
  `module.engine.*`. On the UDOP path `use_bda = false`, so the BDA-branch
  resources do not exist and are not mapped.

### Unavoidable Recreates

The former BDA and SageMaker-UDOP monoliths built their Lambdas via an
**ECR image + CodeBuild** pipeline and used pattern-1/pattern-3-specific resource
names. Those resources have **no equivalent** in the shared engine and will be
destroyed and recreated:

| Resource (old address, per façade) | Façade | Impact |
|-------------------------------------|--------|--------|
| `aws_ecr_repository.{bda,udop}_processor` | BDA, UDOP | ECR repo recreated. Images rebuilt on first apply (~10–15 min CodeBuild). |
| `aws_codebuild_project.{bda,udop}_processor_build` | BDA, UDOP | CodeBuild project recreated; triggers a fresh image build. |
| `aws_s3_object.pattern1_sources` / `aws_s3_object.pattern3_sources` | BDA / UDOP | Source bundle objects recreated. |
| `null_resource.trigger_bda_build` | BDA | Build trigger recreated (forces rebuild). |
| Per-function DLQs + their CloudWatch log groups under old names | BDA | New DLQs/log groups created under engine names; old ones removed. |
| EventBridge `bda_event_rule` / target under old names | BDA | EventBridge wiring recreated under engine names. |
| Per-function IAM roles/policies created under pattern-1/pattern-3 names | BDA, UDOP | New roles/policies created under engine names. |
| `step_functions_*` role/log group, `*_function` Lambdas under pattern-3 names | UDOP | Recreated under engine names. |
| `time_sleep.wait_for_sfn_iam_propagation` | UDOP | New guard resource created. |

**Why these are safe to recreate:** they are stateless compute/build artifacts
(container images, build projects, source objects, log groups, IAM). No
DynamoDB table, S3 *data* bucket, or Cognito pool is in this list. The first
apply after upgrade will rebuild the Lambda container image(s) — budget
~10–15 minutes for the CodeBuild step on the BDA/UDOP façades.

### Migration Steps

1. **Plan and read the move/create/destroy counts** (see Before You Begin
   step 3). Confirm:
   - moved resources → 0 destroy / 0 create
   - only the ECR/CodeBuild/S3-object/DLQ/EventBridge recreates above appear as
     create/destroy
2. **Apply**:

   ```bash
   terraform apply v0.5.12.plan
   ```

3. **Wait for the image build** (BDA/UDOP façades only). The recreated
   CodeBuild project builds the Lambda container image; the Lambda update
   completes once the image is available.

### Rollback

1. Restore your state backup:

   ```bash
   terraform state push state-backup-v0.4.16.json
   ```

2. Check out the `v0.4.16-tf.2` tag of the Terraform repo.
3. `terraform plan` to verify the rollback plan, then `terraform apply`.

> **Warning**: The recreated ECR repositories and CodeBuild projects from the
> upgrade are destroyed on rollback, and the v0.4.16 versions are rebuilt. Keep
> the `state-backup-v0.4.16.json` until you have verified the upgraded
> deployment processes documents end-to-end.

---

## Breaking Change 2: SageMaker-UDOP Façade Migration (Pattern 3 Rebuild)

### What Changed

The former **monolithic** v0.4.16 SageMaker-UDOP module (Pattern 3) is replaced
by a thin `sagemaker-udop-processor` **façade** over the shared engine. Rather
than vendoring back the deleted monolith, UDOP is rebuilt to mirror the CDK
accelerator's `SagemakerUdopProcessor` (verified against `cdklabs/genai-idp@main`,
2026-06-03).

This supersedes the previously deferred Round 3 backlog item **C17**
(`sagemaker-classification-hook` façade), pulling it into Round 1.

### The `LambdaHook` Classification-Bridge Recipe

The façade does **not** create SageMaker hosting or training resources. Instead
it:

1. **Provisions a classification-hook bridge Lambda**, zipped (via
   `data "archive_file"`) from the shipped
   `sources/samples/lambda-hook-inference/GENAIIDP-sagemaker-hook/` — **no
   `sources/` edits**. The bridge reads `SAGEMAKER_ENDPOINT_NAME`, is
   Converse-API compatible, and returns the
   `{"class": ..., "document_boundary": "continue"}` shape the unified pipeline
   expects.
2. **Overrides classification to the `LambdaHook` seam**: sets the document
   config `classification.model = "LambdaHook"` with `model_lambda_hook_arn`
   pointing at the bridge Lambda.
3. **Delegates to the engine** with `use_bda = false`.
4. **Grants the bridge Lambda** `sagemaker:InvokeEndpoint` on the consumer-supplied
   endpoint plus S3 read for page artifacts, attaches the base layer via
   `compact([var.base_layer_arn, ...])`, and applies the
   `time_sleep.wait_for_iam_propagation` guard.

The SageMaker endpoint is **consumer-supplied** via `var.sagemaker_udop_processor`
(name/ARN). The façade hosts no model itself.

### Migration Steps

1. **Keep your endpoint.** The façade consumes an existing SageMaker endpoint —
   it does not manage it. Confirm your endpoint name/ARN is set on
   `var.sagemaker_udop_processor`.
2. **Plan and review.** The state machine, evaluation Lambda, and assessment
   Lambda role/policies/log group are preserved via `moved {}` (0 destroy /
   0 create). The pattern-3-named compute/build resources recreate (see
   Breaking Change 1 — "Unavoidable Recreates").
3. **Apply**, then wait for the recreated image build (~10–15 min).
4. **Verify** a document routes through `ClassificationStep` → the bridge Lambda
   → your SageMaker endpoint.

### Rollback

Same as Breaking Change 1. The bridge Lambda and `LambdaHook` config are removed
on rollback; the v0.4.16 monolithic UDOP resources are rebuilt from the
restored state. Keep your state backup until end-to-end processing is verified.

---

## Breaking Change 3: MCP Rename + Relocation (C5)

### What Changed

Two coupled address changes for the MCP integration:

1. **Lambda rename** (upstream v0.5.3):
   `agentcore_analytics_processor` → `agentcore_mcp_handler` (resource label,
   `sources/` source path, and handler entrypoint).
2. **Relocation**: the whole MCP stack moves **out of**
   `module.processing_environment_api` **into** the new
   `module.mcp_integration` feature submodule
   (`modules/features/mcp-integration/`), per the feature-plugin model
   (Breaking Change 4).

The deployed Lambda `function_name` is intentionally kept at the legacy
`<api_name>-agentcore-analytics-proc` value. Because `function_name` is
ForceNew, preserving it makes the rename an **in-place update (0 destroy /
0 create)** rather than a replacement.

The MCP submodule also:

- **Provisions the OAuth resource server** per upstream v0.5.3 when enabled.
- **Preserves the GovCloud guard**: in `us-gov-*` regions/partitions, MCP is
  disabled regardless of the enable flag.
- **Stays default-off**; enabled by the feature-plugin path or the forwarded
  `var.api.enable_mcp` flag (Breaking Change 4).

### `moved {}` Accounting

The root `moved.tf` remaps every MCP resource from the API module into the
feature submodule, including:

- `aws_lambda_function.agentcore_analytics_processor[0]` →
  `module.mcp_integration[0].aws_lambda_function.agentcore_mcp_handler[0]`
  (plus its IAM role, inline policy, X-Ray + VPC attachments, and CloudWatch
  log group, all renamed to `agentcore_mcp_handler`).
- The gateway-manager Lambda + build, gateway-execution role, the AgentCore
  Gateway CloudFormation stack, and the MCP Cognito user-pool client — these
  keep their labels and move only (module relocation).

All addresses are count-gated (`[0]`) on both sides; whole-resource moves
preserve instance keys.

### Migration Steps

1. **Plan and review.** All MCP resources should report as moves with 0 destroy
   / 0 create. If you had MCP **disabled** (the default), there are no MCP
   resources in state and nothing moves.
2. **Apply.**
3. **OAuth resource server**: when MCP is enabled, the new OAuth resource server
   is created on apply. No action needed beyond reviewing the plan.

### Rollback

Restore the state backup and check out `v0.4.16-tf.2`. The MCP resources move
back into the API module under the old `agentcore_analytics_processor` label.
Because `function_name` was preserved across the rename, the live Lambda is
unaffected by the rollback.

---

## Breaking Change 4: `var.api` Flags → Feature-Plugin Wiring (Requirement 3.5)

### What Changed

In v0.4.16-tf.0 auxiliary features were enabled through a consolidated `var.api`
boolean-flags object. As of v0.5.12-tf.0, auxiliary features (MCP,
Chat-with-Document, HITL) are **self-contained feature submodules** wired into
`modules/processing-environment-api` via an `enabled_feature_contracts` contract
(resolver definitions, IAM statement fragments, environment wiring, optional
GraphQL SDL), composed with `for_each`. This mirrors the CDK accelerator's
`api.enable(feature)` / `webApplication.enable(feature)` composition.

### Transition Path: `var.api.*` Flags Are Still Forwarded

**Existing tfvars keep working.** The root `locals` forward the legacy
`var.api.*` flags to enable the matching feature submodule:

```hcl
feature_enable = {
  mcp                = try(var.api.enable_mcp, false)
  chat_with_document = try(var.api.chat_with_document.enabled, false)
  hitl               = try(var.api.enable_hitl, false)
}
```

A feature is enabled if **either** its feature-plugin module is instantiated
**or** the forwarded `var.api.*` flag is set. Default-off behavior is preserved:
a feature selected by neither path contributes no resources.

### Impact

- **No required action.** If you set `api = { enable_mcp = true, ... }` today,
  MCP stays enabled after the upgrade via forwarding.
- The forwarded flags are a **transition window** per the project's
  deprecation-shim discipline. Prefer the feature-plugin path going forward; the
  example tfvars demonstrate it while the `var.api.*` flags remain accepted.

### Legacy Synchronous Chat Module Removed

Upstream removed the legacy **synchronous** chat module at v0.5.12; it is
replaced by the **async streaming** Chat-with-Document feature
(`modules/features/chat-with-document/`). The streaming feature honors a
top-level `chat:` config block and falls back to `summarization.*` when absent
(preserving v0.4.x behavior), defaulting the chat model to
`us.anthropic.claude-opus-4-7:1m`. If you depended on the synchronous chat
resolver directly, switch to the streaming resolver(s).

### Migration Steps

1. **No change required** to keep existing behavior — `var.api.*` flags are
   forwarded.
2. **Optional**: migrate to the feature-plugin wiring shown in the updated
   example tfvars.

### Rollback

No state surgery needed for the wiring shift itself — it is a configuration-shape
change. Rolling back to `v0.4.16-tf.2` restores the `var.api`-only wiring; your
existing `api = { ... }` block is honored by both versions.

---

## Additive (Non-Breaking) Changes

These require no migration action. They are documented here for completeness.

### Glue `config_version` Column (B2)

The reporting Glue table schema gains an additive `config_version` column
(matching the upstream v0.5.7 schema), so reporting rows can be attributed to the
config revision that produced them.

- **Backward compatible.** The change is purely additive.
- **No partition repair is needed.** Partition projection is enabled on the
  reporting table, so there is no Glue catalog `MSCK REPAIR` / partition-rebuild
  step. Historical rows written before the upgrade simply read
  `config_version = NULL`; new rows carry the value.

### Default Model Bump (B5)

The default extraction model is bumped off the retired
`claude-3-5-sonnet-20241022` to a current, non-retired inference profile
(`us.anthropic.claude-sonnet-4-5-20250929-v1:0`) across modules and examples.
Fresh deployments using defaults no longer fail with
`ResourceNotFoundException`. If you pinned the retired model id in your own
tfvars, update it.

### Claude Opus 4.7 Enablement (B6)

Opus 4.7 ids are accepted by the model picklists / validation / pricing defaults,
and a sample tfvars demonstrates an Opus 4.7 selection.
`us.anthropic.claude-opus-4-7:1m` is a valid, selectable id (also the
Chat-with-Document default).

> Opus 4.8 and the chat default bump to 4.8 are v0.5.13-only and out of scope at
> the v0.5.12 target.

### Python 3.12 + pypdfium2 (E5/E6)

Lambda runtimes move to **Python 3.12** and the layer build images are updated to
match the snapshot (no Python 3.11 pins remain that break the build). Layer
builds use **pypdfium2** (PyMuPDF removed). These are handled in TF runtime
settings and layer buildspecs only — **no `sources/` edits**, and no PyMuPDF
compatibility shim is required.

### Removed Orphaned `pattern2-hitl` Trio

The `pattern2-hitl-{process,wait,status-update}` handlers in
`modules/human-review/` referenced `sources/patterns/pattern-2/src/hitl-*`
paths that **never existed upstream** (absent at v0.3.18, v0.4.16, and v0.5.12).
They were `count`-gated and only errored when HITL was enabled — a pre-existing
latent bug, not a v0.5.12 regression. They are removed. HITL is now the
feature-plugin submodule (`modules/features/hitl/`) plus the inline
unified-statemachine HITL model and `complete_section_review`.

- **Impact**: none for consumers who never set `enable_pattern2_hitl` (the trio
  was unreachable). If you somehow had them in state, they are removed from
  configuration; the real handlers (`complete_section_review`) already provide
  interactive review.

### Removed Standalone Error Analyzer Lambdas

The `error_analyzer` and `error_analyzer_resolver` Lambdas in
`processing-environment-api` (plus their IAM roles/policies, log groups, VPC
policy attachments, and the `ErrorAnalyzerResolverDS` AppSync datasource) were
**removed upstream at v0.5.12**. Their source directories
(`sources/src/lambda/error_analyzer` and `.../error_analyzer_resolver`) no longer
exist in the snapshot, and v0.5.12 ships no replacement Lambda, AppSync
datasource/resolver, or GraphQL field. The capability moved into the unified
**agents framework**: error analysis is now the `Error-Analyzer-Agent` library
agent (`sources/lib/idp_common_pkg/idp_common/agents/error_analyzer/`), surfaced
through the generic `agent_request_handler` / `list_available_agents` resolvers.

Unlike the `pattern2-hitl` trio, these resources **were applyable** in prior
wrapper releases (`enable_error_analyzer` defaulted to `true`), so upgrading
consumers may have them in real state.

- **Migration**: the upgrade ships `removed {}` blocks (with `destroy = false`)
  for every error-analyzer resource, so `terraform plan` reports them leaving
  Terraform management **without** a destroy. The real Lambdas/roles/log groups
  are left intact and can be deleted out-of-band at your discretion. To delete
  them with Terraform instead, run `terraform state rm` is **not** needed — just
  remove the `destroy = false` lifecycle (or delete the orphans manually in the
  console/CLI).
- **`var.enable_error_analyzer`** is retained as a deprecated no-op; setting it
  has no effect. It will be removed in a future release.
- **Impact**: no plan-time error on defaults (previously the missing
  `archive_file` source dir broke `terraform plan` for everyone on the v0.5.12
  snapshot). No destroy of real infrastructure on upgrade.

---

## Migration Checklist

- [ ] `terraform state pull > state-backup-v0.4.16.json`
- [ ] `terraform init -upgrade`
- [ ] `terraform plan -out=v0.5.12.plan` and confirm:
  - [ ] moved resources show **0 destroy / 0 create**
  - [ ] only the documented ECR/CodeBuild/S3-object/DLQ/EventBridge resources
        recreate (BDA/UDOP façades)
  - [ ] MCP resources (if enabled) show as moves only
- [ ] `terraform apply v0.5.12.plan`
- [ ] Wait for the BDA/UDOP CodeBuild image rebuild (~10–15 min)
- [ ] Verify a document processes end-to-end
- [ ] Retain `state-backup-v0.4.16.json` until verified

---

## Rollback (Summary)

1. Restore state: `terraform state push state-backup-v0.4.16.json`
2. Check out the `v0.4.16-tf.2` tag
3. `terraform plan` to verify the rollback plan
4. `terraform apply`

> **Warning**: ECR repositories and CodeBuild projects created/recreated during
> the upgrade are destroyed on rollback and rebuilt at v0.4.16. The MCP Lambda's
> `function_name` was preserved across the rename, so it survives the rollback
> in place. Back up your DynamoDB tracking table before rolling back if document
> processing has occurred on v0.5.12.
