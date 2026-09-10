# Changelog

All notable changes to the Terraform implementation are documented here.

Format: `vX.Y.Z-tf.N` where `X.Y.Z` is the upstream IDP version and `tf.N` is the Terraform iteration.

---

## [Unreleased] — 0.6.4-tf.0 (in progress)

Upgrade to upstream IDP v0.6.4. See
[docs/migration-v0.5.16-to-v0.6.4.md](docs/migration-v0.5.16-to-v0.6.4.md) for
the migration steps behind every breaking change below.

### Breaking Changes

- **Processor inputs collapsed into one `processor` variable.** The three
  mutually exclusive root variables `bedrock_llm_processor`, `bda_processor`, and
  `sagemaker_udop_processor` are replaced by a single required `processor` object
  with a `type` discriminator (`bedrock-llm`, `bda`, or `sagemaker-udop`). Move
  your old block under `processor` and add `type`. The `type` value drives which
  fields are required: `bda` needs `project_arn`, `sagemaker-udop` needs
  `classification_endpoint_arn`. This is an input-surface rename only. Internal
  module block names are unchanged by design, so no `moved {}` blocks and no
  state migration are required, and a plan shows no resource churn. See
  [docs/migration-v0.5.16-to-v0.6.4.md](docs/migration-v0.5.16-to-v0.6.4.md).
- **AWS AppSync removed; the UI/API transport is now an API Gateway REST API.**
  Upstream deleted AppSync in v0.6.0. Queries/mutations go through a single
  dispatcher Lambda at `POST /op/{field}`, status updates are polled, and chat
  tokens stream from a Lambda Function URL. The API module's `graphql_url`,
  `realtime_url`, `api_key`, and `appsync_endpoint_for_dns` outputs are replaced
  by `api_base_url`.
- **ALB Web UI hosting removed** (`web_ui.hosting = "ALB"`), following upstream's
  deletion of the `nested/alb-hosting/` stack. `modules/web-ui-alb`, the
  `web_ui.alb` input, and the `web_ui_alb` output are gone. `removed-v0-6-4.tf`
  ships `removed` blocks so a direct upgrade can still decommission the ALB.
- **Root `required_version` raised to `>= 1.7.0`**, required by those `removed`
  blocks. The effective floor was already 1.5 (existing `check` blocks).
- **`api.visibility` renamed to `api.api_gateway_visibility`.** The old name
  still works and takes precedence, with a deprecation `check`; it will be
  removed in a future release.
- **Step models are now config/system-default authoritative, not pinned to
  `var.model_id`.** Previously the engine force-wrote `classification.model`,
  `extraction.model`, and `summarization.model` from `coalesce(per_step_var,
  var.model_id)`, so a deployment that set no model variables silently ran
  `us.amazon.nova-2-lite-v1:0` for every step and ignored the models the config
  library / upstream system defaults declare. Terraform now writes those keys
  only when the corresponding per-step variable is explicitly set; otherwise the
  config YAML (then the upstream system default, then `var.model_id` as a
  backstop) wins. **Deployments that set no model variables will change which
  models they invoke** — e.g. extraction moves from `nova-2-lite` to the v0.6
  default `us.anthropic.claude-sonnet-5` — changing inference results and cost.
  To keep the prior behaviour, set `classification_model_id`,
  `extraction_model_id`, and `summarization_model_id` (or the per-processor
  equivalents) explicitly to `us.amazon.nova-2-lite-v1:0`.
- **The seeder no longer overwrites operator-edited configuration on every
  apply.** The active `Config#default` row is now written read-modify-write:
  once it has diverged from what Terraform last seeded (an edit made in the Web
  UI), the seeder leaves it intact instead of clobbering it. Operators who
  relied on `terraform apply` reasserting configuration must use the documented
  force procedure (delete the `TerraformSeed#default` marker item, then
  `terraform apply -replace=...seed_default`) to reassert Terraform's config.
  This is also the supported path for adopting the model-authority defaults above
  on a deployment whose config row was already edited.

### Added

- **`web_ui.hosting = "APIGateway"`** — serves the SPA as an S3 proxy on the same
  REST API and stage as the data transport, so the UI inherits the API's PRIVATE
  endpoint and WAF posture. Replaces ALB hosting for VPC-only deployments; needs
  no CloudFront, ALB, ACM certificate, or S3 VPC endpoint.
