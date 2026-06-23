#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# =============================================================================
# verify-moved-0-0.sh — plan-test for the VPC-endpoints moved {} blocks
# =============================================================================
#
# Spec: idp-v0.5.12-round-2, task 4.2 — Property 11 (Address-changing refactors
#       preserve infrastructure, moved 0/0). Shares its gate with task 12.2.
# Requirements: 12.1, 12.2.
# Governing: .kiro/steering/breaking-changes.md ("Verify with a `plan` that shows
#   0 destroy / 0 create for the moved resources — only then is the rename safe").
# Companion artifact: ../../docs/plans/vpc-endpoints-moved-0-0.md
#   (the 17-block mapping table + the credential/state limitation are documented
#    there; this script operationalizes that gate as a repeatable test).
#
# WHAT THIS PROVES
# ----------------
# The Round 2 refactor swaps the example's ~17 inline `aws_vpc_endpoint.*[0]`
# resources for a single `module.vpc_endpoints[0]` call. That changes resource
# addresses, so each old address carries a `moved {}` block remapping it onto the
# module's `for_each`-keyed interface endpoint (or `count`-indexed gateway). The
# refactor is preservable (a live PrivateLink ENI must NOT be destroyed/recreated),
# so per breaking-changes.md it is gated on a plan showing 0 destroy / 0 create.
#
# A TRUE end-to-end "0 destroy / 0 create" confirmation requires a representative
# `bedrock-llm-processor-vpc` state that still carries the OLD inline
# `aws_vpc_endpoint.<svc>[0]` addresses, plus AWS credentials (the example uses the
# real `aws` provider, which validates creds via STS:GetCallerIdentity before
# evaluating any move). Neither is available offline in this repo — the example's
# local state is empty. See ../../docs/plans/vpc-endpoints-moved-0-0.md.
#
# So this script does the BEST FEASIBLE thing in three layers:
#
#   [A] OFFLINE SELF-TEST (default, no creds/network):
#       Builds a SYNTHETIC fixture in a temp dir mirroring the EXACT address SHAPE
#       of the real move — root-level count-gated `aws_vpc_endpoint.<svc>[0]`
#       stand-ins relocated INTO a count-gated child module as a `for_each`-keyed
#       `interface["<svc>"]` resource (interface endpoints) and a `count`-indexed
#       `s3_gateway[0]` / `dynamodb_gateway[0]` (gateway endpoints), with `moved {}`
#       blocks of identical form. Seeds state with the OLD addresses, switches to
#       the module topology, and asserts `terraform plan` reports MOVE notes with
#       0 add / 0 change / 0 destroy. This exercises the moved-block engine across
#       the count→module + count→for_each transformation the real blocks perform.
#
#   [B] ADDRESS CROSS-CHECK (always, offline):
#       Parses every `moved {}` block out of ./main.tf and asserts:
#         * exactly 17 blocks (15 interface + 2 gateway);
#         * every `from` is an old inline `aws_vpc_endpoint.<name>[0]`;
#         * every interface `to` resolves to
#           module.vpc_endpoints[0].aws_vpc_endpoint.interface["<key>"] and both
#           gateways to s3_gateway[0] / dynamodb_gateway[0];
#         * the set of interface keys targeted by `to` is IDENTICAL to the set of
#           `= true` keys in the example's `enabled_interface_endpoints` map (no
#           moved endpoint is dropped, no enabled endpoint is left un-moved — the
#           condition that keeps the plan free of stray create/destroy);
#         * no inline `aws_vpc_endpoint` resource definitions remain in the example.
#
#   [C] OPERATOR / CI MODE (`--plan` against real state, needs AWS creds):
#       Runs `terraform init -upgrade` + `terraform plan -out` against the example's
#       configured backend/state, then `terraform show -json | jq` to assert EVERY
#       `aws_vpc_endpoint` resource-change action is exactly ["no-op"] (a pure move)
#       — never ["create"], ["delete"], or ["delete","create"] — and that the plan
#       has 0 destroy / 0 create overall. This is the authoritative merge gate and
#       exits non-zero if any endpoint would be created or deleted.
#
# USAGE
# -----
#   ./verify-moved-0-0.sh            # [A] + [B] (offline, default; no creds needed)
#   ./verify-moved-0-0.sh --plan     # [B] + [C] (real plan against state; needs creds)
#   ./verify-moved-0-0.sh --help
#
# EXIT: 0 = all selected checks passed; non-zero = a check failed (gate not met).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="${SCRIPT_DIR}"
MAIN_TF="${EXAMPLE_DIR}/main.tf"

RUN_PLAN=0
RC=0

