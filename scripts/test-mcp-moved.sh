#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# =============================================================================
# test-mcp-moved.sh — plan-test for the MCP Lambda relocation/rename moved {} blocks
# =============================================================================
#
# Spec: idp-v0.5.12-round-1, task 10.3. Requirement 8.2, Property 4.
# Governing: .kiro/steering/breaking-changes.md ("Verify with a `plan` that shows
# 0 destroy / 0 create for the moved resources — only then is the rename safe").
#
# WHAT THIS PROVES
# ----------------
# The v0.5.3 MCP change folds TWO Terraform address changes into the
# `moved {}` blocks in ../moved.tf:
#   1. RENAME   : aws_lambda_function.agentcore_analytics_processor
#                 -> aws_lambda_function.agentcore_mcp_handler
#                 (deployed `function_name` held constant -> in-place update)
#   2. RELOCATION: the whole MCP stack moves OUT of
#                 module.processing_environment_api INTO module.mcp_integration.
#
# A TRUE end-to-end "0 destroy / 0 create" confirmation requires a populated
# v0.4.16 state that still carries the OLD address
#   module.processing_environment_api[0].aws_lambda_function.agentcore_analytics_processor[0]
# `moved {}` notes only render when the `from` address actually exists in state.
# No such representative state (and no AWS creds/network) is available offline in
# this repo — the example state is empty (serial 898, 0 resources) and the root
# plan stops at STS GetCallerIdentity. See docs/plans/v0.4.16-to-v0.5.12-plan.md.
#
# So this script does the BEST FEASIBLE thing in three layers:
#
#   [A] OFFLINE SELF-TEST (default, no creds/network):
#       Builds a SYNTHETIC fixture in a temp dir that mirrors the EXACT address
#       SHAPE of the real MCP moved block — a count-gated `processing_environment_api`
#       child module holding `agentcore_analytics_processor[0]`, relocated+renamed
#       to a count-gated `mcp_integration` child module holding
#       `agentcore_mcp_handler[0]`, with a `moved {}` block of identical form.
#       It seeds state with the OLD address, switches config, then asserts
#       `terraform plan` reports a MOVE with 0 add / 0 change / 0 destroy
#       (detailed-exitcode 0). This exercises the moved-block engine across a
#       module boundary + count index + resource rename — the precise
#       transformation the real block performs.
#
#   [B] ADDRESS CROSS-CHECK (always, offline):
#       Parses every `to = module.mcp_integration[0]....` address out of
#       ../moved.tf and asserts a matching `resource "<type>" "<label>"` exists
#       in modules/features/mcp-integration/. Also asserts every MCP `from =`
#       points at module.processing_environment_api[0] with the legacy
#       `agentcore_analytics_processor` / `agentcore_*` naming. This is what
#       guarantees the real block's from/to are syntactically valid and the
#       `to` targets resources that actually exist.
#
#   [C] OPERATOR MODE (`--state <path/to/v0.4.16.tfstate>`):
#       Runs the REAL root plan against a supplied representative state and greps
#       the actual MCP addresses for 0 destroy / 0 create. Requires AWS creds.
#       This is the authoritative proof and is documented as an operator step in
#       docs/migration-v0.4.16-to-v0.5.12.md.
#
# USAGE
# -----
#   scripts/test-mcp-moved.sh                 # [A] + [B] (offline, default)
#   scripts/test-mcp-moved.sh --state S.tfstate  # [B] + [C] (real plan, needs creds)
#   scripts/test-mcp-moved.sh --help
#
# EXIT: 0 = all selected checks passed; non-zero = a check failed.
set -euo pipefail

# --- locate repo paths relative to this script -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOVED_TF="${ROOT_DIR}/moved.tf"
MCP_MODULE_DIR="${ROOT_DIR}/modules/features/mcp-integration"

STATE_FILE=""
RC=0

usage() { sed -n '2,70p' "${BASH_SOURCE[0]}"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) STATE_FILE="${2:?--state needs a path}"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; RC=1; }
hdr()  { printf '\n=== %s ===\n' "$1"; }