- **Chat token streaming** via a Lambda Web Adapter function behind a
  `RESPONSE_STREAM` Function URL, replacing the AppSync
  mutation-to-subscription fan-out. Surfaced to the UI as `VITE_STREAM_URL`.
- `api.use_private_api`, `api.api_gateway_vpc_endpoint_id`, and
  `api.waf_allowed_ipv4_ranges`, mirroring the upstream parameters.
- **`preprocessing` and `postprocessing` pipeline hook points.** Two generic
  extension points added in IDP v0.6, alongside the six existing per-step
  `<step>.postHook` lists. `preprocessing` runs before the BDA/pipeline routing
  decision (so it fires in both processing modes, and can halt an execution as
  `REDACTED_SUPERSEDED` when it spawns a redacted copy); `postprocessing` runs
  last, after evaluation, on the shared tail. Inert until a config version
  populates the section.
- **`ocr.backend: bda`** — runs a Bedrock Data Automation standard-output SYNC
  project as a pure OCR engine in place of Textract. Enable with the new
  `enable_bda_ocr_backend` flag on any processor. The deployment-scoped project is
  created and deleted with the deployment.
- **Configuration seeder edit-preservation provenance.** The seeder records what
  it wrote as a sibling DynamoDB item, `Configuration = "TerraformSeed#<version>"`,
  holding a hash of the seeded config. On the next apply it compares the stored
  row against that hash to tell "Terraform's desired config changed" (update)
  from "an operator edited the row" (skip). The marker is a separate item, never
  a top-level attribute on the config row, so the runtime config loader never
  surfaces it as a configuration section (`list_config_versions` only scans
  `Config#*`). A row with no marker (a pre-existing deployment) is adopted once
  on first upgrade. Divergence detection is deliberately coarse: **any** change
  to the stored row freezes the whole row against future Terraform config
  updates until the marker is deleted.
- **Plan-time Bedrock model-ID validation.** Each resolved per-step model ID is
  checked against a model-ID/ARN shape before it is used to build an IAM ARN, so
  a typo in a config-YAML model fails `terraform plan` naming the step and value
  rather than producing a malformed ARN / `AccessDenied` at invoke time.

### Changed

- Private networking requires the `execute-api` interface VPC endpoint instead of
  `appsync-api`; `modules/vpc-endpoints` renames its `appsync_api_endpoint_id`
  output to `execute_api_endpoint_id`.
- The pipeline-hooks dispatcher timeout is raised from 60s to 900s. It fronts
  hooks synchronously, and upstream budgets up to ~890s for the PII-redaction
  preprocessing hook, so 60s would sever the invoke.
- `idp_common` layer extras are reconciled with v0.6.4's `pyproject.toml`:
  `criteria_validation` → `rule_validation`, and `multi_document_discovery` /
  `synthesis` / `code_intel` are now accepted. `analytics` was never a real extra
  and is rejected. This matters because pip does not fail on an unknown extra — it
  installs nothing for it — so a stale name produced a layer silently missing
  dependencies at runtime.

### Fixed

- **BDA (pattern-1) deployments no longer seed an unmerged configuration.**
  Upstream v0.6.4's `system_defaults/pattern-1.yaml` inherits
  `base-assessment.yaml`, a file that release deleted, and the merge raises
  `FileNotFoundError` on a missing inherited file. Every BDA deployment therefore
  fell back to storing the raw user config with no default prompts, models, or
  classes. The seeder now retries with a loader that skips absent inherits, which
  is semantically correct since assessment is retired in the v0.6 config model.
- **Cross-region inference profiles with a `global.`, `ca.` or `sa.` prefix now
  receive their IAM grant.** v0.6 defaults ship
  `global.anthropic.claude-sonnet-4-6`, but all three copies of the model-ID IAM
  derivation matched only `us|eu|apac`, so such models got the foundation-model
  grant without the inference-profile grant — an `AccessDenied` at invoke time.
  The `agent-analytics` copy additionally stripped the prefix with
  `substr(id, 3, -1)`, which mangled `apac.` IDs; it now uses the same regex as
  the others.
- Evaluation without summarization passed the whole Step Functions state envelope
  to the evaluation Lambda as its `document`, instead of the document.
