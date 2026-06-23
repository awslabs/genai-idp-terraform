# Plan Artifact: VPC-endpoints `moved {}` — 0 destroy / 0 create

**Spec tasks:** `idp-v0.5.12-round-2` task 12.2 (breaking-change plan artifact)
**and** task 4.2 — **Property 11: Address-changing refactors preserve
infrastructure (moved 0/0)**. Both tasks share the same gate (a verified
0-destroy/0-create plan) and the same offline constraint, so this single artifact
satisfies both.
**Requirements:** 15.2 (breaking-change plan artifact), 12.1 / 12.2 (moved-block
state-migration discipline)

> **Property 11 / task 4.2 framing.** Property 11 asserts that, against a
> representative state holding the old inline endpoints, the post-`moved` plan
> shows 0 destroy / 0 create for each moved endpoint — and that the *verified
> plan*, not the mere presence of the `moved {}` blocks, is the gate. Per the
> design Notes ("What needs real state / a live plan"), this property "is not
> provable from static files": it needs AWS credentials + a representative
> `bedrock-llm-processor-vpc` state. What *is* verifiable offline — and is
> verified in this artifact — is (a) `terraform validate` of the example, (b) the
> exact, complete, correctly-targeted 17-block `moved {}` mapping against the
> `modules/vpc-endpoints/` resource addresses, and (c) the precise consumer/CI
> commands that constitute the live gate. The realized form of Property 11 is
> therefore this migration-plan artifact + the documented gate procedure, not a
> generative property test (see tasks.md "PBT framing").
**Breaking change:** Migration guide
[Breaking Change 5: `bedrock-llm-processor-vpc` Example Adopts `modules/vpc-endpoints/` (C7)](../migration-v0.4.16-to-v0.5.12.md#breaking-change-5-bedrock-llm-processor-vpc-example-adopts-modulesvpc-endpoints-c7)
**Example under test:** `examples/bedrock-llm-processor-vpc/`

---

## Purpose

The Round 2 refactor moves the example's ~17 inline `aws_vpc_endpoint.*`
resources into the reusable `modules/vpc-endpoints/` module. This is an
**address-changing refactor of live infrastructure**, so per
`breaking-changes.md` it ships with `moved {}` blocks and is gated on a
`terraform plan` that shows **0 destroy / 0 create** for every moved endpoint.

Per Req 12.1, **the verified 0/0 plan — not the presence of the `moved {}`
blocks — is the merge gate.** This artifact records what was verifiable in the
build environment and specifies exactly what a consumer / CI must run with AWS
credentials and a representative state to satisfy the gate.

## The 17 `moved {}` mappings (old inline → new module address)

Each old inline `aws_vpc_endpoint.<name>[0]` maps onto the module's
`for_each`-keyed interface endpoint or its `count`-indexed gateway endpoint.
Note the upstream-friendly key renames: `cloudwatch_logs` → `logs`,
`cloudwatch_monitoring` → `monitoring`, `step_functions` → `states`,
`eventbridge` → `events`.

| # | Old inline address | New module address |
|---|--------------------|--------------------|
| 1 | `aws_vpc_endpoint.ssm[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["ssm"]` |
| 2 | `aws_vpc_endpoint.cloudwatch_logs[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["logs"]` |
| 3 | `aws_vpc_endpoint.cloudwatch_monitoring[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["monitoring"]` |
| 4 | `aws_vpc_endpoint.kms[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["kms"]` |
| 5 | `aws_vpc_endpoint.bedrock[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock"]` |
| 6 | `aws_vpc_endpoint.bedrock_runtime[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock-runtime"]` |
| 7 | `aws_vpc_endpoint.bedrock_agent_runtime[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock-agent-runtime"]` |
| 8 | `aws_vpc_endpoint.sts[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["sts"]` |
| 9 | `aws_vpc_endpoint.codebuild[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["codebuild"]` |
| 10 | `aws_vpc_endpoint.eventbridge[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["events"]` |
| 11 | `aws_vpc_endpoint.lambda[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["lambda"]` |
| 12 | `aws_vpc_endpoint.sqs[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["sqs"]` |
| 13 | `aws_vpc_endpoint.step_functions[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["states"]` |
| 14 | `aws_vpc_endpoint.textract[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["textract"]` |
| 15 | `aws_vpc_endpoint.appsync_api[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.interface["appsync-api"]` |
| 16 | `aws_vpc_endpoint.s3[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.s3_gateway[0]` |
| 17 | `aws_vpc_endpoint.dynamodb[0]` | `module.vpc_endpoints[0].aws_vpc_endpoint.dynamodb_gateway[0]` |

15 interface endpoints + 2 gateway endpoints = **17 moves**.

## Expected plan result (the merge gate)

For a deployment whose state holds the **old inline** `aws_vpc_endpoint.*[0]`
addresses, after upgrading to the module-based example, `terraform plan` MUST
report, for each of the 17 endpoints:

- a single **move** line (old address → new module address), and
- **no** accompanying `+ create` and **no** `- destroy` for that address.

Move-only outcome — i.e. **0 to destroy / 0 to create** attributable to the
endpoint refactor. Terraform prints each move like:

```text
# aws_vpc_endpoint.bedrock[0] has moved to
# module.vpc_endpoints[0].aws_vpc_endpoint.interface["bedrock"]
```

The plan summary line (`Plan: N to add, 0 to change, 0 to destroy.`) must show
**0 destroy**, and none of the `N` adds may be one of the 17 endpoints above.
If any moved endpoint shows `+ create` / `- destroy`, the gate **fails** — stop
and reconcile the state address or the `moved {}` mapping before applying
(destroying a live PrivateLink interface endpoint is not an acceptable outcome,
because the rename is preservable).

## Verification performed in this environment

| Check | Result |
|-------|--------|
| `terraform validate` (example) | **Pass** (config valid; only `name`-deprecation and `hash_key`-deprecation provider warnings, unrelated to the moves) |
| `moved {}` block count in `main.tf` | **17** — matches the 17 inline endpoints |
| `from` addresses | All 17 use the old inline `aws_vpc_endpoint.<name>[0]` form |
| `to` addresses vs. module resource addresses | All 15 interface targets resolve to `module.vpc_endpoints[0].aws_vpc_endpoint.interface["<key>"]` and both gateways to `s3_gateway[0]` / `dynamodb_gateway[0]` — confirmed against `modules/vpc-endpoints/main.tf` (`for_each` interface resource, `count`-gated `s3_gateway` / `dynamodb_gateway`) |
| Interface keys enabled in the module call | All 15 moved interface keys are present and `= true` in the example's `enabled_interface_endpoints` map (no extra/missing service that would add or drop an endpoint) |
| Interface-key set equality (re-verified task 4.2) | The set of 15 keys targeted by `moved` `to` addresses is **identical** to the set of 15 `= true` keys in `enabled_interface_endpoints` (diff is empty both ways): `appsync-api, bedrock, bedrock-agent-runtime, bedrock-runtime, codebuild, events, kms, lambda, logs, monitoring, sqs, ssm, states, sts, textract` |
| Leftover inline `aws_vpc_endpoint` resource defs in example | **0** — the inline resources were fully removed; only `moved` blocks + the module call remain |
| Representative state present locally | **No** — example `terraform.tfstate` is empty (`"resources": []`), so the 0/0 plan cannot be produced offline |
| `terraform plan` (this environment) | **Not provable here** — see limitation below |

Terraform version used: `1.15.5`; aws provider `6.46.0`. (`terraform init
-backend=false` + `terraform validate` re-run for task 4.2 — config valid.)

## Credential / state limitation (why the live 0/0 plan is the consumer's gate)

A live `terraform plan` for this example could **not** be completed in the build
environment for two independent reasons:

1. **No AWS credentials.** The `aws` provider validates credentials via
   `STS:GetCallerIdentity` before evaluating any moves. A plan attempt with no
   credentials fails with:

   ```text
   Error: Retrieving AWS account details: validating provider credentials:
   retrieving caller identity from STS: operation error STS: GetCallerIdentity,
   https response error StatusCode: 403, ... api error InvalidClientTokenId:
   The security token included in the request is invalid.
   ```

   This is expected and matches the task's reality check. The example uses the
   real `aws` provider (not a mock/null provider), so a fully offline plan is
   not possible.

2. **No representative state.** The example's local `terraform.tfstate` is empty
   (`"resources": []`), so it does not contain the old inline
   `aws_vpc_endpoint.*[0]` addresses the move test requires. The 0/0 result is
   only meaningful against a state captured from a real prior deployment of this
   example (or an equivalent representative state), which is not present in this
   repo and cannot be fabricated.

Therefore, per Req 12.1, the live 0/0 plan is the **merge gate to be run by a
consumer / CI** that has both AWS credentials and a representative
`bedrock-llm-processor-vpc` state with the old inline endpoints. Static-file
inspection above establishes that the `moved {}` blocks are present, complete,
and correctly targeted — a necessary but **not sufficient** condition; the
verified plan is what gates the merge.

## Exact commands a consumer / CI runs to satisfy the gate

From `examples/bedrock-llm-processor-vpc/`, with AWS credentials configured and
the backend/state pointing at a representative deployment that still holds the
**old inline** endpoint addresses:

```bash
# 0. Back up state first (breaking-changes.md discipline)
terraform state pull > state-backup-pre-vpc-endpoints.json

# 1. Pick up the new modules/vpc-endpoints/ source + moved {} blocks
terraform init -upgrade

# 2. Plan and read the move / create / destroy counts
terraform plan -out=vpc-endpoints.plan
```

### What a passing result looks like

- 17 `... has moved to module.vpc_endpoints[0]....` lines (one per endpoint
  above).
- **`Plan: <n> to add, 0 to change, 0 to destroy.`** with `0 to destroy`, and
  none of the `<n>` adds being any of the 17 endpoints (any adds are unrelated,
  e.g. `random_string`, buckets — for the endpoint refactor specifically the
  count is 0 add / 0 destroy).
- Optionally confirm machine-readably:

  ```bash
  terraform show -json vpc-endpoints.plan \
    | jq '[.resource_changes[]
           | select(.type=="aws_vpc_endpoint")
           | {address, actions: .change.actions}]'
  ```

  Every `aws_vpc_endpoint` entry must have `actions == ["no-op"]` (a pure move),
  never `["create"]`, `["delete"]`, or `["delete","create"]`.

Only once that plan is confirmed clean should the consumer `terraform apply
vpc-endpoints.plan`. See Breaking Change 5 of the migration guide for the full
migration + rollback steps.

## Repeatable test harness (task 4.2)

The gate above is operationalized as a runnable script committed alongside the
example:

```
examples/bedrock-llm-processor-vpc/verify-moved-0-0.sh
```

It mirrors the three-layer structure of `scripts/test-mcp-moved.sh`:

- **[B] Address cross-check (always, offline)** — asserts exactly 17 `moved {}`
  blocks, every `from` is an old inline `aws_vpc_endpoint.<name>[0]`, every
  interface `to` resolves to `module.vpc_endpoints[0].aws_vpc_endpoint.interface["<key>"]`
  (gateways → `s3_gateway[0]`/`dynamodb_gateway[0]`), the moved interface-key set
  is **identical** to the `= true` keys in `enabled_interface_endpoints` (so no
  endpoint is dropped or left un-moved), and no inline `aws_vpc_endpoint` defs
  remain.
- **[A] Offline self-test (default, no creds)** — builds a synthetic fixture that
  mirrors the exact move shape (count-gated inline resources → a count-gated child
  module's `for_each`-keyed `interface["<svc>"]` + `count`-indexed gateways),
  seeds state with the OLD addresses, switches to the module topology, and asserts
  the plan reports MOVE notes with `Plan: 0 to add, 0 to change, 0 to destroy` and
  that `terraform show -json` reports every change as `["no-op"]`.
- **[C] Operator / CI mode (`--plan`, needs AWS creds + representative state)** —
  runs `terraform init -upgrade && terraform plan -out` against the configured
  state, then `terraform show -json | jq` to assert **every** `aws_vpc_endpoint`
  change action is exactly `["no-op"]` (0 create / 0 delete). Exits non-zero if any
  endpoint would be created or deleted — this is the authoritative merge gate.

```bash
# offline (cross-check + synthetic self-test) — no credentials required
./verify-moved-0-0.sh

# authoritative gate — needs AWS creds and a state holding the old inline endpoints
./verify-moved-0-0.sh --plan
```

**Verified offline in this environment:** layers [A] and [B] pass
(`exit 0`); layer [C] exits non-zero without credentials/representative state, as
expected — confirming the script enforces the gate rather than fabricating a pass.