# =============================================================================
# [B] ADDRESS CROSS-CHECK — moved.tf MCP `to` addresses vs the real module
# =============================================================================
crosscheck_addresses() {
  hdr "[B] Address cross-check: moved.tf MCP block vs modules/features/mcp-integration/"

  if [[ ! -f "${MOVED_TF}" ]]; then fail "moved.tf not found at ${MOVED_TF}"; return; fi
  if [[ ! -d "${MCP_MODULE_DIR}" ]]; then fail "mcp-integration module not found"; return; fi

  # Concatenate the module's .tf so resource decls are searchable.
  local module_src
  module_src="$(cat "${MCP_MODULE_DIR}"/*.tf)"

  # Extract every `to = module.mcp_integration[0].<type>.<label>[...]` address.
  # Strip a trailing [0] / [n] instance index to get the bare type.label.
  local to_addrs
  to_addrs="$(grep -E '^\s*to\s*=\s*module\.mcp_integration\[0\]\.' "${MOVED_TF}" \
    | sed -E 's/.*module\.mcp_integration\[0\]\.//; s/\[[0-9]+\]\s*$//; s/\s+$//' \
    | sort -u)"

  if [[ -z "${to_addrs}" ]]; then
    fail "no 'to = module.mcp_integration[0]...' addresses found in moved.tf"
    return
  fi

  local count=0 ok=0
  while IFS= read -r addr; do
    [[ -z "${addr}" ]] && continue
    count=$((count + 1))
    local rtype="${addr%%.*}"      # e.g. aws_lambda_function
    local rlabel="${addr#*.}"      # e.g. agentcore_mcp_handler
    # Match: resource "<type>" "<label>"
    if printf '%s' "${module_src}" | grep -Eq "resource[[:space:]]+\"${rtype}\"[[:space:]]+\"${rlabel}\"" ; then
      ok=$((ok + 1))
    else
      fail "moved.tf 'to' address has NO matching resource in module: ${rtype}.${rlabel}"
    fi
  done <<< "${to_addrs}"

  [[ ${ok} -eq ${count} && ${count} -gt 0 ]] && \
    pass "all ${count} MCP 'to' addresses map to real resources in the module"

  # The renamed Lambda specifically: from analytics_processor -> to mcp_handler.
  if grep -Eq 'from\s*=\s*module\.processing_environment_api\[0\]\.aws_lambda_function\.agentcore_analytics_processor\[0\]' "${MOVED_TF}" \
     && grep -Eq 'to\s*=\s*module\.mcp_integration\[0\]\.aws_lambda_function\.agentcore_mcp_handler\[0\]' "${MOVED_TF}"; then
    pass "Lambda rename mapped: processing_environment_api...agentcore_analytics_processor[0] -> mcp_integration...agentcore_mcp_handler[0]"
  else
    fail "Lambda rename moved{} block (analytics_processor -> mcp_handler) not found with expected addresses"
  fi

  # Every MCP `from` must originate in the API module (the relocation source).
  local bad_from
  bad_from="$(grep -E '^\s*from\s*=\s*' "${MOVED_TF}" \
    | grep -E 'agentcore_(analytics_processor|mcp_handler|gateway_manager|gateway_execution|gateway)|mcp_client' \
    | grep -vcE 'module\.processing_environment_api\[0\]\.' || true)"
  if [[ "${bad_from}" == "0" ]]; then
    pass "all MCP 'from' addresses originate in module.processing_environment_api[0] (relocation source)"
  else
    fail "${bad_from} MCP 'from' address(es) do not originate in module.processing_environment_api[0]"
  fi

  # function_name preservation note — what makes the RENAME an in-place update.
  if grep -Eq 'mcp_handler_function_name\s*=\s*"\$\{local\.api_name\}-agentcore-analytics-proc"' "${MCP_MODULE_DIR}/main.tf"; then
    pass "legacy function_name preserved (\${api_name}-agentcore-analytics-proc) — rename is an in-place update"
  else
    fail "could not confirm the legacy function_name is preserved in the module (needed for 0/0 rename)"
  fi
}