- With neither summarization nor evaluation enabled, the workflow's final output
  was the raw envelope, so the workflow tracker matched `output_data["document"]`
  and persisted the original pre-OCR document rather than the processed one.
- The workflow tracker can now delete an original superseded by a redacted copy:
  it gains `INPUT_BUCKET` plus the S3 rights to purge the input object and all
  versions under the output prefix.
- **The per-step Bedrock IAM allowlist is derived from the effective
  configuration, so a grant can no longer disagree with the model the runtime
  invokes.** Previously `classification`, `extraction`, and `summarization` were
  pinned to `coalesce(per_step_var, var.model_id)` for both the seeded config and
  IAM, while `evaluation`/`assessment` already read the config — the two
  asymmetries cancelled out and hid the bug. All five steps now resolve through
  one expression (per-step variable → config → upstream system default →
  `var.model_id`) and share a single model-ID→ARN transform, so the grant always
  matches the seeded model. The system-default layer is read directly from
  `sources/.../system_defaults/base-*.yaml`, because those models are merged into
  the config by the seeder Lambda at apply time and are otherwise invisible to
  Terraform.
- **Assessment (confidence) invocations no longer `AccessDenied`.** v0.6 folded
  assessment under `extraction.confidence`; the assessment Lambda invokes
  `extraction.confidence.model` (default `us.amazon.nova-lite-v1:0`) and, on
  low-confidence sections, `extraction.confidence.escalation_model` (default
  `us.anthropic.claude-sonnet-5:1m`). The assessment role now grants both,
  resolved from the effective config, instead of a single model derived from the
  wrong key.
- **The legacy un-stripped assessment IAM fallback is removed.** When no
  assessment model resolved, `iam.tf` built
  `foundation-model/${var.assessment_model_id}` without stripping the geographic
  prefix, producing a malformed ARN; the grant now comes from the shared,
  prefix-aware transform.
- **OCR / process-results / assessment roles can write the tracking table when
  the API is enabled.** These roles gated the `dynamodb:UpdateItem` grant on the
  tracking table behind `var.enable_api ? [] : [...]` — stale v0.5 logic assuming
  the API path wrote status via AppSync. v0.6 removed AppSync and backend workers
  write status to DynamoDB directly, so with `enable_api = true` (every web-UI
  example) the pipeline failed at the OCR step with
  `AccessDeniedException ... dynamodb:UpdateItem`. The grant is now unconditional.
- **`api.visibility` validation no longer crashes on its null default.** The
  deprecated-field validation was `var.api.visibility == null ||
  contains([...], var.api.visibility)`; Terraform does not short-circuit `||`
  when the right side's `contains(list, null)` throws, so `terraform validate` /
  `plan` failed for every example. Rewritten as a null-guarding ternary.

### Not applicable

- Upstream's `EnableHeadless` → `EnableJobsApi` rename (v0.6.2) needs no wrapper
  change: the wrapper does not implement the upstream Jobs API (no `/jobs`
  Private API Gateway, `api_handler`/`job_tracker`/`batch_pre_processor`
  Lambdas, machine-to-machine OAuth client, or bastion). The wrapper's
  `enable_api = false` "headless" posture is an unrelated concept and is
  unchanged. See the migration guide.
- Backend workers write status to DynamoDB directly (`APPSYNC_API_URL=""`),
  matching upstream, and the UI polls for updates.
- Upstream's `PermissionsBoundaryArn` fix for the Feature Platform nested stack
  (v0.6.1) needs no wrapper change, because there are no nested stacks to forward
  it to. Note separately that the wrapper does not implement permissions
  boundaries at all — upstream added them in v0.3.9, so this is a pre-existing gap
  rather than a regression in this release, and it is tracked as follow-up work.
  Accounts whose SCP requires a boundary on every IAM role cannot deploy this
  wrapper. See the migration guide.
- Feature-Platform registration of the new `preprocessing` / `postprocessing` hook
  points needs no wrapper change: the vendored `register_feature_hooks` Lambda
  already accepts both flat points.

---

## [0.5.16-tf.0]

> This release bundles two tracks: the **local-build** work (`var.build`,
> below) that landed on `v0.5.16-rc`, and the **upstream v0.5.16 parity
> upgrade** (sources snapshot + feature parity), documented in its own block
> at the end of this release's notes.

### Summary

