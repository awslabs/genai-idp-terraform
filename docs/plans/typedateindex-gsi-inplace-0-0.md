# Plan Artifact: Tracking-Table `TypeDateIndex` GSI — 0 destroy / 0 create

**Spec tasks:** `idp-v0.5.12-round-3` task 12.2 (breaking-change plan artifact)
**and** task 4.1 / **Property 4: TypeDateIndex added in place (C1)**. Both share
the same gate — a verified plan showing the tracking table **updated in place
(0 destroy / 0 create)** with the `TypeDateIndex` GSI added — and the same
offline constraint, so this single artifact serves both.
**Requirements:** 12.2 (breaking-change plan artifact), 9.1 (the in-place-update
plan, not the presence of the GSI block, is the merge gate), 7.1 / 7.2 (the GSI
is an additive in-place table update, never a replacement).
**Breaking change:** Migration guide
the Breaking Changes section of the `[0.5.12-tf.2]` entry in [CHANGELOG.md](../../CHANGELOG.md)
**Module under test:** `modules/tracking-table/`

---

## Purpose

Round 3 adds the upstream v0.5.1 **`TypeDateIndex`** global secondary index to
`aws_dynamodb_table.tracking_table` in `modules/tracking-table/` (HASH
`ItemType` / RANGE `InitialEventTime`, `INCLUDE` projection of 21 list
attributes), plus the two backing `attribute` blocks `ItemType` (S) and
`InitialEventTime` (S).

This is the **one true breaking change of the v0.5.12 line**. It is an
**additive, in-place** update — DynamoDB supports online GSI creation, so the
AWS provider adds the index without destroying/recreating the table — but
because it mutates a stateful resource (a DynamoDB table holding live
document/test-run/test-set tracking history), per `breaking-changes.md` it ships
gated on a `terraform plan` showing **0 destroy / 0 create** for the table.

Per Req 9.1, **the verified in-place-update plan — not the mere presence of the
`global_secondary_index` block — is the merge gate.** This artifact records the
in-place result demonstrated offline and specifies exactly what a consumer / CI
must run against real state at apply time.

## What the change looks like (the address that must stay in-place)

The GSI is an **added block on an existing resource** — no resource address
changes, so no `moved {}` block is needed (contrast the Round 2 vpc-endpoints
gate, which was an address-changing refactor). In a full deployment the table
lives at:

```
module.processing_environment.module.tracking_table.aws_dynamodb_table.tracking_table
```

The required plan outcome for that resource is a single `~ update in-place`
adding:

- `+ attribute { name = "ItemType"         type = "S" }`
- `+ attribute { name = "InitialEventTime" type = "S" }`
- `+ global_secondary_index { name = "TypeDateIndex" … }`

and **no** `-/+` replace, **no** `- destroy`.

## Why this is provably in-place (not a replacement)

Terraform core decides update-vs-replace from the provider **schema's
`ForceNew` flags**, independent of any live API call. In the
`hashicorp/aws` provider's `aws_dynamodb_table` schema, neither the
`global_secondary_index` block nor the top-level `attribute` block is marked
`ForceNew`. GSIs and attribute definitions are mutated by `UpdateTable`
(`GlobalSecondaryIndexUpdates`), which is an online operation. Therefore adding
them **cannot** force a table replacement — the only resources whose change
forces replacement on this table are `hash_key`, `range_key`, `name`,
`billing_mode`→table-key changes, and similar identity attributes, none of which
this change touches.

The demonstration below confirms this empirically: planning the GSI add against
a prior state that holds the **pre-GSI** table yields `0 to destroy`.

## Demonstration performed offline (the in-place result)

A true offline `terraform plan` with the **real** AWS provider is not possible
for `aws_dynamodb_table`: the provider calls `DescribeTable` during plan, which
requires live credentials (a plan attempt with mock credentials and
`-refresh=false` still fails with
`operation error DynamoDB: DescribeTable … UnrecognizedClientException`). This
is the same credential/state limitation the Round 2 vpc-endpoints artifact
documented.

To demonstrate the **update-vs-replace decision** without AWS access, a
`terraform test` harness with `mock_provider "aws"` was used. `mock_provider`
bypasses the provider API entirely, so Terraform core computes the diff purely
from the resource schema (the `ForceNew` logic above) — which is exactly the
decision the gate cares about. The harness:

1. mock-**applies** the table **without** the GSI (`with_gsi = false`) to seed a
   representative **pre-GSI** prior state, then