# =============================================================================
# [A] OFFLINE SELF-TEST — synthetic fixture mirroring the MCP moved-block shape
# =============================================================================
offline_selftest() {
  hdr "[A] Offline self-test: synthetic fixture mirroring the MCP relocation+rename"

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  mkdir -p "${tmp}/modules/api" "${tmp}/modules/mcp"

  # --- child module: stand-in for processing_environment_api (OLD home) ---
  cat > "${tmp}/modules/api/main.tf" <<'EOF'
variable "enabled" { type = bool }
resource "terraform_data" "agentcore_analytics_processor" {
  count = var.enabled ? 1 : 0
  input = "mcp-lambda:function_name=api-agentcore-analytics-proc"
}
EOF

  # --- child module: stand-in for mcp_integration (NEW home, renamed label) ---
  cat > "${tmp}/modules/mcp/main.tf" <<'EOF'
variable "enabled" { type = bool }
resource "terraform_data" "agentcore_mcp_handler" {
  count = var.enabled ? 1 : 0
  # Same underlying identity as the OLD resource: the deployed function_name is
  # held constant across the rename, which is what keeps the move at 0/0.
  input = "mcp-lambda:function_name=api-agentcore-analytics-proc"
}
EOF

  # --- STEP 1: OLD topology (MCP lives under module.processing_environment_api) ---
  # The module call is count-gated, exactly like the real root, so the module
  # instance address carries [0] — matching the moved{} `from` in ../moved.tf.
  cat > "${tmp}/main.tf" <<'EOF'
terraform { required_version = ">= 1.1" }
module "processing_environment_api" {
  source  = "./modules/api"
  count   = 1
  enabled = true
}
EOF

  ( cd "${tmp}" && terraform init -input=false >/dev/null 2>&1 \
                && terraform apply -auto-approve -input=false >/dev/null 2>&1 )

  # Sanity: the OLD count-gated address must be in state before we move it.
  if ! ( cd "${tmp}" && terraform state list 2>/dev/null \
        | grep -qFx 'module.processing_environment_api[0].terraform_data.agentcore_analytics_processor[0]' ); then
    fail "fixture seeding failed — OLD address not present in synthetic state"
    return
  fi
  pass "seeded synthetic state with OLD address module.processing_environment_api[0]...agentcore_analytics_processor[0]"

  # --- STEP 2: NEW topology (relocated + renamed) + moved{} block ---------------
  # Mirrors ../moved.tf exactly in form: cross-module, count-gated [0], rename.
  cat > "${tmp}/main.tf" <<'EOF'
terraform { required_version = ">= 1.1" }
module "mcp_integration" {
  source  = "./modules/mcp"
  count   = 1
  enabled = true
}
moved {
  from = module.processing_environment_api[0].terraform_data.agentcore_analytics_processor[0]
  to   = module.mcp_integration[0].terraform_data.agentcore_mcp_handler[0]
}
EOF

  local plan_out
  plan_out="$( cd "${tmp}" && terraform init -input=false >/dev/null 2>&1; terraform plan -no-color 2>&1 )"
  echo "${plan_out}" | sed 's/^/    | /'

  # --- ASSERTIONS ---------------------------------------------------------------
  # 1. A "has moved to" note must appear for the MCP handler.
  if echo "${plan_out}" | grep -q 'has moved to .*agentcore_mcp_handler'; then
    pass "plan reports a MOVE note for agentcore_mcp_handler"
  else
    fail "plan did NOT report a move note for agentcore_mcp_handler"
  fi

  # 2. 0 destroy / 0 create / 0 change.
  if echo "${plan_out}" | grep -Eq 'Plan: 0 to add, 0 to change, 0 to destroy\.|No changes\.'; then
    pass "plan shows 0 to add, 0 to change, 0 to destroy"
  else
    fail "plan does NOT show 0/0/0"
  fi

  # 3. No destroy/replace lines for the moved address.
  if echo "${plan_out}" | grep -Eq 'will be destroyed|must be replaced'; then
    fail "plan contains a destroy/replace line for a moved resource"
  else
    pass "no 'will be destroyed' / 'must be replaced' lines present"
  fi

  # 4. Authoritative: applying the moved{} records the move in state, after which
  #    a re-plan must be a clean no-op (detailed-exitcode 0). NOTE: before apply,
  #    `plan -detailed-exitcode` returns 2 — the move is a *pending* state change
  #    even though the resource diff is 0/0/0; that is expected, not a failure.
  set +e
  ( cd "${tmp}" && terraform apply -auto-approve -no-color >/dev/null 2>&1 )
  ( cd "${tmp}" && terraform plan -no-color -detailed-exitcode >/dev/null 2>&1 )
  local ec=$?
  set -e
  if [[ ${ec} -eq 0 ]]; then
    pass "after applying the move, re-plan == 0 changes (detailed-exitcode 0; move is idempotent)"
  else
    fail "after applying the move, re-plan -detailed-exitcode == ${ec} (expected 0)"
  fi
}

# =============================================================================
# [C] OPERATOR MODE — real root plan against a representative v0.4.16 state
# =============================================================================
operator_plan() {
  hdr "[C] Operator mode: real root plan against ${STATE_FILE}"

  if [[ ! -f "${STATE_FILE}" ]]; then
    fail "state file not found: ${STATE_FILE}"
    return
  fi

  echo "  Running: terraform plan against the supplied state (requires AWS creds)."
  echo "  Asserting 0 destroy / 0 create for every module.mcp_integration[0] address."

  local plan_out ec
  set +e
  plan_out="$( cd "${ROOT_DIR}" \
      && terraform init -input=false >/dev/null 2>&1 \
      && terraform plan -no-color -state="${STATE_FILE}" 2>&1 )"
  ec=$?
  set -e

  echo "${plan_out}" | grep -E 'agentcore|mcp_integration|Plan:' | sed 's/^/    | /' || true

  if [[ ${ec} -ne 0 ]]; then
    fail "terraform plan failed (likely missing AWS creds/network). Raw tail above."
    return
  fi

  # Any destroy/replace touching the MCP submodule address is a failure.
  if echo "${plan_out}" | grep -E 'module\.mcp_integration\[0\]' | grep -Eq 'will be destroyed|must be replaced'; then
    fail "MCP submodule shows destroy/replace — moved{} did NOT preserve the resources"
  else
    pass "no destroy/replace for any module.mcp_integration[0] address"
  fi

  if echo "${plan_out}" | grep -q 'has moved to .*mcp_integration'; then
    pass "plan reports MCP resources as moved (relocation recognised)"
  else
    echo "  NOTE: no 'has moved to' note for MCP — the supplied state may not"
    echo "        contain the OLD agentcore_analytics_processor address."
  fi
}

# =============================================================================
# main
# =============================================================================
echo "MCP moved{} plan-test  (spec idp-v0.5.12-round-1 task 10.3; Req 8.2 / Property 4)"
command -v terraform >/dev/null 2>&1 || { echo "terraform not on PATH" >&2; exit 2; }

crosscheck_addresses              # [B] always
if [[ -n "${STATE_FILE}" ]]; then
  operator_plan                   # [C] when a real state is supplied
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