Adds the `var.build` object, introducing an opt-in path that builds
Lambda layers and processor container images locally on the deploy host
using Docker / Podman / Finch, replacing AWS CodeBuild for those steps.
Non-breaking: defaults preserve the historical CodeBuild path
bit-for-bit. Set `build.lambda_local = true` to opt in.

Activates `build.ui_local` (previously reserved): when `true`, the web UI
React/Vite build runs locally via `npm ci && npm run build` on the deploy
host with direct S3 sync + CloudFront invalidation, eliminating the last
CodeBuild project from the stack. Requires Node.js >= 18 on the deploy host.

### Added

- **`var.build` (root)** — new object with fields:
  - `lambda_local` (bool, default `false`) — when `true`, all Lambda
    layers and processor container images build locally on the deploy
    host; AWS CodeBuild infrastructure collapses to `count = 0`.
  - `lambda_architecture` (string, default `"arm64"`, validated against
    `["x86_64", "arm64"]`) — target Lambda architecture, honored by
    both CodeBuild and local-build paths. The CodeBuild path now gains
    arm64 support (previously hardcoded x86_64). The default was flipped
    from `x86_64` to `arm64` in this release to match upstream v0.5.16
    (see the parity-upgrade block below for the migration note).
  - `container_runtime` (string, default `"auto"`, validated against
    `["auto", "docker", "podman", "finch"]`) — runtime selector when
    `lambda_local = true`. `"auto"` probes docker → podman → finch.
  - `ui_local` (bool, default `false`) — when `true`, builds the web
    UI locally on the deploy host via `npm ci && npm run build`,
    syncs to S3, and invalidates CloudFront — eliminating the UI
    CodeBuild project, trigger Lambda, and supporting IAM. Requires
    Node.js >= 18.
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
- **`modules/web-ui-build-check`** — probes the host for Node.js >= 18
  via `scripts/detect-node-runtime.sh`; fails plan with per-OS install
  instructions when `ui_local = true` and Node.js is missing or too old.
- **Build script** `scripts/build-web-ui.sh` — runs `npm ci && npm run
  build` in `sources/src/ui/`, syncs `build/` to S3, and invalidates
  CloudFront.
- **Detection script** `scripts/detect-node-runtime.sh` plus
  `tests/validate-web-ui-build-check.sh` unit test.
- **Documentation page** `docs/content/deployment-guides/local-web-ui-build.md`
  covering Node.js prerequisites and the local UI build flow.

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

### Upstream v0.5.16 parity upgrade

#### Summary
Advances the vendored `sources/` tree from upstream `0.5.12` to `0.5.16` and
reimplements the Terraform-side feature parity across `0.5.13–0.5.16`: web-UI
CloudFront OAC, arm64 Lambda default, OpenAI GPT-5.x IAM, pipeline hooks, the
Feature Platform, and ALB hosting. The `sources/` snapshot also carries
upstream runtime behavior for those versions regardless of Terraform wiring.

#### Added
- **Web UI ALB hosting** (`web_ui.hosting = "ALB"`): new `modules/web-ui-alb`
  serves the web app bucket through an internal Application Load Balancer + S3
  interface VPC endpoint (host-header/url rewrite via `aws_lb_listener_rule`
  `transform` blocks), for private-network / GovCloud deployments. New
  `web_ui.alb` inputs (`vpc_id`, `subnet_ids`, `certificate_arn`, `scheme`,
  `allowed_cidrs`, `lambda_security_group_id`), `web_ui.custom_domain_url`
  (CORS + Cognito callback/logout URLs), and `web_ui.s3_presigned_url_via_vpc_endpoint`
  / `s3_vpc_endpoint_dns_name_override` / `s3_vpc_endpoint_id_override`
  (presigned URLs via the VPCE). New `web_ui_alb` root output. Mirrors upstream
  `WebUIHosting` / `CustomDomainUrl` / `S3PresignedUrlViaVpcEndpoint`.
- **Feature Platform** (`feature_platform.enabled`, default `false`): optional
  `modules/features/feature-platform` (InstalledFeatures table + 9 Lambdas + 9
  AppSync datasources + 12 resolvers) for installable feature catalog /
  entitlement / install / register operations.
- **Pipeline hooks**: a dispatcher Lambda wired into the Step Functions
  workflow at five inert-by-default extension points (`postOcr`,
  `postClassification`, `postExtraction`, `postAssessment`,
  `postSummarization`).
