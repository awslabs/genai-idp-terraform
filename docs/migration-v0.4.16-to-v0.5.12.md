# Migration Guide: v0.4.16-tf.2 → v0.5.12-tf.2

This guide covers the changes introduced across the three upstream IDP v0.5.12
migration rounds and the steps required to migrate existing deployments:

- **Round 1 (v0.5.12-tf.0)** — the reconciliation of the wrapper with the
  v0.5.12 `sources/` snapshot. Headline change: the **per-pattern processor
  façade** refactor (three façades over one shared
  `modules/processors/unified-processor/` engine), the MCP Lambda rename, the
  `var.api` → feature-plugin shift, and the SageMaker-UDOP façade rebuild.
  Breaking Changes 1–4 below.
- **Round 2 (v0.5.12-tf.1)** — the production-readiness subsystems and small
  drop-ins layered on the Round 1 base: **RBAC + `Users` table** (C2), **external
  SAML/OIDC IdP federation** (C6), the standalone **`modules/vpc-endpoints/`**
  module + private-network wiring (C7), **`AppSyncVisibility`** (B3),
  **`BedrockHubRoleArn`** cross-account assume-role (B8), and **managed config**
  (B11). All Round 2 subsystems are **default-off and additive**; the only
  address-changing refactor (the `bedrock-llm-processor-vpc` example adopting
  the VPC-endpoints module) is `moved {}`-preserved at 0 destroy / 0 create.
  Breaking Change 5 and the Round 2 feature sections below.
- **Round 3 (v0.5.12-tf.2)** — the "cheap + small tier" layered on the merged
  Round 1 + Round 2 base: the three config-shape `x-aws-idp-*` schema flags
  (B9 / B10 / B12, runtime-enforced pass-through), the
  **`getLatestPublishedVersion`** version-check resolver (C14), the **W2 dataset
  deployer** (C16), and the tracking-table **`TypeDateIndex` GSI** + an
  **operator-triggered GSI backfill** (C1). The config flags and C14/C16 are
  **default-off and additive**; the one breaking change is the `TypeDateIndex`
  GSI, which is added to the tracking table **in place** (gated on a verified
  0-destroy / 0-create plan, never a table replacement). Breaking Change 6 and
  the Round 3 feature sections below.

Most of the migration work is `terraform state` address bookkeeping that the
shipped `moved {}` blocks handle for you — but a subset of BDA/UDOP-only
resources are unavoidable recreates (Round 1, Breaking Change 1).

See the [CHANGELOG](../CHANGELOG.md) `## [0.5.12-tf.0]`, `## [0.5.12-tf.1]`, and
`## [0.5.12-tf.2]` sections for the full feature lists.

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

## Breaking Change 5: `bedrock-llm-processor-vpc` Example Adopts `modules/vpc-endpoints/` (C7)

> **Round 2 (v0.5.12-tf.1).** This is the **only** address-changing refactor in
> Round 2, and it is confined to the `examples/bedrock-llm-processor-vpc/`
> example. It is `moved {}`-preserved (0 destroy / 0 create). If you do not use
> that example, no action is required.

### What Changed

Round 2 generalizes the inline interface/gateway VPC endpoints in the
`bedrock-llm-processor-vpc` example into a reusable standalone module,
`modules/vpc-endpoints/`. The example now calls that module instead of declaring
~16 inline `aws_vpc_endpoint` resources:

```hcl
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"
  # ...
  vpc_id              = local.vpc_id
  subnet_ids          = local.vpc_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true
  # interface endpoints (ssm, logs, monitoring, kms, sts, sqs, states, bedrock,
  # bedrock-runtime, bedrock-agent-runtime, appsync-api, codebuild, lambda,
  # events, textract) + s3/dynamodb gateways are toggled via the module inputs.
}
```

The interface endpoints move under the module's `for_each`-keyed
`aws_vpc_endpoint.interface["<service>"]`, and the S3 and DynamoDB gateway
endpoints move under `aws_vpc_endpoint.s3_gateway[0]` /
`aws_vpc_endpoint.dynamodb_gateway[0]`. The example also sets
`AppSyncVisibility = "PRIVATE"` and provisions the `appsync-api` endpoint to
demonstrate B3 + private networking together.