usage() { sed -n '2,78p' "${BASH_SOURCE[0]}"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) RUN_PLAN=1; shift ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; RC=1; }
hdr()  { printf '\n=== %s ===\n' "$1"; }

# The 17 expected interface keys (15) — the 2 gateways are handled separately.
EXPECTED_INTERFACE_KEYS="appsync-api bedrock bedrock-agent-runtime bedrock-runtime codebuild events kms lambda logs monitoring sqs ssm states sts textract"

# =============================================================================
# [B] ADDRESS CROSS-CHECK — moved.tf blocks vs the module call in main.tf
# =============================================================================
crosscheck_addresses() {
  hdr "[B] Address cross-check: moved {} blocks vs module.vpc_endpoints call"

  if [[ ! -f "${MAIN_TF}" ]]; then fail "main.tf not found at ${MAIN_TF}"; return; fi

  # 1. Exactly 17 moved blocks.
  local moved_count
  moved_count="$(grep -cE '^moved \{' "${MAIN_TF}")"
  if [[ "${moved_count}" -eq 17 ]]; then
    pass "found 17 moved {} blocks (15 interface + 2 gateway)"
  else
    fail "expected 17 moved {} blocks, found ${moved_count}"
  fi

  # 2. Every `from` is an old inline aws_vpc_endpoint.<name>[0].
  local bad_from
  bad_from="$(grep -E '^\s*from\s*=\s*' "${MAIN_TF}" \
    | grep -vcE 'from\s*=\s*aws_vpc_endpoint\.[a-z0-9_]+\[0\]\s*$' || true)"
  if [[ "${bad_from}" == "0" ]]; then
    pass "every 'from' is an old inline aws_vpc_endpoint.<name>[0] address"
  else
    fail "${bad_from} 'from' address(es) are not of the form aws_vpc_endpoint.<name>[0]"
  fi

  # 3. Gateway `to` addresses present and correctly targeted.
  if grep -qE 'to\s*=\s*module\.vpc_endpoints\[0\]\.aws_vpc_endpoint\.s3_gateway\[0\]' "${MAIN_TF}"; then
    pass "S3 gateway move targets module.vpc_endpoints[0].aws_vpc_endpoint.s3_gateway[0]"
  else
    fail "S3 gateway move target not found"
  fi
  if grep -qE 'to\s*=\s*module\.vpc_endpoints\[0\]\.aws_vpc_endpoint\.dynamodb_gateway\[0\]' "${MAIN_TF}"; then
    pass "DynamoDB gateway move targets module.vpc_endpoints[0].aws_vpc_endpoint.dynamodb_gateway[0]"
  else
    fail "DynamoDB gateway move target not found"
  fi

  # 4. Extract the interface keys targeted by the moved `to` addresses.
  local moved_keys
  moved_keys="$(grep -oE 'module\.vpc_endpoints\[0\]\.aws_vpc_endpoint\.interface\["[^"]+"\]' "${MAIN_TF}" \
    | sed -E 's/.*interface\["([^"]+)"\].*/\1/' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  local expected_sorted
  expected_sorted="$(echo "${EXPECTED_INTERFACE_KEYS}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  if [[ "${moved_keys}" == "${expected_sorted}" ]]; then
    pass "15 interface 'to' keys match the expected service set exactly"
  else
    fail "interface 'to' keys mismatch"
    echo "      moved:    ${moved_keys}"
    echo "      expected: ${expected_sorted}"
  fi

  # 5. Set equality: moved interface keys == enabled_interface_endpoints (= true).
  #    Isolate the enabled_interface_endpoints {...} block, then pull `<key> = true`.
  local enabled_keys
  enabled_keys="$(awk '/enabled_interface_endpoints = \{/{f=1; next} f && /^[[:space:]]*\}/{f=0} f' "${MAIN_TF}" \
    | grep -E '=[[:space:]]*true' \
    | sed -E 's/^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=.*/\1/' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  if [[ "${enabled_keys}" == "${moved_keys}" && -n "${enabled_keys}" ]]; then
    pass "moved interface keys == enabled_interface_endpoints (=true) set — no stray create/destroy"
  else
    fail "moved interface keys differ from enabled_interface_endpoints set"
    echo "      moved:   ${moved_keys}"
    echo "      enabled: ${enabled_keys}"
  fi

  # 6. No inline aws_vpc_endpoint resource definitions remain in the example.
  local leftover
  leftover="$(grep -cE '^resource "aws_vpc_endpoint"' "${MAIN_TF}" || true)"
  if [[ "${leftover}" == "0" ]]; then
    pass "no leftover inline aws_vpc_endpoint resource definitions in the example"
  else
    fail "${leftover} inline aws_vpc_endpoint resource definition(s) still present"
  fi
}

