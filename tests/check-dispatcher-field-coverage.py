#!/usr/bin/env python3
"""Fail if an upstream API field cannot be served by this deployment.

The v0.6 UI talks to one dispatcher Lambda at POST /op/{field}, which resolves the
field at runtime from an SSM map. A field the map does not cover returns
"unknown operation" the moment a user clicks the feature, and nothing earlier sees
it: the HCL is valid, the plan is clean, the apply succeeds. That is exactly how
`listDocuments` shipped broken, and how `getStepFunctionExecution` and
`updateChatSessionTitle` were later found by hand.

A field counts as covered when any of these holds:

  1. it is a key of `local.field_function_map` in dispatcher.tf, in any branch of
     the merge, so feature-gated entries count: coverage means the field CAN be
     served, not that every configuration serves it;
  2. the dispatcher serves it itself, from `ddb_direct._HANDLED`;
  3. `FIELD_ALIASES` folds it onto a field that is covered;
  4. it is listed in DOCUMENTED_GAPS below, with a reason.

Everything else fails the build. Add the wiring, or add an entry to DOCUMENTED_GAPS
explaining why the gap is acceptable. Do not delete the assertion.

Rebuilt from scratch during the v0.6.9 upgrade: the 0.6.4 task list recorded this
guard as added and wired into `make test`, but its PR was never pushed, so the file,
the target and the vendored spec copy were all absent. Reads the spec from the
pinned `sources/` tree rather than a copy, so it re-grades itself on every pin move.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SUBM") or os.path.abspath(os.path.join(HERE, ".."))
DISPATCHER = os.path.join(ROOT, "sources", "nested", "api-resolvers", "src", "lambda",
                          "http_api_dispatcher")
SPEC = os.path.join(DISPATCHER, "api_validation_spec.json")
DDB_DIRECT = os.path.join(DISPATCHER, "ddb_direct.py")
INDEX = os.path.join(DISPATCHER, "index.py")
TF = os.path.join(ROOT, "modules", "processing-environment-api", "dispatcher.tf")

# Fields this wrapper knowingly does not serve. Each needs a reason, and a reason
# that is a decision rather than a restatement of the absence.
DOCUMENTED_GAPS = {
    # Worker-internal writes. The pipeline Lambdas write these through the tracking
    # table directly, so there is no user-facing API path to serve and nothing to
    # wire. Listed rather than ignored so a later upstream change that makes one
    # user-facing shows up here as a decision to revisit.
    "createDocument": "Worker-internal: queue_processor creates the tracking row directly, not through the API.",
    "updateDocument": "Worker-internal: workers update the tracking row directly.",
    "updateDocumentStatus": "Worker-internal: the workflow tracker writes status directly.",
    "updateDocumentSection": "Worker-internal: process_results writes sections directly.",
    "updateConfigBootstrapJobStatus": "Worker-internal: the config bootstrap job writes its own status.",

    # Genuinely unserved and worth fixing, kept failing-visible via this list.
    "publishCircuitBreakerStatus": "Circuit breaker is not deployed by this wrapper, so there is no publisher to route to.",
    "updateAgentChatMessage": "Agent chat messages are read-only from the UI; no mutation is surfaced.",
    "listAvailableModels": "Model choice is config-authoritative here, so the UI's dynamic model list is not wired.",
    "updateFinetuningJobStatus": "Written by the fine-tuning state machine, not through the API.",
    "validateTestSetForFinetuning": "Fine-tuning test-set validation is not surfaced. Task 7.1c.",
}


def fields_from_spec():
    with open(SPEC, encoding="utf-8") as f:
        return set(json.load(f).get("fields", {}))


def ddb_direct_handled():
    src = open(DDB_DIRECT, encoding="utf-8").read()
    m = re.search(r'_HANDLED\s*=\s*\{(.*?)\}', src, re.S)
    return set(re.findall(r'["\']([A-Za-z][A-Za-z0-9_]*)["\']', m.group(1))) if m else set()


def field_aliases():
    src = open(INDEX, encoding="utf-8").read()
    m = re.search(r'FIELD_ALIASES:\s*Dict\[str,\s*str\]\s*=\s*\{(.*?)\n\}', src, re.S)
    if not m:
        return {}
    return dict(re.findall(r'["\']([A-Za-z0-9_]+)["\']\s*:\s*["\']([A-Za-z0-9_]+)["\']', m.group(1)))


def terraform_mapped_fields(spec):
    """Field names that actually reach the dispatcher's SSM map.

    Two sources, because the map is assembled from two places:

      1. `field_function_map = merge(...)` in dispatcher.tf, including every
         feature-gated branch. Coverage means the field CAN be served, not that
         every configuration serves it.
      2. `field_functions = { ... }` maps published by the feature modules, which
         reach the dispatcher through `enabled_feature_contracts` and
         `feature_platform_field_functions`.

    Scope matters in both directions, and getting it wrong is easy in each. Reading
    only dispatcher.tf reported the 12 feature-platform ops and
    sendChatDocumentMessage as unserved when they are wired. Scanning every .tf
    instead counted names that appear as keys in modules which never feed the
    dispatcher. Only maps literally named `field_functions` do.
    """
    out = set()

    def keys_from(body):
        # Drop comment lines, then scan the remainder as one blob: a feature module
        # may publish its whole map on a single line, e.g.
        # `field_functions = { sendChatDocumentMessage = aws_lambda_function.x.arn }`,
        # so a line-anchored match finds nothing. Intersecting with the upstream
        # spec keeps a loose `name =` pattern from picking up anything else.
        kept = "\n".join(l for l in body.split("\n")
                         if not l.strip().startswith(("#", "//")))
        for name in re.findall(r'([a-z][A-Za-z0-9_]*)\s*=\s*[^=]', kept):
            if name in spec:
                out.add(name)

    disp = os.path.join(ROOT, "modules", "processing-environment-api", "dispatcher.tf")
    if os.path.exists(disp):
        src = open(disp, encoding="utf-8").read()
        a = "field_function_map = merge("
        if a in src:
            i = src.index(a)
            keys_from(src[i:src.index("\n  )", i)])

    # Every module under modules/features/ exists to contribute fields, and each
    # builds its map differently: rbac and chat publish a literal `field_functions`,
    # while feature-platform keeps a typed op map that its output projects. Scanning
    # these modules wholesale covers all shapes; the spec intersection keeps it tight.
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, "modules", "features")):
        dirnames[:] = [d for d in dirnames if d not in (".terraform", "sources", ".git")]
        for fn in filenames:
            if not fn.endswith(".tf"):
                continue
            src = open(os.path.join(dirpath, fn), encoding="utf-8", errors="ignore").read()
            keys_from(src)
    return out


def main():
    for p in (SPEC, DDB_DIRECT, INDEX):
        if not os.path.exists(p):
            print(f"SKIP: {os.path.relpath(p, ROOT)} not present (sources/ submodule not initialised)")
            return 0

    spec = fields_from_spec()
    handled = ddb_direct_handled()
    aliases = field_aliases()
    mapped = terraform_mapped_fields(spec)

    def covered(field, _seen=None):
        _seen = _seen or set()
        if field in _seen:
            return False
        _seen.add(field)
        if field in mapped or field in handled:
            return True
        target = aliases.get(field)
        return covered(target, _seen) if target else False

    missing = sorted(f for f in spec if not covered(f) and f not in DOCUMENTED_GAPS)
    stale_gaps = sorted(g for g in DOCUMENTED_GAPS if g not in spec)
    now_covered = sorted(g for g in DOCUMENTED_GAPS if g in spec and covered(g))

    print(f"upstream API fields      : {len(spec)}")
    print(f"mapped in dispatcher.tf  : {len(mapped & spec)}")
    print(f"served by ddb_direct     : {len(handled & spec)}")
    print(f"resolved via an alias    : {len(aliases)} alias(es) declared")
    print(f"documented gaps          : {len(DOCUMENTED_GAPS)}")

    rc = 0
    if now_covered:
        print(f"\nFAIL: {len(now_covered)} documented gap(s) are now covered. Remove them from")
        print("DOCUMENTED_GAPS so the list keeps meaning something:")
        for g in now_covered:
            print(f"  {g}")
        rc = 1
    if stale_gaps:
        print(f"\nFAIL: {len(stale_gaps)} documented gap(s) name a field upstream no longer has.")
        print("The pin moved; drop them:")
        for g in stale_gaps:
            print(f"  {g}")
        rc = 1
    if missing:
        print(f"\nFAIL: {len(missing)} upstream field(s) this deployment cannot serve.")
        print("Each returns \"unknown operation\" when a user reaches the feature.")
        print("Wire it in dispatcher.tf, or add it to DOCUMENTED_GAPS with a reason.\n")
        for f in missing:
            print(f"  {f}")
        rc = 1

    if rc == 0:
        print("\nOK: every upstream field is mapped, served directly, aliased, or a documented gap")
    return rc


if __name__ == "__main__":
    sys.exit(main())
