#!/usr/bin/env bash
# Wrapper that runs a `make` target and converts a non-zero exit code into a
# warning instead of a hard failure. Used by the warn-only pre-commit hooks
# defined in .pre-commit-config.yaml so commits aren't blocked by validate /
# tflint / tfsec issues. The authoritative gate remains `make all` and CI.

set -u

target="${1:-}"
if [[ -z "${target}" ]]; then
  echo "precommit-warn.sh: missing make target argument" >&2
  exit 0
fi

# Run the target. Don't fail on errors.
if ! make -s "${target}"; then
  echo
  echo "warning: 'make ${target}' reported issues (non-blocking)."
  echo "         Run 'make ${target}' for details, or 'make all' for the full gate."
fi

exit 0
