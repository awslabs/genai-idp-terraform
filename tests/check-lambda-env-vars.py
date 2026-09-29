#!/usr/bin/env python3
"""Fail if a deployed Lambda reads an env var the Terraform never sets.

Why this exists. Moving the `sources/` pin brings new upstream code, and that code
can expect a new environment variable. Nothing else notices: the path resolves so
`check-sources` passes, the HCL is valid so `validate` passes, the resource is
correct so `apply` passes. The only symptom is at runtime, on one code path.

Two real cases from the v0.6.9 upgrade:

  * `get_stepfunction_execution_resolver` gained an IDOR check reading
    STATE_MACHINE_ARN that FAILS CLOSED. Unset, every call 403'd and the UI's
    "View Processing Flow" broke. Found by a human clicking the button.
  * `test_set_resolver` hard-reads TEST_RUNNER_FUNCTION_ARN, so the draft-labeling
    path raises KeyError.

Severity follows how the code reads the variable:

  HARD READ    os.environ["X"]           -> KeyError, the request dies.      FAIL
  FAILS CLOSED os.environ.get("X","") +  -> denies the request.              FAIL
               a guard that raises
  DEFAULTED    os.environ.get("X", ...)  -> degrades quietly, feature loss.  REPORT

Scope. Only Lambdas this Terraform actually packages, discovered from
`archive_file` / `templatefile` paths into sources/, so code we never deploy (for
example circuit_breaker_resolver) is not reported.

Scoping. The "is it set?" test is per function wherever the function can be linked
to its source directory, and falls back to "set anywhere in the Terraform" where it
cannot. The linkage is `aws_lambda_function.filename` ->
`data.archive_file.<name>.output_path` -> that block's literal `source_dir`, so it
needs only brace matching rather than a full HCL parser.

The fallback is deliberate. A function is treated leniently when its `source_dir` is
a variable or local rather than a literal, or when its `variables` is a reference or
a `merge(...)` instead of an inline map, because in those cases the names genuinely
cannot be read off the file and guessing would fail honest configurations. Lenient
means the old behaviour, so this check never reports something that was already
passing. Run with SHOW_SCOPE=1 to print which functions resolved.

Why per function matters. It used to compare against every env-var name assigned
anywhere, so a variable set on one function and read by another read as satisfied.
That missed a real defect: workflow_tracker reads DATA_RETENTION_IN_DAYS to compute
the TTL it stamps on tracking records and nothing set it on that function, while
queue_sender set the same name 100 lines earlier in the same file. The tracker
silently used the source's own 365 and ignored the shorter retention the operator
had configured. Per-file scoping would not have caught it either; only per-function
does.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SUBM") or os.path.abspath(os.path.join(HERE, ".."))

# Provided by the Lambda runtime, never by us.
RUNTIME_PROVIDED = {
    "AWS_REGION", "AWS_DEFAULT_REGION", "AWS_EXECUTION_ENV", "AWS_LAMBDA_FUNCTION_NAME",
    "AWS_LAMBDA_FUNCTION_VERSION", "AWS_LAMBDA_FUNCTION_MEMORY_SIZE", "AWS_LAMBDA_LOG_GROUP_NAME",
    "AWS_LAMBDA_LOG_STREAM_NAME", "AWS_LAMBDA_INITIALIZATION_TYPE", "AWS_LAMBDA_RUNTIME_API",
    "LAMBDA_TASK_ROOT", "LAMBDA_RUNTIME_DIR", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN", "AWS_XRAY_DAEMON_ADDRESS", "AWS_XRAY_CONTEXT_MISSING",
    "TZ", "PATH", "PYTHONPATH", "HOME", "AWS_PARTITION",
}

# Negative lookahead: `os.environ['X'] = ...` is the code SETTING a var for itself
# (the dataset deployers do this for HF_HOME), not requiring one from us.
HARD = re.compile(r'os\.environ\[\s*["\']([A-Z][A-Z0-9_]{2,})["\']\s*\](?!\s*=[^=])')
GET = re.compile(r'os\.environ\.get\(\s*["\']([A-Z][A-Z0-9_]{2,})["\']')
DENIES = re.compile(r'raise\b|_unauthorized|PermissionError')


def tf_assigned_env_names():
    """Every ENV_VAR_NAME = ... assignment across our Terraform."""
    r = subprocess.run(
        ["grep", "-rhoE", r'[A-Z][A-Z0-9_]{2,}[ \t]*=', "--include=*.tf",
         "modules/", "examples/", "."],
        cwd=ROOT, capture_output=True, text=True)
    return set(re.findall(r'([A-Z][A-Z0-9_]{2,})[ \t]*=', r.stdout))


BLOCK = re.compile(r'^(resource|data)[ \t]+"([A-Za-z0-9_]+)"[ \t]+"([A-Za-z0-9_-]+)"[^\n{]*\{', re.M)
ARCHIVE_REF = re.compile(r'filename\s*=\s*data\.archive_file\.([A-Za-z0-9_-]+)\.output_path')
SRC_LITERAL = re.compile(r'source_dir\s*=\s*"([^"]*)"')
ENV_OPEN = re.compile(r'\benvironment\s*(?:=\s*)?\{')
VARS_OPEN = re.compile(r'\bvariables\s*=\s*\{')
VARS_ANY = re.compile(r'\bvariables\s*=')
NAME_ASSIGN = re.compile(r'^[ \t]*([A-Z][A-Z0-9_]{2,})[ \t]*=', re.M)


def _match_brace(text, i):
    """Index just past the brace matching the one at i, skipping strings/comments."""
    depth = 0
    while i < len(text):
        c = text[i]
        if c == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                i += 2 if text[i] == '\\' else 1
        elif c == '#' or text.startswith('//', i):
            while i < len(text) and text[i] != '\n':
                i += 1
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return len(text)


def _blocks(text):
    for m in BLOCK.finditer(text):
        start = m.end() - 1
        yield m.group(1), m.group(2), m.group(3), text[start:_match_brace(text, start)]


def _sources_path(raw):
    """Normalise an HCL source_dir to the repo-relative sources/... form."""
    i = raw.find("sources/")
    return raw[i:].rstrip("/") if i >= 0 else None


def _inline_env_names(body):
    """Env names from an inline variables map, or None if not statically readable."""
    e = ENV_OPEN.search(body)
    if not e:
        return set()
    env = body[e.end() - 1:_match_brace(body, e.end() - 1)]
    v = VARS_OPEN.search(env)
    if not v:
        # `variables = local.x` or `merge(...)`: names are not in this file.
        return None if VARS_ANY.search(env) else set()
    inner = env[v.end() - 1:_match_brace(env, v.end() - 1)]
    if "merge(" in inner:
        return None
    return {n for n in NAME_ASSIGN.findall(inner) if n not in RUNTIME_PROVIDED}


def per_function_env():
    """Map sources/... dir -> env names set on the Lambda packaged from it.

    A dir maps to None when its names cannot be read statically, which the caller
    treats as "fall back to the global set" rather than as an empty set.
    """
    archives, lambdas = {}, []
    for root, _, files in os.walk(ROOT):
        if os.sep + "sources" in root or os.sep + ".terraform" in root:
            continue
        for f in files:
            if not f.endswith(".tf"):
                continue
            try:
                text = open(os.path.join(root, f), encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for kind, typ, name, body in _blocks(text):
                if kind == "data" and typ == "archive_file":
                    m = SRC_LITERAL.search(body)
                    if m:
                        p = _sources_path(m.group(1))
                        if p:
                            archives[name] = p
                elif kind == "resource" and typ == "aws_lambda_function":
                    ref = ARCHIVE_REF.search(body)
                    if ref:
                        lambdas.append((ref.group(1), _inline_env_names(body)))

    out = {}
    for archive_name, names in lambdas:
        path = archives.get(archive_name)
        if not path:
            continue
        if names is None or out.get(path, set()) is None:
            out[path] = None          # unreadable wins, stays lenient
        else:
            out[path] = out.get(path, set()) | names
    return out


def deployed_lambda_dirs():
    """Lambda source dirs under sources/ that our Terraform packages."""
    r = subprocess.run(
        ["grep", "-rhoE", r'sources/[A-Za-z0-9_./-]*lambda/[A-Za-z0-9_-]+',
         "--include=*.tf", "modules/", "."],
        cwd=ROOT, capture_output=True, text=True)
    out = set()
    for p in set(r.stdout.split()):
        full = os.path.join(ROOT, p)
        if os.path.isdir(full):
            out.add(p)
    return sorted(out)


def classify(path):
    blob = ""
    for root, _, files in os.walk(os.path.join(ROOT, path)):
        for f in files:
            if f.endswith(".py") and not f.startswith("test_"):
                blob += open(os.path.join(root, f), encoding="utf-8", errors="ignore").read() + "\n"
    hard = {v for v in HARD.findall(blob) if v not in RUNTIME_PROVIDED}
    got = {v for v in GET.findall(blob) if v not in RUNTIME_PROVIDED}
    closed = set()
    for v in got:
        for m in re.finditer(r'if not _?' + v + r'\b(.{0,400})', blob, re.S):
            if DENIES.search(m.group(1)):
                closed.add(v)
                break
    return hard, closed, got - closed


def main():
    if not os.path.isdir(os.path.join(ROOT, "sources", "src")):
        print("SKIP: sources/ not initialised (git submodule update --init)")
        return 0

    assigned = tf_assigned_env_names()
    per_fn = per_function_env()
    dirs = deployed_lambda_dirs()
    fail, report = [], []
    scoped = 0

    for d in dirs:
        hard, closed, defaulted = classify(d)
        name = os.path.basename(d)
        own = per_fn.get(d)
        if own is None:
            where, have = "anywhere", assigned
        else:
            where, have = "on this function", own
            scoped += 1
        for v in sorted(hard - have):
            fail.append((name, v, f"HARD READ, raises KeyError (not set {where})"))
        for v in sorted(closed - have):
            fail.append((name, v, f"FAILS CLOSED, denies the request (not set {where})"))
        for v in sorted(defaulted - have):
            report.append((name, v))

    print(f"checked {len(dirs)} deployed Lambda source dir(s); "
          f"{scoped} checked per function, {len(dirs) - scoped} against the global set")

    if os.environ.get("SHOW_SCOPE"):
        for d in dirs:
            own = per_fn.get(d)
            n = "lenient (unresolved)" if own is None else f"{len(own)} var(s)"
            print(f"  scope {os.path.basename(d)}: {n}")

    if report:
        print(f"\nnote: {len(report)} defaulted var(s) unset -> quiet feature loss, not an outage:")
        for n, v in report:
            print(f"  {n}: {v}")

    if fail:
        print(f"\nFAIL: {len(fail)} env var(s) a deployed Lambda requires but nothing sets.")
        print("Set them in the function's environment block, or explain why not.\n")
        for n, v, why in fail:
            print(f"  {n}")
            print(f"      {v} -- {why}")
        return 1

    print("OK: every env var a deployed Lambda requires is set somewhere in the Terraform")
    return 0


if __name__ == "__main__":
    sys.exit(main())