### `moved {}` Accounting

The example ships one `moved {}` block per relocated endpoint. Each old inline
address maps onto the module's keyed interface endpoint (or the count-indexed
gateway endpoint). The full mapping (note the upstream-friendly key renames:
`cloudwatch_logs` → `logs`, `cloudwatch_monitoring` → `monitoring`,
`step_functions` → `states`, `eventbridge` → `events`):

| Old inline address | New module address |
|--------------------|--------------------|
| `aws_vpc_endpoint.ssm[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["ssm"]` |
| `aws_vpc_endpoint.cloudwatch_logs[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["logs"]` |
| `aws_vpc_endpoint.cloudwatch_monitoring[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["monitoring"]` |
| `aws_vpc_endpoint.kms[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["kms"]` |
| `aws_vpc_endpoint.bedrock[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock"]` |
| `aws_vpc_endpoint.bedrock_runtime[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock-runtime"]` |
| `aws_vpc_endpoint.bedrock_agent_runtime[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock-agent-runtime"]` |
| `aws_vpc_endpoint.sts[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["sts"]` |
| `aws_vpc_endpoint.codebuild[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["codebuild"]` |
| `aws_vpc_endpoint.eventbridge[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["events"]` |
| `aws_vpc_endpoint.lambda[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["lambda"]` |
| `aws_vpc_endpoint.sqs[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["sqs"]` |
| `aws_vpc_endpoint.step_functions[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["states"]` |
| `aws_vpc_endpoint.textract[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["textract"]` |
| `aws_vpc_endpoint.appsync_api[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["appsync-api"]` |
| `aws_vpc_endpoint.s3[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.s3_gateway[0]` |
| `aws_vpc_endpoint.dynamodb[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.dynamodb_gateway[0]` |

### Migration Steps (Plan Gate)

The verified plan — **not** the presence of the `moved {}` blocks — is the merge
gate. **You MUST confirm the plan shows 0 destroy / 0 create for the moved
endpoints before applying.**

1. **Plan and read the move/create/destroy counts**:

   ```bash
   terraform init -upgrade
   terraform plan -out=vpc-endpoints.plan
   ```

   Each endpoint should appear as a move line with **no** accompanying
   `+ create` / `- destroy`, e.g.:

   ```text
   # aws_vpc_endpoint.bedrock[0] has moved to
   # module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock"]
   ```

2. **Stop and investigate if any moved endpoint shows create/destroy.** A
   destroy/recreate of a live interface endpoint is **not** an acceptable
   outcome here; the rename is preservable, so a non-0/0 plan means the state
   address or `moved {}` mapping needs reconciling before you apply.

3. **Apply** once the plan is clean:

   ```bash
   terraform apply vpc-endpoints.plan
   ```

### Rollback

Restore your state backup and check out the prior tag. The endpoints move back
to their inline addresses; because the refactor is move-only, no real endpoint
is destroyed or recreated by the rollback.

---

## Breaking Change 6: Tracking-Table `TypeDateIndex` GSI (C1, Round 3)

> **Round 3 (v0.5.12-tf.2).** This is the **only** breaking change in Round 3,
> and it is the **one true breaking change of the whole v0.5.12 line**. It is an
> **additive, in-place** table update — the tracking table is **not** replaced —
> but because it mutates a stateful resource (a DynamoDB table that holds your
> document/test-run/test-set tracking history), it is gated on a verified
> 0-destroy / 0-create plan, exactly like the Round 2 vpc-endpoints gate.

### What Changed

The tracking table (`modules/tracking-table/`) gains the upstream v0.5.1
**`TypeDateIndex`** global secondary index so the document / test-run / test-set
list resolvers query by item type + time range instead of scanning the whole
table. Concretely, the table now declares:

- two new attributes — `ItemType` (S) and `InitialEventTime` (S);
- a `global_secondary_index "TypeDateIndex"` keyed **HASH `ItemType`** /
  **RANGE `InitialEventTime`**, with an `INCLUDE` projection of the 21 non-key
  list attributes (matching `sources/template.yaml` exactly).