# =============================================================================
# [A] OFFLINE SELF-TEST — synthetic fixture mirroring the VPC-endpoints move shape
# =============================================================================
offline_selftest() {
  hdr "[A] Offline self-test: synthetic fixture mirroring the inline -> module move"

  command -v terraform >/dev/null 2>&1 || { fail "terraform not on PATH"; return; }

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  mkdir -p "${tmp}/modules/vpce"

  # --- child module: stand-in for modules/vpc-endpoints (NEW home) -------------
  # for_each-keyed interface resource + count-indexed gateway resources, mirroring
  # the real module's resource shapes exactly.
  cat > "${tmp}/modules/vpce/main.tf" <<'EOF'
variable "enabled_interface_endpoints" { type = map(bool) }
variable "enable_s3_gateway"           { type = bool }
variable "enable_dynamodb_gateway"     { type = bool }
locals {
  enabled = { for s, on in var.enabled_interface_endpoints : s => s if on }
}
resource "terraform_data" "interface" {
  for_each = local.enabled
  input    = "vpce:${each.value}"
}
resource "terraform_data" "s3_gateway" {
  count = var.enable_s3_gateway ? 1 : 0
  input = "vpce:s3"
}
resource "terraform_data" "dynamodb_gateway" {
  count = var.enable_dynamodb_gateway ? 1 : 0
  input = "vpce:dynamodb"
}
EOF

  # --- STEP 1: OLD topology — inline count-gated aws_vpc_endpoint stand-ins -----
  # Two interface services (ssm, logs) + S3/DynamoDB gateways is enough to
  # exercise both the count->for_each and the count->count[0] transformations.
  cat > "${tmp}/main.tf" <<'EOF'
terraform { required_version = ">= 1.1" }
resource "terraform_data" "ssm" {
  count = 1
  input = "vpce:ssm"
}
resource "terraform_data" "logs" {
  count = 1
  input = "vpce:logs"
}
resource "terraform_data" "s3" {
  count = 1
  input = "vpce:s3"
}
resource "terraform_data" "dynamodb" {
  count = 1
  input = "vpce:dynamodb"
}
EOF

  ( cd "${tmp}" && terraform init -input=false >/dev/null 2>&1 \
                && terraform apply -auto-approve -input=false >/dev/null 2>&1 )

  if ! ( cd "${tmp}" && terraform state list 2>/dev/null | grep -qFx 'terraform_data.ssm[0]' ); then
    fail "fixture seeding failed — OLD inline address terraform_data.ssm[0] not in state"
    return
  fi
  pass "seeded synthetic state with OLD inline addresses (ssm/logs/s3/dynamodb)[0]"

  # --- STEP 2: NEW topology — module call + moved {} blocks --------------------
  # Mirrors main.tf exactly in form: count-gated module, count->for_each interface
  # keys, count->count[0] gateways.
  cat > "${tmp}/main.tf" <<'EOF'
terraform { required_version = ">= 1.1" }
module "vpc_endpoints" {
  source = "./modules/vpce"
  count  = 1
  enabled_interface_endpoints = { ssm = true, logs = true }
  enable_s3_gateway       = true
  enable_dynamodb_gateway = true
}
moved {
  from = terraform_data.ssm[0]
  to   = module.vpc_endpoints[0].terraform_data.interface["ssm"]
}
moved {
  from = terraform_data.logs[0]
  to   = module.vpc_endpoints[0].terraform_data.interface["logs"]
}
moved {
  from = terraform_data.s3[0]
  to   = module.vpc_endpoints[0].terraform_data.s3_gateway[0]
}
moved {
  from = terraform_data.dynamodb[0]
  to   = module.vpc_endpoints[0].terraform_data.dynamodb_gateway[0]
}
EOF

  local plan_out
  plan_out="$( cd "${tmp}" && terraform init -input=false >/dev/null 2>&1; terraform plan -no-color 2>&1 )"
  echo "${plan_out}" | sed 's/^/    | /'

  # 1. MOVE notes present for the interface + gateway relocations.
  if echo "${plan_out}" | grep -q 'has moved to .*interface\["ssm"\]'; then
    pass "plan reports a MOVE note for the interface[\"ssm\"] relocation"
  else
    fail "plan did NOT report a move note for interface[\"ssm\"]"
  fi
  if echo "${plan_out}" | grep -q 'has moved to .*s3_gateway\[0\]'; then
    pass "plan reports a MOVE note for the s3_gateway[0] relocation"
  else
    fail "plan did NOT report a move note for s3_gateway[0]"
  fi

  # 2. 0 destroy / 0 create / 0 change.
  if echo "${plan_out}" | grep -Eq 'Plan: 0 to add, 0 to change, 0 to destroy\.|No changes\.'; then
    pass "plan shows 0 to add, 0 to change, 0 to destroy"
  else
    fail "plan does NOT show 0/0/0"
  fi

  # 3. No destroy/replace lines.
  if echo "${plan_out}" | grep -Eq 'will be destroyed|must be replaced'; then
    fail "plan contains a destroy/replace line for a moved resource"
  else
    pass "no 'will be destroyed' / 'must be replaced' lines present"
  fi

  # 4. jq no-op assertion on the machine-readable plan (mirrors operator mode [C]).
  if command -v jq >/dev/null 2>&1; then
    ( cd "${tmp}" && terraform plan -out=plan.bin -no-color >/dev/null 2>&1 )
    local non_noop
    non_noop="$( cd "${tmp}" && terraform show -json plan.bin \
      | jq '[.resource_changes[] | select(.change.actions != ["no-op"])] | length' )"
    if [[ "${non_noop}" == "0" ]]; then
      pass "terraform show -json: every resource change is [\"no-op\"] (pure move)"
    else
      fail "terraform show -json: ${non_noop} resource change(s) are not [\"no-op\"]"
    fi
  else
    echo "  NOTE: jq not on PATH — skipped the -json no-op assertion (operator mode [C] uses it)."
  fi
}