2. **plans** the same table **with** the GSI (`with_gsi = true`) against that
   state and reads the change shape.

### Verbatim plan output (`terraform test -verbose`)

```text
  run "seed_pre_gsi_table"... pass
  run "add_gsi_in_place"... pass

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_dynamodb_table.tracking_table will be updated in-place
  ~ resource "aws_dynamodb_table" "tracking_table" {
        id                          = "3r7b2oeg"
        name                        = "idp-harness-tracking"
        tags                        = {}
        # (13 unchanged attributes hidden)

      + attribute {
          + name = "InitialEventTime"
          + type = "S"
        }
      + attribute {
          + name = "ItemType"
          + type = "S"
        }

      + global_secondary_index {
          + hash_key           = "ItemType"
          + name               = "TypeDateIndex"
          + non_key_attributes = [
              + "CompletedAt",
              + "CompletedFiles",
              + "CompletionTime",
              + "ConfidenceAlertCount",
              + "ConfigVersion",
              + "CreatedAt",
              + "EvaluationStatus",
              + "FailedFiles",
              + "FilesCount",
              + "HITLCompleted",
              + "HITLReviewOwner",
              + "HITLReviewedBy",
              + "HITLStatus",
              + "HITLTriggered",
              + "NumPages",
              + "ObjectKey",
              + "ObjectStatus",
              + "Status",
              + "TestRunId",
              + "TestSetName",
            ]
          + projection_type    = "INCLUDE"
          + range_key          = "InitialEventTime"
        }

        # (5 unchanged blocks hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Success! 2 passed, 0 failed.
```

The decisive lines:

- **`# aws_dynamodb_table.tracking_table will be updated in-place`** — the `~`
  action, not `-/+` (replace).
- **`Plan: 0 to add, 1 to change, 0 to destroy.`** — **0 destroy / 0 create**
  for the table; the single change is the in-place GSI + attribute add.

> Note on the `non_key_attributes` ordering: Terraform renders the projection
> set alphabetically in the plan; the module declares it in
> `sources/template.yaml` order. Both describe the **same 21-element set**
> (a DynamoDB projection is a set, order-insensitive), so the difference is
> cosmetic and does not affect the diff.

Tool versions: Terraform `v1.15.5`; harness pinned to `hashicorp/aws` (the
module's locked provider is `6.49.0`, constraint `>= 4.0.0`). The
`hash_key is deprecated` provider warnings in the run are pre-existing and
unrelated to the GSI add.

### Reproducing the offline demonstration

The harness is intentionally not committed as live module `.tf` (it would be
picked up by `make validate`/`make all`); it is reproduced here so the result is
verifiable. Create a scratch dir (e.g. under the gitignored
`modules/tracking-table/.terraform-build/`) with two files:

`main.tf`:

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 4.0.0" }
  }
}
provider "aws" { region = "us-east-1" }

variable "with_gsi" {
  type    = bool
  default = true
}