DynamoDB supports **online GSI creation**, so the AWS provider adds the index as
an in-place table update — no destroy/recreate. The index read access the
resolvers need (`<tracking_table_arn>/index/*`) was already granted, so no IAM
change is required.

### Impact

| Aspect | Detail |
|--------|--------|
| Table identity | **Preserved.** The GSI is an added block on the existing `aws_dynamodb_table.tracking_table` — no resource address change, no `moved {}` needed. |
| Plan shape | The table shows **updated in place (0 destroy / 0 create)**; the only change is `+ global_secondary_index` and the two `+ attribute` blocks. |
| Data | **Preserved.** No tracking data is lost. New/updated items populate the GSI automatically; pre-existing items need the backfill (below) to appear in `TypeDateIndex` queries. |
| Backfill | The data-population step for historical items is **operator-triggered and default-off** — `terraform apply` never mutates tracking data unattended. |

### Migration Steps (Plan Gate)

The verified plan — **not** the presence of the GSI block — is the merge gate.
**You MUST confirm the plan shows the table updated in place (0 destroy /
0 create) before applying.**

1. **Plan and read the table change**:

   ```bash
   terraform init -upgrade
   terraform plan -out=typedateindex.plan
   ```

   The tracking table should appear as an **in-place update** (`~`) adding the
   `TypeDateIndex` GSI and the `ItemType` / `InitialEventTime` attributes, e.g.:

   ```text
   # module.processing_environment.module.tracking_table.aws_dynamodb_table.tracking_table will be updated in-place
   ~ resource "aws_dynamodb_table" "tracking_table" {
       + attribute { name = "ItemType"         type = "S" }
       + attribute { name = "InitialEventTime" type = "S" }
       + global_secondary_index { name = "TypeDateIndex" ... }
     }
   ```

2. **Stop and investigate if the plan shows the table being destroyed/recreated
   (`-/+`).** A destroy/recreate of the live tracking table is **not** an
   acceptable outcome — it would lose tracking history. A non-in-place plan means
   the change must be reconciled before you apply.

3. **Apply** once the plan is clean:

   ```bash
   terraform apply typedateindex.plan
   ```

   DynamoDB backfills the index asynchronously; the table stays usable during
   the online GSI build.

### Backfilling Historical Items (Operator-Triggered, Default-Off)

The GSI is created regardless of the backfill toggle, and new/updated items
populate it automatically. For **pre-existing** tracking-table items to appear
in `TypeDateIndex` queries (so the UI listing is complete immediately after
upgrade), enable and run the backfill explicitly:

1. **Enable the backfill module** via the new `var.tracking` object, then apply:

   ```hcl
   tracking = {
     enable_gsi_backfill = true
   }
   ```

   ```bash
   terraform apply
   ```

   This provisions `module.tracking_gsi_backfill` — the
   `backfill_gsi_attributes` worker Lambda and a Step Functions **distributed-map**
   state machine — and nothing else. **Applying does not start a run**: there is
   no `aws_lambda_invocation` / auto-start resource, so `terraform apply` never
   mutates tracking data unattended (the machinery is created idle).

2. **Trigger the backfill run explicitly.** Read the state-machine ARN and the
   tracking-table name from state, then start the execution — supplying the
   table name and the number of parallel scan segments the distributed map
   should fan out over:

   ```bash
   # State-machine ARN (the backfill module is count-gated, hence the [0]):
   STATE_MACHINE_ARN=$(terraform state show \
     'module.tracking_gsi_backfill[0].aws_sfn_state_machine.backfill' \
     | awk -F'"' '/^[[:space:]]*arn /{print $2; exit}')

   # Tracking-table name (derived from the root processing_environment output):
   TABLE_NAME=$(terraform output -json processing_environment \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["tracking_table_arn"].split("/")[-1])')

   aws stepfunctions start-execution \
     --state-machine-arn "$STATE_MACHINE_ARN" \
     --input "{\"tableName\":\"$TABLE_NAME\",\"totalSegments\":10}"
   ```

   The distributed map fans the worker across `totalSegments` tracking-table
   scan segments, deriving `ItemType` from each item's PK prefix (`doc#` →
   `document`, `testrun#` → `testrun`, `testset#` → `testset`; `list#` / `agent#`
   skipped) and setting it only where missing. The run is **idempotent** and
   resumes past the Lambda timeout via a continuation token, so it can be re-run
   safely.