- **OpenAI GPT-5.x IAM**: `bedrock-mantle:*` permissions on all 11
  model-invoking roles so GPT-5.x models served via bedrock-mantle can be used.
- **`web_ui.console_title`** (default `"IDP Accelerator Console"`): top-nav
  banner title (upstream `ConsoleTitle`).
- **`updateTestSet`** AppSync resolver (Test Studio).
- **`api.appsync_endpoint_for_dns`** output for private-DNS wiring.
- **`user-identity`**: `additional_callback_urls` / `additional_logout_urls`
  to register the Web UI custom domain with Cognito.

#### Changed
- **CloudFront OAI → OAC**: the web-UI distribution now uses an Origin Access
  Control (sigv4) with a bucket policy scoped to the distribution ARN,
  replacing the legacy Origin Access Identity.
- **`build.lambda_architecture` default `x86_64` → `arm64`** to match upstream
  v0.5.16 (both values remain selectable).
- **Config defaults (D5)**: `classification.enforceValidClasses` and
  `assessment.ground_geometry_in_ocr` are default-on, carried by the vendored
  `idp_common` system defaults and merged into every seeded config by the
  configuration seeder (no Terraform change).

#### Migration
- **arm64 default**: existing deployments that omit `build.lambda_architecture`
  will rebuild/replace Lambda layers and container images for arm64 on the next
  apply. Pin `build = { lambda_architecture = "x86_64" }` to keep the previous
  architecture.
- **OAI → OAC**: plan shows the OAI destroyed and an OAC created; the CloudFront
  distribution updates in place (no replacement). Review the plan to confirm.
- **ALB hosting** requires `web_ui.alb.vpc_id`, ≥2 `subnet_ids`, and an ACM
  `certificate_arn`; point the custom domain DNS at the `web_ui_alb` output
  `alb_dns_name` / `alb_hosted_zone_id`. The ALB path is acyclic: the custom
  domain URL and the presign VPCE DNS name are supplied as inputs, not derived
  from the ALB module.
- **Snapshot-carried behavior**: the `0.5.13–0.5.16` `sources/` refresh changes
  runtime behavior (prompts, default model IDs, granular assessment) regardless
  of Terraform variables.

---

## [0.5.12-tf.0] - 2026-07-02

### Summary

Upgrade from `0.4.16-tf.2` to the upstream IDP v0.5.12 line. The
vendored `sources/` snapshot is refreshed to v0.5.12 and the three version markers
are realigned (`IDP_VERSION` → `0.5.12`, `sources/VERSION` → `0.5.12`, `VERSION` →
`0.5.12-tf.0`).

The headline change is the **per-pattern processor façade** model: a single shared
internal engine (`modules/processors/unified-processor`) with three thin public
façades (`bda-processor`, `bedrock-llm-processor`, `sagemaker-udop-processor`) that
delegate to it, mirroring the CDK accelerator's `UnifiedDocumentProcessor` plus
per-pattern processor constructs. Auxiliary features are restructured as
**feature-plugins** wired through an `enabled_feature_contracts` contract, with the
legacy `var.api.*` flags still forwarded for a transition window. On top of that,
this release adds the production-readiness subsystems (RBAC, external SAML/OIDC
federation, private-network VPC endpoints) and a batch of additive parity drop-ins
(inference-profile IAM, reporting column, model enablement, MCP rename,
chat-with-document streaming, Python 3.12 runtimes, config-shape schema flags,
version-check resolver, W2 dataset deployer, tracking-table GSI).

