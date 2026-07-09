#!/usr/bin/env bash
# Asserts that every Terraform reference into the vendored `sources/` tree
# resolves to a path that actually exists on disk.
#
# This guards against the class of bug where an upstream re-snapshot moves or
# deletes paths (e.g. `sources/patterns/pattern-1/2/3` collapsing into
# `sources/patterns/unified/`) while `.tf` files keep pointing at the old
# locations. Such breakage only surfaces at `terraform plan`/`apply` time (and
# sometimes only when an optional, count-gated feature is enabled), so we catch
# it statically here instead.
#
# It scans all `**/*.tf` files (excluding `.terraform/`), extracts every quoted
# string literal that references `sources/` -- this covers `archive_file`
# `source_dir`, `templatefile(...)`, `file(...)`/`fileexists(...)`, and plain
# `locals` -- resolves `${path.module}` / `${path.root}` prefixes, and fails
# (non-zero exit) if any referenced path is missing.
#
# Usage:
#   scripts/check-sources-paths.sh            # scan the repo (default)
#   CHECK_SOURCES_ROOT=/some/dir scripts/check-sources-paths.sh   # scan elsewhere

set -euo pipefail

# Repo root = parent of this script's directory (the genai-idp-terraform root).
# Use `pwd -P` to resolve symlinks: the repo is often consumed through a
# symlinked submodule path, and BSD `find` won't traverse a symlinked start dir.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${CHECK_SOURCES_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd -P)}"

errors=0
checked=0

# Find all .tf files, excluding the .terraform/ provider/cache dirs.
while IFS= read -r tf; do
  tf_dir="$(dirname "${tf}")"

  # Extract every double-quoted string literal that contains "sources/" as a
  # path segment (preceded by `/` or string start). Requiring the `/` boundary
  # avoids matching prose substrings like "...chat re[sources/]logs...".
  # -o prints only the match; we then strip the surrounding quotes.
  while IFS= read -r literal; do
    [ -n "${literal}" ] || continue

    # Strip the surrounding double quotes.
    path="${literal#\"}"
    path="${path%\"}"

    # Real path references never contain whitespace; prose does. Skip the latter.
    case "${path}" in
      *[[:space:]]*) continue ;;
    esac

    # Resolve Terraform path references to real filesystem locations.
    #   ${path.module} -> directory of the current .tf file
    #   ${path.root}   -> repo root (where root-module terraform runs)
    resolved="${path}"
    resolved="${resolved//\$\{path.module\}/${tf_dir}}"
    resolved="${resolved//\$\{path.root\}/${ROOT}}"

    # If unresolved interpolations remain (e.g. a var in the path), we can't
    # statically verify it -- skip rather than emit a false positive.
    case "${resolved}" in
      *'${'*) continue ;;
    esac

    # A bare relative path (e.g. a variable default `../../sources/...`) is
    # resolved by Terraform relative to the file that declares it, so anchor it
    # to the .tf file's directory. Absolute paths are used as-is.
    case "${resolved}" in
      /*) ;;
      *) resolved="${tf_dir}/${resolved}" ;;
    esac

    checked=$((checked + 1))

    # `-e` matches both files (schema.graphql) and directories (source_dir).
    if [ ! -e "${resolved}" ]; then
      errors=$((errors + 1))
      echo "ERROR: ${tf}"
      echo "       references missing sources/ path: ${path}"
      echo "       resolved to: ${resolved}"
    fi
  done < <(grep -oE '"([^"]*/)?sources/[^"]*"' "${tf}" || true)
done < <(find "${ROOT}" -type d -name .terraform -prune -o -type f -name '*.tf' -print)

if [ "${errors}" -gt 0 ]; then
  echo ""
  echo "✗ ${errors} broken sources/ reference(s) found (checked ${checked})."
  echo "  An upstream re-snapshot likely moved or removed these paths."
  echo "  See .kiro/steering/upstream-sync.md for the reconciliation procedure."
  exit 1
fi

echo "✅ All ${checked} sources/ path reference(s) resolve."