3. **Leave the backfill disabled if you don't need historical items indexed.**
   With `tracking = { enable_gsi_backfill = false }` (the default) neither the
   worker Lambda nor the state machine is created; the GSI still exists and new
   items still populate it.

### Rollback

The GSI addition is additive and non-destructive, so there is no data-loss
rollback concern. To revert the configuration, check out the prior tag and
`terraform plan` — note that **removing** a GSI is also an in-place table update
(DynamoDB drops the index; the underlying items are unaffected). The backfill
module, if enabled, is destroyed on rollback (it is stateless machinery — no
tracking data is removed). Back up your DynamoDB tracking table before rolling
back if document processing has occurred on v0.5.12.

---

## Round 2 Feature Adoption (Additive, Default-Off)

The Round 2 subsystems below are all **opt-in and additive**: with their flags
left at the defaults, no new resources are created and existing deployments are
unchanged. No `moved {}` work is required to adopt them.

### Enabling RBAC (C2)

RBAC is a feature-plugin submodule (`modules/features/rbac/`) wired through the
root. Enable it via `var.rbac`:

```hcl
rbac = {
  enabled = true

  # Optional: override any of the four canonical group names. Each key defaults
  # to its canonical value, so overriding one does not change the default-on
  # behavior of the four roles.
  group_names = {
    admin    = "Admin"
    author   = "Author"
    reviewer = "Reviewer"
    viewer   = "Viewer"
  }

  # Optional: comma-separated email domains the user-management Lambda permits
  # when creating users. Empty (default) disables domain restriction.
  allowed_signup_email_domains = ""
}
```

When enabled, the submodule provisions:

- The **four Cognito user-pool groups** `Admin` / `Author` / `Reviewer` /
  `Viewer` (names overridable via `group_names`), with server-side
  `@aws_auth(cognito_groups: [...])` directives enforcing role-to-operation
  access in AppSync.
- The **`Users` DynamoDB table** (user id, email, persona, status, timestamps,
  `allowedConfigVersions`), encrypted with the project KMS key and with
  point-in-time recovery, consistent with the other IDP tables.
- The **user-management Lambda** (create / list / delete users, role
  assignment) with a least-privilege role scoped to the `Users` table and the
  Cognito user-pool admin actions only.
- Server-side **Reviewer document filtering** and **`allowedConfigVersions`
  scoping** for non-Admin callers (`null`/empty = unrestricted).

> **Cognito is required (enforced at plan time).** RBAC requires a Cognito user
> pool. The root ships a `check "rbac_requires_cognito"` that fails
> `terraform plan` — **before any apply** — when `var.rbac.enabled = true` but no
> Cognito user pool is available (neither an external `var.user_identity` nor an
> internally-created pool). This mirrors the CDK `UserManagement` constructor
> guard. The plan error is:
>
> ```text
> RBAC (var.rbac.enabled = true) requires a Cognito user_identity (user pool).
> Configure Cognito (set var.user_identity or let the module create a user pool)
> or disable RBAC.
> ```
>
> Remediation: configure Cognito (set `var.user_identity` or let the module
> create a user pool), or set `rbac = { enabled = false }`.

**Default-off:** with `rbac = { enabled = false }` (the default) no RBAC
resources are created and the pre-Round-2 single-tenant Cognito authorization
behavior is preserved.

### Configuring External SAML/OIDC Federation (C6)

Federation is a feature-plugin submodule (`modules/features/idp-federation/`)
enabled via `var.idp_federation`. SAML example:

```hcl
idp_federation = {
  enabled       = true
  provider_type = "SAML"
  provider_name = "PingOne"

  saml_metadata_url = "https://idp.example.com/saml/metadata"
  # or: saml_metadata_file = file("metadata.xml")

  attribute_mapping    = { email = "email", given_name = "firstName", family_name = "lastName" }
  group_attribute_name = "groups"
  group_mapping        = { "idp-admins" = "Admin", "idp-reviewers" = "Reviewer" }
}
```