# =============================================================================
# [C] OPERATOR / CI MODE — real plan against the configured state, jq no-op gate
# =============================================================================
operator_plan() {
  hdr "[C] Operator mode: real terraform plan against the configured state"

  command -v terraform >/dev/null 2>&1 || { fail "terraform not on PATH"; return; }
  command -v jq >/dev/null 2>&1        || { fail "jq not on PATH (required for the no-op assertion)"; return; }

  echo "  This requires AWS credentials AND a state holding the OLD inline endpoints."
  echo "  Running: terraform init -upgrade && terraform plan -out=vpc-endpoints.plan"

  local ec
  set +e
  ( cd "${EXAMPLE_DIR}" \
      && terraform init -upgrade -input=false >/dev/null 2>&1 \
      && terraform plan -out=vpc-endpoints.plan -input=false -no-color >/dev/null 2>&1 )
  ec=$?
  set -e
  if [[ ${ec} -ne 0 ]]; then
    fail "terraform plan failed (likely missing AWS creds/network, or no representative state)."
    echo "      The example uses the real aws provider; an offline plan is not possible."
    echo "      See ../../docs/plans/vpc-endpoints-moved-0-0.md for the gate procedure."
    return
  fi

  local json
  json="$( cd "${EXAMPLE_DIR}" && terraform show -json vpc-endpoints.plan )"

  # Every aws_vpc_endpoint change must be exactly ["no-op"] (a pure move).
  local non_noop
  non_noop="$(echo "${json}" | jq '[.resource_changes[]
        | select(.type=="aws_vpc_endpoint")
        | select(.change.actions != ["no-op"])] | length')"
  echo "${json}" | jq -r '.resource_changes[]
        | select(.type=="aws_vpc_endpoint")
        | "    | \(.address): \(.change.actions)"'
  if [[ "${non_noop}" == "0" ]]; then
    pass "every aws_vpc_endpoint change action is [\"no-op\"] (pure move, 0 create / 0 destroy)"
  else
    fail "${non_noop} aws_vpc_endpoint change(s) are NOT [\"no-op\"] — the move would create/destroy infra"
  fi

  # Belt-and-suspenders: overall 0 destroy / 0 create for the endpoint type.
  local creates deletes
  creates="$(echo "${json}" | jq '[.resource_changes[]
        | select(.type=="aws_vpc_endpoint")
        | select(.change.actions | index("create"))] | length')"
  deletes="$(echo "${json}" | jq '[.resource_changes[]
        | select(.type=="aws_vpc_endpoint")
        | select(.change.actions | index("delete"))] | length')"
  if [[ "${creates}" == "0" && "${deletes}" == "0" ]]; then
    pass "0 aws_vpc_endpoint creates / 0 deletes in the plan"
  else
    fail "aws_vpc_endpoint plan shows ${creates} create(s) / ${deletes} delete(s) — gate NOT met"
  fi
}

# =============================================================================
# main
# =============================================================================
echo "VPC-endpoints moved {} plan-test  (spec idp-v0.5.12-round-2 task 4.2; Req 12.1/12.2; Property 11)"

crosscheck_addresses              # [B] always
if [[ ${RUN_PLAN} -eq 1 ]]; then
  operator_plan                   # [C] when --plan is supplied
else
  offline_selftest                # [A] otherwise
fi

hdr "RESULT"
if [[ ${RC} -eq 0 ]]; then
  echo "  All selected checks PASSED."
else
  echo "  One or more checks FAILED."
fi
exit ${RC}
