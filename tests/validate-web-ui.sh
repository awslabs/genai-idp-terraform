#!/usr/bin/env bash
# validate-web-ui.sh — Task 6.6
# Validates web-ui module for v0.4.8 changes (VITE_* env vars, build timeout, image).
# Usage: bash tests/validate-web-ui.sh (from genai-idp-terraform/ root)

set -euo pipefail

PASS=0
FAIL=0
MODULE="modules/web-ui"

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "true" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== web-ui Module Validation ==="

# No REACT_APP_* env vars remain
echo ""
echo "--- REACT_APP_* removal ---"
check "no REACT_APP_ env vars in main.tf" \
  "$(! grep -q 'REACT_APP_' "$MODULE/main.tf" && echo true || echo false)"

check "no REACT_APP_ env vars in buildspec.yml" \
  "$(! grep -q 'REACT_APP_' "$MODULE/buildspec.yml" 2>/dev/null && echo true || echo false)"

# VITE_* env vars present
echo ""
echo "--- VITE_* env vars ---"
for var in VITE_APPSYNC_GRAPHQL_URL VITE_USER_POOL_ID VITE_USER_POOL_CLIENT_ID VITE_AWS_REGION VITE_CLOUDFRONT_DOMAIN; do
  check "$var present in main.tf" \
    "$(grep -q "$var" "$MODULE/main.tf" && echo true || echo false)"
done

# CodeBuild image
echo ""
echo "--- CodeBuild image ---"
check "CodeBuild image is amazonlinux2-x86_64-standard:5.0" \
  "$(grep -q 'amazonlinux2-x86_64-standard:5.0' "$MODULE/main.tf" && echo true || echo false)"

# Build timeout
check "build_timeout = 30" \
  "$(grep -q 'build_timeout.*=.*30' "$MODULE/main.tf" && echo true || echo false)"

# Version string
echo ""
echo "--- Version string ---"
check "version string is 0.4.8 in web_ui_settings" \
  "$(grep -q '"0.4.8"' "$MODULE/main.tf" && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