OIDC example — the **client secret is supplied by reference, never as
plaintext**:

```hcl
idp_federation = {
  enabled        = true
  provider_type  = "OIDC"
  provider_name  = "OktaOIDC"
  oidc_issuer    = "https://example.okta.com"
  oidc_client_id = "0oa1b2c3d4e5f6g7h8i9"

  # A REFERENCE only: a Secrets Manager secret ARN or an SSM parameter name.
  # The module resolves it at apply time and feeds it ONLY into the Cognito
  # identity provider's provider_details.client_secret. The raw value never
  # appears as a module input value or a non-sensitive output / in plaintext
  # state.
  oidc_client_secret_ref = "arn:aws:secretsmanager:us-east-1:123456789012:secret:oidc-client-secret-AbCdEf"

  oidc_authorize_scopes = "openid email profile"
  attribute_mapping     = { email = "email" }
  group_mapping         = { "oidc-admins" = "Admin" }
}
```

Notes:

- **OIDC client secret by reference (Req 5.3).** Pass `oidc_client_secret_ref`
  as a Secrets Manager ARN or SSM parameter name. The module resolves it at
  apply time (Secrets Manager when the ref looks like a `secretsmanager` ARN,
  otherwise SSM with decryption) and routes the plaintext **only** into
  `provider_details.client_secret`. Do not put the raw secret in tfvars.
- **`COGNITO` is retained.** Federation **additively** adds the external
  provider to the user-pool client's `supported_identity_providers` while
  keeping `COGNITO`, so direct-Cognito sign-in continues to work unless you
  explicitly disable it.
- **Group-mapping trigger for externally-owned pools.** The module provisions a
  group-mapping Lambda that maps external IdP groups/claims onto the four RBAC
  group names. Because `aws_cognito_user_pool_client` is a full resource (not a
  patch-by-id surface), the module does not take ownership of an
  externally-owned pool; instead it surfaces the trigger Lambda ARN as the
  output **`group_mapping_function_arn`**. Wire that as the user pool's
  **PreTokenGeneration** trigger when the pool is owned outside this module. (For
  pools created within the stack, the root performs the wiring.)
- **RBAC group-name alignment.** When both RBAC and federation are enabled, the
  root passes the RBAC group names into federation automatically, so the
  group-mapping Lambda's `*_GROUP_NAME` environment targets the same four roles.

**Default-off:** with `idp_federation = { enabled = false }` (the default) no
federation resources are created and the pool stays configured for direct
Cognito authentication. The submodule still emits its Round 1 feature-plugin
contract (empty when disabled) — that is the wiring architecture, not a
conditional behavior.

### Private Network Deployment + `modules/vpc-endpoints/` (C7)

For a fully private deployment, place the IDP Lambdas in your VPC and provision
the interface/gateway endpoints they need via the root:

```hcl
vpc_subnet_ids         = ["subnet-aaa", "subnet-bbb"]
vpc_security_group_ids = ["sg-xxx"]

private_network = {
  vpc_id              = "vpc-0123456789abcdef0"
  route_table_ids     = ["rtb-aaa", "rtb-bbb"] # for the s3/dynamodb gateways
  private_dns_enabled = true
}

api = {
  visibility = "PRIVATE"
  # ...
}
```

When `var.private_network` is set (with a `vpc_id` and non-empty
`var.vpc_subnet_ids`), the root instantiates `module.vpc_endpoints` and
provisions the interface endpoints required by the **enabled** processors and
features (plus the S3/DynamoDB gateways). The VPC-capable Lambdas are placed in
`var.vpc_subnet_ids` / `var.vpc_security_group_ids`. Leave `var.private_network`
null (the default) for a public deployment — no endpoint resources are created.