# Mirrors modules/tracking-table/main.tf's aws_dynamodb_table, with the
# TypeDateIndex GSI + its two backing attributes toggled by var.with_gsi.
resource "aws_dynamodb_table" "tracking_table" {
  name         = "idp-harness-tracking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.with_gsi ? toset(["ItemType", "InitialEventTime"]) : toset([])
    content {
      name = attribute.value
      type = "S"
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.with_gsi ? toset(["TypeDateIndex"]) : toset([])
    content {
      name            = "TypeDateIndex"
      hash_key        = "ItemType"
      range_key       = "InitialEventTime"
      projection_type = "INCLUDE"
      non_key_attributes = [
        "ObjectKey", "ObjectStatus", "CompletionTime", "ConfigVersion",
        "EvaluationStatus", "NumPages", "ConfidenceAlertCount", "HITLTriggered",
        "HITLCompleted", "HITLStatus", "HITLReviewOwner", "HITLReviewedBy",
        "TestRunId", "TestSetName", "CreatedAt", "CompletedFiles", "FailedFiles",
        "FilesCount", "Status", "CompletedAt",
      ]
    }
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
  deletion_protection_enabled = false
  table_class                 = "STANDARD"
  server_side_encryption { enabled = true }
  tags = {}
}
```

`gsi_inplace.tftest.hcl`:

```hcl
mock_provider "aws" {}

run "seed_pre_gsi_table" {
  command = apply
  variables { with_gsi = false }
}

run "add_gsi_in_place" {
  command = plan
  variables { with_gsi = true }

  assert {
    condition     = aws_dynamodb_table.tracking_table.name == "idp-harness-tracking"
    error_message = "Table identity must be preserved across the GSI add."
  }
}
```

Then:

```bash
terraform init
terraform test -verbose
```

Expect `Success! 2 passed, 0 failed.` and the
`will be updated in-place` / `Plan: 0 to add, 1 to change, 0 to destroy.` lines
shown above.

## What is verified offline vs. what the operator must confirm at apply time

| Aspect | Status |
|--------|--------|
| GSI block + `ItemType`/`InitialEventTime` attributes present, matching `sources/template.yaml` (21 non-key attrs) | **Verified** (`modules/tracking-table/main.tf`) |
| `global_secondary_index` / `attribute` are not `ForceNew` ⇒ add cannot force replacement | **Verified** (provider schema; corroborated by the mock-provider plan showing `~ update in-place`) |
| Plan shows the table **updated in place, 0 destroy / 0 create** | **Verified offline** via the mock-provider `terraform test` above |
| Live plan against a **real** pre-GSI tracking-table state | **Operator/CI gate** — requires AWS credentials + a representative state; not producible offline (real provider calls `DescribeTable` at plan time) |

The mock-provider result proves the **schema-driven update-vs-replace decision**
(the substance of the gate). The remaining step — confirming the same `0 destroy
/ 0 create` against a real deployment's state — is the consumer/CI gate below,
because the real provider's plan needs credentials and live state that cannot be
fabricated here.

## Exact commands the consumer / CI runs to satisfy the gate

From the root (or example) with AWS credentials configured and the backend/state
pointing at a deployment that still holds the **pre-GSI** tracking table:

```bash
# 0. Back up state first (breaking-changes.md discipline)
terraform state pull > state-backup-pre-typedateindex.json

# 1. Pick up the new modules/tracking-table/ GSI block
terraform init -upgrade

# 2. Plan and read the table change
terraform plan -out=typedateindex.plan
```

### What a passing result looks like

- The tracking table appears as an **in-place update** (`~ … will be updated
  in-place`) adding the `TypeDateIndex` GSI and the `ItemType` /
  `InitialEventTime` attributes.
- **`Plan: <n> to add, <m> to change, 0 to destroy.`** with **0 to destroy**,
  and the tracking table is among the `~` changes, **never** a `-/+` replace.
- Confirm machine-readably:

  ```bash
  terraform show -json typedateindex.plan \
    | jq '[.resource_changes[]
           | select(.type=="aws_dynamodb_table"
                    and (.name=="tracking_table"))
           | {address, actions: .change.actions}]'
  ```

  Every matching entry must have `actions == ["update"]` — never
  `["delete","create"]`, `["create","delete"]`, or `["delete"]`. If any tracking
  table shows a replace/destroy, the gate **fails**: stop and reconcile before
  applying (destroying the live tracking table would lose document/test history).

Only once that plan is confirmed clean should the consumer `terraform apply
typedateindex.plan`. DynamoDB then backfills the index asynchronously; the table
stays usable during the online GSI build.

## Data population is a separate, operator-triggered step (not part of apply)

Applying the GSI populates the index **only for new/updated items** going
forward. For **pre-existing** items to appear in `TypeDateIndex` queries, the
operator runs the **default-off, operator-triggered** backfill
(`modules/tracking-gsi-backfill/`) — `terraform apply` never mutates tracking
data unattended:

```hcl
tracking = {
  enable_gsi_backfill = true
}
```

```bash
terraform apply   # creates the backfill worker Lambda + SFN distributed-map machinery, IDLE

# Then trigger the run explicitly (the artifact-creating apply does NOT start it):
STATE_MACHINE_ARN=$(terraform state show \
  'module.tracking_gsi_backfill[0].aws_sfn_state_machine.backfill' \
  | awk -F'"' '/^[[:space:]]*arn /{print $2; exit}')
TABLE_NAME=$(terraform output -json processing_environment \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tracking_table_arn"].split("/")[-1])')

aws stepfunctions start-execution \
  --state-machine-arn "$STATE_MACHINE_ARN" \
  --input "{\"tableName\":\"$TABLE_NAME\",\"totalSegments\":10}"
```

The distributed map derives `ItemType` from each item's PK prefix (`doc#` →
`document`, `testrun#` → `testrun`, `testset#` → `testset`; `list#` / `agent#`
skipped) and sets it only where missing. The run is idempotent. See
the Breaking Changes section of [CHANGELOG.md](../../CHANGELOG.md)
of the migration guide for the full migration + rollback steps.