This release carries breaking changes to module internal addresses (processor façade
refactor, MCP rename) and a VPC-endpoints example refactor, all of which ship
`moved {}` blocks so a normal upgrade plans **0 destroy / 0 create** for preservable
resources; see [Breaking Changes](#breaking-changes) and the migration notes below.
Per-subsystem defaults are documented under each feature below; some subsystems
(Chat-with-Document, Knowledge Base, discovery, managed-config seeding) default on at
the module level, while others (RBAC, IdP federation, private networking, the
version-check resolver, the W2 deployer, and the GSI backfill) default off.

No file under `sources/` is modified outside the snapshot refresh.

### New Features & Changes

#### Processor façades over a shared engine

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
    endpoint via the native SageMaker classification backend
    (`classification_backend = "sagemaker"`); it creates no SageMaker
    hosting/training.
- Root wiring instantiates the three façades count-gated from
  `var.bda_processor` / `var.bedrock_llm_processor` / `var.sagemaker_udop_processor`,
  with an exactly-one-façade validation replacing the old
  `check "single_processor_required"`.

#### Feature-plugin wiring

- Self-contained feature submodules — `modules/features/mcp-integration`,
  `modules/features/chat-with-document`, and `modules/features/hitl` — are composed
  into `processing-environment-api` via an `enabled_feature_contracts` contract
  (resolvers, IAM statement fragments, env wiring, optional GraphQL SDL) using
  `for_each`. This mirrors the CDK `api.enable(feature)` idiom.
- Legacy `var.api.*` flags (`enable_mcp`, the chat flag, `enable_hitl`, …) are
  forwarded via root `locals` to enable the matching feature submodule; `var.api.*`
  is still accepted as a transition path.

#### RBAC + `Users` table feature-plugin submodule

- New self-contained feature-plugin submodule `modules/features/rbac/` (composed
  into `processing-environment-api` via the feature-plugin contract — mirrors the
  CDK `api.enable(userManagement)` idiom).
- Provisions the four Cognito user-pool groups (`Admin`, `Author`, `Reviewer`,
  `Viewer`) with default-or-override names, a `Users` DynamoDB table (KMS-encrypted
  via `encryption_key_arn`, point-in-time recovery enabled) storing user id, email,
  persona, status, timestamps, and `allowedConfigVersions`, and a least-privilege
  user-management Lambda.
- Server-side **Reviewer document filtering** and **`allowedConfigVersions` scoping**
  are enforced in the resolver/Lambda layer (not the web UI), so the restriction
  cannot be bypassed by a direct API call; the profile query exposes
  `allowedConfigVersions`.
- The user-management role grants only `dynamodb:{GetItem,PutItem,UpdateItem,DeleteItem,
  Query,Scan}` on the `Users` table (+ its KMS key) and the Cognito admin actions
  required for group membership, scoped to the user-pool ARN.
- Default-off: with `var.rbac` unset, no RBAC resources are created and the
  pre-existing single-tenant Cognito authorization behavior is preserved.

#### External SAML/OIDC IdP federation feature-plugin submodule

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
  to the four RBAC group names at sign-in.
- Default-off: with `var.idp_federation` unset, no federation resources are created
  and the user pool stays configured for direct Cognito authentication.

#### Private Network Deployment + standalone `vpc-endpoints` module

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

#### Additive parity drop-ins

- **Bedrock inference-profile IAM.** `bedrock:GetInferenceProfile` +
  `application-inference-profile/*` added to the unified engine IAM.
- **Glue reporting `config_version` column.** Additive column on the reporting table.
- **Default extraction model bump.** Off the retired Claude 3.5 Sonnet to
  `us.anthropic.claude-sonnet-4-5-20250929-v1:0` across modules and examples.
- **Claude Opus 4.7 enablement.** Added to model picklists/validation/pricing, plus
  an Opus 4.7 sample tfvars.
- **MCP integration submodule.** Renames `agentcore_analytics_processor` →
  `agentcore_mcp_handler`, provisions the OAuth resource server, preserves the
  GovCloud guard, and stays default-off.
- **Chat-with-Document async streaming resolver(s).** Honors a `chat:` config block
  with `summarization.*` fallback and default `us.anthropic.claude-opus-4-7:1m`.
- **Python 3.12 runtimes.** Lambda runtimes moved to Python 3.12; layer builds use
  pypdfium2 (PyMuPDF removed) via buildspec-only changes (no `sources/` edits).
- **`AppSyncVisibility` at the root API layer.** `var.api.visibility`
  (`GLOBAL` / `PRIVATE`) is threaded into `processing-environment-api`, which sets
  `aws_appsync_graphql_api.visibility` and validates the value. Unset defaults to
  `GLOBAL`.
- **`BedrockHubRoleArn` cross-account assume-role.** Optional assume-role for a
  centralized Bedrock "hub" account, added on the unified-processor engine execution
  role(s) so all three façades inherit it; scoped to exactly `var.bedrock_hub_role_arn`
  when set, fully additive when unset.
- **`managed_config` baselines seeded as `managed: true` rows.** The configuration
  seeder seeds the baselines under `sources/config_library/managed_config/*/config.yaml`
  as rows carrying `Managed = true`. Additive: new managed rows only — consumer-authored
  rows are never overwritten or deleted.
- **Per attribute / per section schema flags.** `x-aws-idp-extraction-model`,
  `x-aws-idp-exclude-from-processing` (with optional reason), and
  `x-aws-idp-page-types` / `x-aws-idp-source-page-types` are carried through the
  configuration seeder unchanged (runtime enforces them; no new resources).
- **Version check resolver.** A `getLatestPublishedVersion` AppSync query backed by a
  Lambda that reads the latest published IDP version from a public artifacts S3
  bucket, so the web UI can show an "update available" indicator. Gated on
  `var.api.public_artifacts_bucket` (default empty), with a least-privilege read role
  scoped to exactly that bucket.
- **W2 dataset deployer.** A Test Studio dataset deployer mirroring the FCC deployer,
  gated by `var.api.enable_w2_dataset` (default false) and only when Test Studio is
  enabled.
- **`TypeDateIndex` GSI on the tracking table.** Lets the list resolvers query
  documents, test runs, and test sets by type and time range instead of scanning the
  whole table. Created by default; new and updated items populate it automatically.
- **Tracking GSI backfill.** An operator-triggered Step Functions backfill that
  populates the new GSI attributes on items predating the index. Gated by
  `var.tracking.enable_gsi_backfill` (default false), least-privilege scoped, and
  never runs on `apply`.

### Fixed

- **SageMaker UDOP classification.** The processor classifies through idp_common's
  native SageMaker backend, which calls the endpoint directly with the `input_image`
  and `input_textract` payload the UDOP model expects. A `classification_backend`
  input was added to the unified processor (default `bedrock`, so BDA and Bedrock-LLM
  are unaffected); the SageMaker-UDOP façade sets it to `sagemaker` and the engine
  grants the classification Lambda `sagemaker:InvokeEndpoint` on the supplied endpoint.
- **First-apply count race.** Gated feature IAM policies (hook-inference,
  composed-feature IAM) on plan-time-known flags so a clean apply no longer aborts
  with an "Invalid count argument" error when names derive from a not-yet-known random
  suffix.
- **Chat-with-Document on empty system prompt.** The system-prompt lookup falls back
  correctly when the configured value is empty instead of leaving the chat request
  stuck behind queue state.
- **Processor OCR layer.** The shared idp_common layer is built with the `ocr` extra
  on all processor paths, so the OCR step has `pypdfium2` available.
- **BDA routing default.** The BDA façade forces `use_bda = true` onto its seeded
  default config so it routes to the BDA branch out of the box; a consumer config that
  already sets `use_bda` still wins.

### Tooling

- **`make security` (tfsec) reworked to a per-module scan.** tfsec 1.28.x cannot
  parse Terraform 1.5+ `check {}` / `removed {}` blocks — such a block anywhere in a
  scanned root module is a fatal parse abort before result filtering, so the previous
  `tfsec . --exclude-path main.tf` invocation never actually skipped those files. The
  target now scans each module directory individually (the only exclusion form that
  works in 1.28.x), skipping directories whose `.tf` files carry `check {}`/`removed {}`
  glue. `make all` now completes green.
- The new modules pass tfsec strictly (`rbac`, `idp-federation`, `vpc-endpoints`,
  `processor-configuration`). Pre-existing findings are scanned with `--soft-fail`
  (printed, non-blocking) for a fixed allowlist of modules that carried findings before
  the v0.5.12 work; every module not on that allowlist is scanned strictly.

### Breaking Changes

- **Processor façade refactor (module internal address change).** Per-pattern
  processor internals now live under `module.<facade>[0].module.engine.*`. `moved {}`
  blocks remap the old `module.bda_processor.*` / `module.bedrock_llm_processor.*` /
  `module.sagemaker_udop_processor.*` addresses into the new façade→engine nested
  addresses (SQS, DDB, ECR, CloudWatch) — target **0 destroy / 0 create** for the
  moved resources. Some BDA/UDOP-only resources (ECR/CodeBuild and other
  pattern-specific resources) are unavoidable recreates.
- **Pattern 3 monolith replaced.** The former monolithic SageMaker-UDOP module is
  replaced by the new `sagemaker-udop-processor` façade over the shared engine.
- **MCP Lambda rename.** `agentcore_analytics_processor` → `agentcore_mcp_handler`.
  A `moved {}` block preserves the resource (and its `function_name`) into the
  feature-submodule address.
- **`var.api` flags object → feature-plugin wiring.** Auxiliary features are now
  enabled through the feature-plugin contract. `var.api.*` flags are still forwarded
  during the transition window.
- **Removed orphaned `pattern2-hitl` trio.** The
  `pattern2-hitl-{process,wait,status-update}` handlers in `modules/human-review/`
  referenced `sources/` paths that never existed upstream; they are removed (HITL is
  the feature-plugin submodule + `complete_section_review`).
- **Removed legacy synchronous chat module.** The in-API
  `modules/processing-environment-api/chat-with-document/` submodule is removed and
  replaced by the self-contained `modules/features/chat-with-document/` feature-plugin
  (async streaming, composed via `enabled_feature_contracts`).
- **Removed standalone Error Analyzer Lambdas.** The `error_analyzer` and
  `error_analyzer_resolver` Lambdas (and their IAM roles, log groups, VPC attachments,
  and AppSync datasource) were removed upstream at v0.5.12. Error analysis is now
  provided by the unified agents framework (`Error-Analyzer-Agent`), surfaced via the
  generic agent resolvers. `removed {}` blocks (with `destroy = false`) drop the
  orphaned resources from state without destroying real infrastructure;
  `var.enable_error_analyzer` is retained as a deprecated no-op.
- **`vpc-endpoints` example refactor (module internal address change).** The
  `bedrock-llm-processor-vpc` example consumes `modules/vpc-endpoints/` in place of its
  inline `aws_vpc_endpoint.*` resources, and sets `AppSyncVisibility = "PRIVATE"`. The
  change ships `moved {}` blocks mapping each old inline endpoint address into the
  module, so a normal plan shows **0 destroy / 0 create** for the moved endpoints.
- **Tracking table `TypeDateIndex` GSI added in place.** Adding the GSI (and its
  `ItemType` / `InitialEventTime` attributes) is a non-destructive in-place update in
  the AWS provider — no resource is replaced and no `moved {}` block is needed. Still,
  confirm the table reports 0 destroy / 0 create before applying.

### Migration

New root variables `var.rbac`, `var.idp_federation`, `var.private_network`,
`var.api.visibility`, `var.bedrock_hub_role_arn`, and `var.tracking` are introduced.
These default off, so leaving them unset does not enable those subsystems. Note that
some other subsystems (Chat-with-Document, Knowledge Base, discovery, and
managed-config seeding) default on at the module level; review the per-feature
defaults above and set the corresponding variables if you want the previous behavior.

Key steps:

1. **Upgrade the module** and run `terraform plan`. The bundled `moved {}` blocks
   remap the per-pattern processor internals into the new façade→engine addresses
   (`module.<facade>[0].module.engine.*`), the renamed MCP Lambda
   (`agentcore_analytics_processor` → `agentcore_mcp_handler`), and the VPC-endpoints
   example addresses automatically — no manual `terraform state mv` is required for the
   preservable resources.
2. **Confirm the move is non-destructive.** The moved resources (SQS, DynamoDB wiring,
   ECR repo, CloudWatch resources, MCP Lambda, VPC endpoints) MUST report **0 destroy /
   0 create** before you apply. If they show destroy/create, stop and re-check the
   `moved {}` mapping against your state addresses. Back up state first:
   `terraform state pull > backup.tfstate`.
3. **Accept the unavoidable recreates.** Some BDA/UDOP-only resources (ECR/CodeBuild
   and other pattern-specific resources) are recreated.
4. **`TypeDateIndex` GSI backfill (optional).** For items that predate the GSI to
   appear in `TypeDateIndex` queries, opt in and run the backfill; `apply` provisions
   the machinery but never starts a run:

   ```bash
   # tfvars:  tracking = { enable_gsi_backfill = true }
   terraform apply
   aws stepfunctions start-execution \
     --state-machine-arn <state_machine_arn> \
     --input '{"tableName":"<tracking_table_name>","totalSegments":10}'
   ```

5. **No tfvars changes required for the transition.** `var.api.*` flags are still
   forwarded to the new feature-plugins, so existing tfvars keep working; migrate to
   feature-plugin wiring at your own pace.
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