> **PRIVATE AppSync requires the `appsync-api` endpoint (enforced at plan
> time).** Setting `var.api.visibility = "PRIVATE"` makes the GraphQL API
> reachable only through the `appsync-api` PrivateLink endpoint. The root ships
> a `check "private_appsync_endpoint_present"` that fails `terraform plan` when
> visibility is `PRIVATE` but the `appsync-api` interface endpoint is not among
> the provisioned set. A companion best-effort
> `check "private_required_endpoints_present"` surfaces any interface endpoint
> an enabled processor/feature needs but that is missing from
> `module.vpc_endpoints`, naming the missing services — so a gap is caught at
> plan time rather than only at runtime. Remediation in both cases: enable the
> missing service(s) on the private-network configuration so
> `module.vpc_endpoints` provisions them.

The `modules/vpc-endpoints/` module renders each `service_name` from the current
region as `com.amazonaws.<region>.<service>`, so it works across partitions
(including `us-gov-*`). Each interface endpoint is individually toggleable;
consumers provision only what they need.

### `BedrockHubRoleArn` Cross-Account Assume-Role (B8)

For a centralized "hub" Bedrock account, opt in by setting the hub role ARN. The
grant attaches in the shared `unified-processor` engine, so all three façades
(BDA / Bedrock-LLM / SageMaker-UDOP) inherit it:

```hcl
# On the relevant processor (or threaded from the root), set:
bedrock_hub_role_arn = "arn:aws:iam::222233334444:role/idp-bedrock-hub"

# Optional ExternalId for the cross-account trust policy:
bedrock_assume_role_external_id = "my-external-id"
```

When set to a non-empty ARN, the Bedrock-calling processing Lambdas are granted
`sts:AssumeRole` scoped to **exactly** that ARN (and no other), and receive
`BEDROCK_ASSUME_ROLE_ARN` (plus `BEDROCK_ASSUME_ROLE_EXTERNAL_ID` when supplied)
in their environment — the exact keys read by
`sources/lib/idp_common_pkg/idp_common/bedrock/session.py` — so Bedrock calls
assume the hub role.

**Fully additive.** When `bedrock_hub_role_arn` is empty/unset (the default),
none of the assume-role policies render and no `BEDROCK_ASSUME_ROLE_*` env var is
set, so an existing same-account deployment shows **no B8-attributable diff** on
`terraform plan` and same-account Bedrock access is unchanged.

---

## Round 3 Feature Adoption (Additive, Default-Off)

The Round 3 items below are all **opt-in and additive**: the config-shape flags
change nothing unless you author them into a configuration document, and the
version-check resolver and W2 dataset deployer create no resources until you
supply their inputs. The one always-on Round 3 change is the tracking-table
`TypeDateIndex` GSI (Breaking Change 6 above) — additive and in-place.

### Config-Shape `x-aws-idp-*` Schema Flags (B9 / B10 / B12)

Three families of `x-aws-idp-*` schema keys carried inside a configuration
document's class / attribute / section schema let the upstream `idp_common`
runtime alter extraction behavior. They are **runtime-enforced upstream** — the
Terraform wrapper's entire role is **faithful pass-through**: the configuration
seeder persists the keys into the configuration DynamoDB table unchanged
(it deep-merges with system defaults and stringifies generically, with no closed
schema / key allow-list). Adding any of these flags requires **no Terraform
change and no new AWS resources** — only an edit to the configuration YAML you
seed.

| Flag (upstream version) | Placement | Effect (enforced in `idp_common`) |
|---|---|---|
| `x-aws-idp-extraction-model` (v0.5.5, B9) | on a class or an attribute | overrides `extraction.model` for that class/attribute only |
| `x-aws-idp-exclude-from-processing` (+ `x-aws-idp-exclusion-reason`) (v0.5.8, B10) | on a class/section | skips LLM extraction/assessment/summarization for sections of that class; the reason is surfaced in UI badges + evaluation reports |
| `x-aws-idp-page-types` / `x-aws-idp-source-page-types` (v0.5.12, B12) | `page-types` on a class, `source-page-types` on a property | distinguishes a **MISSING** field (the page that would carry it was never present) from a **BLANK** field (page present, value empty) |

Example schema fragment demonstrating all three families (see the
`bedrock-llm-processor` example's `config-overlays/round3-x-aws-idp-flags.yaml`
for a complete, seedable overlay):

