# Migrating from v0.6.4-tf.x to v0.6.9-tf.0

**Short version: there is nothing to migrate.** No input was renamed or removed, no
resource address changed, and no state operation is required. A plan against an
existing v0.6.4 deployment shows no destroys and no moves attributable to this
release.

What this release does change is **runtime behaviour**, in four ways that can
surprise a running deployment. Each is listed below with the condition under which
you need to act. If none of the conditions apply to you, upgrading is an ordinary
`apply`.

> This is a **partial parity** release. `sources/` is pinned at upstream v0.6.9 and
> the pipeline is reconciled against it, but several v0.6.9 surfaces are
> deliberately not adopted. See the `0.6.9-tf.0` section of
> [CHANGELOG.md](../CHANGELOG.md) for what is landed, deferred, and unassessed.

## Why there is no state migration

For the record, since the previous release needed a great deal of it:

- **No declaration was removed.** Comparing `v0.6.4-tf.0..HEAD` across every `.tf`
  file: 42 `resource` / `module` / `variable` / `output` / `data` blocks added, zero
  removed. So no `moved {}` or `removed {}` blocks are needed, and there is nothing
  to `terraform state rm`.
- **Every new input is optional.** Eighteen variables were added and all of the
  consumer-facing ones carry defaults, so an existing `terraform.tfvars` still
  plans unchanged. (One addition, `state_bucket_name`, has no default but lives in
  `ci/bootstrap`, which is internal CI scaffolding and not part of the module
  surface.)
- **The upstream log-group rename was deliberately not adopted.** Taking it would
  have been 76 destroy-and-creates orphaning existing log data, for no functional
  gain, since this wrapper names its own log groups at Lambda's default path. That
  decision is what keeps this release free of resource churn.

---

## 1. Executions now time out after 6 hours

### What changed

The document-processing state machine gains a top-level `TimeoutSeconds`, bound to
the new `processor.workflow_execution_timeout_seconds` (default `21600`, matching
upstream's `WorkflowExecutionTimeoutSeconds`).

Before, an execution had no timeout at all. A stalled document could hold a
concurrency slot for up to a year, so one bad document could starve the pipeline.

### When you need to act

**If any of your documents legitimately take longer than six hours to process.**
Those executions will now **fail** where previously they ran on. Raise the value:

```hcl
processor = {
  type = "bedrock-llm"
  # ... your existing configuration ...

  # Wall-clock ceiling for one document. Raise if large documents legitimately
  # exceed six hours; they now fail rather than hang.
  workflow_execution_timeout_seconds = 43200 # 12 hours
}
```

No state migration: changing a state machine definition is an in-place update.

### How to tell whether this affects you

Look for executions whose duration approached or exceeded six hours before the
upgrade:

```bash
aws stepfunctions list-executions \
  --state-machine-arn "arn:aws:states:<region>:<account>:stateMachine:<prefix>-processor-document-processing" \
  --status-filter SUCCEEDED --max-items 200 \
  --query 'executions[?stopDate!=`null`].[name,startDate,stopDate]' --output text
```

---

## 2. A pipeline hook configured `onError: fail` now halts the document

### What changed

Upstream v0.6.9 raises a named `HookFatalError` when a hook configured with
`onError: fail` fails. Our post-step hook states caught `States.ALL` and routed
forward, so **a hook asking to gate the pipeline was silently ignored** and the
document continued as though the hook had succeeded.

Each post-step hook now catches `HookFatalError` ahead of its `States.ALL` catcher,
so the document halts as configured.

### When you need to act

**If you have a hook set to `onError: fail` that has been failing unnoticed.** Its
documents will now stop instead of completing. That is the configured intent, but
if you have come to rely on the pipeline continuing, either fix the hook or change
it to `onError: continue`.

Hooks using the default `onError: continue` are unaffected.

---

## 3. A failed evaluation no longer fails the whole execution

### What changed

`EvaluationStep` had retries but no catch, so an exhausted retry discarded
extraction output that had already been written successfully. It now records the
failure and rejoins the normal tail, so `EvaluationStatus` reflects reality instead
of staying `RUNNING`.

### When you need to act

**Nothing to do.** This strictly recovers work that was previously thrown away. The
visible difference is that documents whose evaluation fails now complete with a
recorded evaluation failure, rather than failing the execution.

---

## 4. Tracking records now honour your configured retention

### What changed

`workflow_tracker` computes the TTL it stamps on tracking records from
`DATA_RETENTION_IN_DAYS`. That variable was never passed to it, so it fell back to
the source's own default of 365 days and **ignored `data_tracking_retention_days`
entirely**. It is now wired.

### When you need to act

**If you set `data_tracking_retention_days` to anything other than 365.** Records
written by the tracker will now expire on your schedule rather than after a year:

- **Shorter than 365** (for example 30): tracker records now expire far sooner.
  This is the configured intent, but if anything of yours reads tracking history
  older than that window, it will stop finding it.
- **Longer than 365**: tracker records now live longer than before.

Existing records keep the TTL they were written with; only records written after
the upgrade use the new value. If you need the old behaviour, set
`data_tracking_retention_days = 365` explicitly.

---

## Optional: things this release adds that are off by default

None of these change anything unless you opt in.

| Input | Default | What turning it on does |
|---|---|---|
| `feature_platform.publish_cloudformation_exports` | `false` | Publishes the CloudFormation exports installable features import. **Changes teardown**: an installed feature blocks `terraform destroy` until it is uninstalled. See [the FAQ](content/faqs/troubleshooting.md#terraform-destroy-fails-on-the-feature-platform-exports-stack). |
| `additional_callback_urls` / `additional_logout_urls` (unified-processor example) | `[]` | Allows the deployed Web UI url as an OAuth callback, which hosted-UI and federated sign-in need. Supply it after the first apply, once `web_ui_url` is known. |

## Rolling back

Since no state changed, rolling back is a matter of checking out the previous
version and applying. The two behaviour changes worth knowing on the way back:

- Removing `TimeoutSeconds` restores unbounded executions, including the stalled
  concurrency-slot problem it was added to fix.
- Reverting the hook catchers restores silently ignoring `onError: fail`.

Neither requires state surgery.