```yaml
classes:
  - $id: BankStatement
    type: object
    x-aws-idp-document-type: BankStatement
    # B9 — extract this whole class with a stronger model than the doc default:
    x-aws-idp-extraction-model: us.anthropic.claude-sonnet-4-5-20250929-v1:0
    # B12 — declare the named page sub-types this class can contain:
    x-aws-idp-page-types:
      - name: AccountSummary
        x-aws-idp-document-page-content-regex: "(?i)account summary"
    properties:
      ClosingBalance:
        type: string
        # B9 (attribute level) — override the model for just this field:
        x-aws-idp-extraction-model: us.anthropic.claude-opus-4-7:1m
        # B12 — this field only appears on AccountSummary pages; if that page
        # type is absent the field is MISSING (not BLANK):
        x-aws-idp-source-page-types: [AccountSummary]

  - $id: Instructions
    type: object
    x-aws-idp-document-type: Instructions
    # B10 — skip all LLM calls for sections classified as this class:
    x-aws-idp-exclude-from-processing: true
    x-aws-idp-exclusion-reason: instructions
```

- **No action required** unless you want the behavior. Absent the flags, seeding
  is byte-identical to pre-Round-3 output (no flag is injected by default).
- The wrapper never strips, renames, or validates these keys; if a future
  upstream version adds more `x-aws-idp-*` keys, they pass through the same way.

### Enabling the Version-Check Resolver (`getLatestPublishedVersion`, C14)

The `getLatestPublishedVersion` AppSync query lets the web UI surface an "update
available" indicator by reading the latest published IDP version from a public
artifacts S3 bucket. It is **input-gated**: set the bucket name on the `var.api`
object to enable it.

```hcl
api = {
  enabled = true

  # C14 — enable the version-check resolver by naming the public artifacts
  # bucket. Empty (the default) ⇒ the resolver Lambda/data source/resolver are
  # NOT created (default-off, zero plan diff).
  public_artifacts_bucket = "my-org-idp-published-artifacts"

  # Optional — defaults shown. Override only if your bucket layout/region differ.
  public_artifacts_prefix = "artifacts/genai-idp"
  public_artifacts_region = "" # "" ⇒ same region as the deployment
}
```

When `public_artifacts_bucket` is set, the API module provisions the
`version_check_resolver` Lambda (zipped from
`sources/src/lambda/version_check_resolver/`), an AppSync Lambda data source, and
the `Query.getLatestPublishedVersion` resolver. The Lambda's execution role is
**least-privilege**: `s3:GetObject` / `s3:ListBucket` on exactly that bucket
(and its objects) and nothing broader. The GraphQL field already ships in the
read-only schema, so no SDL is injected. Leave `public_artifacts_bucket` empty
(the default) and no version-check resources are created — existing behavior is
preserved.

### Enabling the W2 Dataset Deployer (C16)

The W2 dataset deployer is a Test Studio Lambda that copies the bundled W2
sample dataset into the deployment's test-set bucket/table on demand, mirroring
the existing FCC dataset deployer. It is gated behind a new `enable_w2_dataset`
flag on the `var.api` object and is only created when **Test Studio is also
enabled**:

```hcl
api = {
  enabled = true

  enable_test_studio = true  # required — the W2 deployer is a Test Studio feature
  enable_w2_dataset  = true  # C16 — deploy the bundled W2 sample dataset
}
```

The W2 deployer reuses the shared Test Studio execution role and environment
(`TESTSET_BUCKET` / `TRACKING_TABLE` / `LOG_LEVEL`), and AppSync is granted
`lambda:InvokeFunction` on exactly that function. With either
`enable_test_studio = false` or `enable_w2_dataset = false` (the default) neither
the W2 deployer Lambda nor its data source/resolver is created.

### TypeDateIndex GSI + Backfill (C1)

See **Breaking Change 6** above for the GSI plan gate (confirm the table is
updated **in place**, 0 destroy / 0 create) and the operator-triggered backfill
(`tracking = { enable_gsi_backfill = true }` + the explicit
`aws stepfunctions start-execution` command).

---

## State-Preservation Summary (Round 2)

All Round 2 address changes are **`moved {}`-preserved with a verified
0-destroy / 0-create plan** — the only address-changing refactor is the
`bedrock-llm-processor-vpc` example adopting `modules/vpc-endpoints/` (Breaking
Change 5), and its 17 endpoint moves are confirmed at 0/0 by the plan gate. The
RBAC, federation, VPC-endpoints, `AppSyncVisibility`, `BedrockHubRoleArn`, and
managed-config additions are all new, default-off resources that introduce no
address churn for existing deployments.

**Round 2 introduces no unpreservable recreates.** No stateful resource
(DynamoDB table, S3 data bucket, Cognito pool) is destroyed or recreated by
adopting Round 2; there is no Round-2 recreate requiring an impact/rollback
note beyond the move-only refactor documented above.

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

### Managed Config Seeding (B11, Round 2)

Round 2 seeds the upstream **managed baseline configs** from
`sources/config_library/managed_config/*/config.yaml` (e.g. `fake-w2`,
`docsplit`, `realkie-fcc-verified`, `ocr-benchmark`) into the configuration
DynamoDB table, each row carrying a `managed: true` flag marking it
**non-editable** through the normal config-edit path.

- **Additive.** Seeding only **adds** managed rows; it never overwrites or
  deletes consumer-authored non-managed config rows.
- **Non-editable.** Attempts to edit a `managed: true` row through the normal
  config-write operations are blocked with a "managed / non-editable" error,
  matching the upstream v0.5.2/v0.5.3 behavior (enforcement lives in the
  upstream `config.py`, no `sources/` edits).
- **No action required.** The managed rows appear after apply; existing
  configuration is unaffected.

---

## Migration Checklist

### Round 1 (v0.5.12-tf.0)

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

### Round 2 (v0.5.12-tf.1) — only if affected

- [ ] **`bedrock-llm-processor-vpc` example consumers:** `terraform plan` and
      confirm the 17 endpoint moves show **0 destroy / 0 create** before
      applying (Breaking Change 5). Stop and reconcile if any moved endpoint
      shows create/destroy.
- [ ] **Adopting RBAC:** confirm a Cognito user pool is configured (otherwise
      the `rbac_requires_cognito` check fails at plan); set `var.rbac.enabled`.
- [ ] **Adopting federation:** supply `oidc_client_secret_ref` by reference (no
      plaintext); wire `group_mapping_function_arn` as the pool's
      PreTokenGeneration trigger if the pool is externally owned.
- [ ] **Adopting private networking:** if `var.api.visibility = "PRIVATE"`,
      confirm the `appsync-api` endpoint is provisioned (the
      `private_appsync_endpoint_present` check enforces this at plan time).
- [ ] **Adopting `BedrockHubRoleArn`:** confirm `terraform plan` shows no
      B8-attributable diff when left unset; set `bedrock_hub_role_arn` to opt in.

### Round 3 (v0.5.12-tf.2)

- [ ] **TypeDateIndex GSI (required, Breaking Change 6):** `terraform plan` and
      confirm the tracking table is **updated in place (0 destroy / 0 create)**
      with the `TypeDateIndex` GSI + `ItemType` / `InitialEventTime` attributes
      added. Stop and reconcile if the plan shows the table being
      destroyed/recreated.
- [ ] **Backfilling historical items (optional):** set
      `tracking = { enable_gsi_backfill = true }`, apply, then start the backfill
      explicitly with `aws stepfunctions start-execution` (input
      `{"tableName":"<table>","totalSegments":N}`). Applying alone never mutates
      tracking data.
- [ ] **Config-shape flags (optional, B9/B10/B12):** add
      `x-aws-idp-extraction-model`, `x-aws-idp-exclude-from-processing`
      (+ `x-aws-idp-exclusion-reason`), and/or `x-aws-idp-page-types` /
      `x-aws-idp-source-page-types` to your seeded config YAML. No Terraform
      change required; they pass through the seeder unchanged.
- [ ] **Version-check resolver (optional, C14):** set
      `api.public_artifacts_bucket` to enable `getLatestPublishedVersion`. Leave
      empty for default-off.
- [ ] **W2 dataset deployer (optional, C16):** set
      `api.enable_test_studio = true` and `api.enable_w2_dataset = true`.

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
