# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IDP v0.4.16 configuration seeder for the Terraform implementation.
#
# Replaces the legacy v0.4.8-style seeder that wrote
#     {"Configuration": "Default", **payload}
# in favor of the upstream v0.4.16 versioned format
#     {"Configuration": "Config#default", "IsActive": true, ...timestamps, **merged_payload}
# while also merging the user payload with system defaults
# (`idp_common.config.merge_utils.merge_config_with_defaults`) so that
# every Lambda has a complete `IDPConfig` available at runtime.
#
# The Lambda is invoked once per `Key` from the Terraform module
# (`Default` and `Schema`). Two minimum-effort changes vs. the upstream
# `update_configuration` Lambda:
#   1. Speaks plain Lambda invocation JSON, not CloudFormation Custom
#      Resource protocol (no cfnresponse).
#   2. For the active `default` version it does a read-modify-write that
#      preserves operator edits (tracked via a `TerraformSeed#<version>`
#      provenance sibling row); managed baselines and non-active additional
#      versions keep the historical unconditional write.

import gzip
import hashlib
import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import boto3
import yaml  # noqa: F401 — kept for parity with upstream; not used in current invocation shape
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


# Provenance marker prefix. The marker is a SEPARATE sibling item, never a
# top-level attribute on the Config# row: the runtime treats any non-metadata
# top-level attribute as config data, and list_config_versions only scans
# `begins_with(Configuration, "Config#")`, so a TerraformSeed# row is invisible.
_MARKER_PREFIX = "TerraformSeed"

# Row metadata / storage plumbing, NOT config data. Mirrors idp_common's
# _DYNAMODB_METADATA_FIELDS plus its compressed-storage markers; copied locally
# because idp_common lives in the (offline-absent) layer and sources/ is
# read-only.
_METADATA_FIELDS = frozenset(
    {
        "Configuration",
        "CreatedAt",
        "UpdatedAt",
        "IsActive",
        "Description",
        "BdaProjectArn",
        "BdaSyncStatus",
        "BdaLastSyncedAt",
        "Managed",
        "_config_storage",
        "_compressed_config",
        "_config_format",
    }
)
_COMPRESSED_STORAGE_MARKER = "_config_storage"
_COMPRESSED_STORAGE_VALUE = "compressed"
_COMPRESSED_DATA_FIELD = "_compressed_config"


def _isoformat_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _marker_key(version: str) -> str:
    """Partition key of the provenance sibling row for a config version."""
    return f"{_MARKER_PREFIX}#{version}"


def _seed_hash(merged_config: Dict[str, Any]) -> str:
    """Canonical-JSON sha256 of the stringified config the seeder writes, so it
    matches what a later invocation reconstructs via ``_stored_config_data``."""
    canonical = json.dumps(
        _stringify_values(merged_config),
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _decompress_if_needed(item: Dict[str, Any]) -> Dict[str, Any]:
    """Expand a runtime-compressed row (gzip blob under ``_compressed_config``)
    to its inline shape, mirroring the runtime's own _decompress_item. Rows that
    are not compressed are returned unchanged."""
    if item.get(_COMPRESSED_STORAGE_MARKER) != _COMPRESSED_STORAGE_VALUE:
        return item

    blob = item.get(_COMPRESSED_DATA_FIELD)
    if blob is None:
        return item
    try:
        raw = bytes(blob) if not isinstance(blob, bytes) else blob
        config_data = json.loads(gzip.decompress(raw).decode("utf-8"))
    except Exception as exc:  # pragma: no cover - corrupt/unknown blob
        logger.warning("Could not decompress stored config row: %s", exc)
        return item

    metadata = {k: v for k, v in item.items() if k in _METADATA_FIELDS}
    return {**metadata, **config_data}


def _stored_config_data(item: Dict[str, Any]) -> Dict[str, Any]:
    """Config-data portion of a stored row: decompress, then drop metadata."""
    expanded = _decompress_if_needed(item)
    return {k: v for k, v in expanded.items() if k not in _METADATA_FIELDS}


def _stringify_values(obj: Any) -> Any:
    """
    Recursively convert non-bool numeric values to strings.

    Mirrors `idp_common.config.records.ConfigurationRecord._stringify_values`:
    DynamoDB number storage round-trips through ``Decimal`` and breaks any
    Pydantic model that expects ``float`` / ``int``. The IDP convention is to
    store every numeric value as a string and let the Pydantic models coerce
    on read.

    Pass-through contract: this recursion is intentionally *generic* — it
    walks dicts and lists without any key allow-list or closed schema.
    Author-supplied ``x-aws-idp-*`` schema flags
    (``x-aws-idp-extraction-model``, ``x-aws-idp-exclude-from-processing`` +
    its ``reason``, ``x-aws-idp-page-types`` / ``x-aws-idp-source-page-types``)
    are therefore persisted into the configuration item verbatim, neither
    stripped nor renamed. These flags are enforced by the read-only
    ``idp_common`` runtime upstream; the seeder's only obligation is faithful
    pass-through, so do NOT add key-specific handling here.
    """
    if obj is None:
        return None
    if isinstance(obj, bool):
        return obj
    if isinstance(obj, dict):
        return {k: _stringify_values(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_stringify_values(item) for item in obj]
    if isinstance(obj, (int, float)):
        return str(obj)
    return obj


def _merge_with_system_defaults(user_config: Dict[str, Any]) -> Dict[str, Any]:
    """
    Merge a user-supplied IDP config with the built-in system defaults so
    runtime fields like `system_prompt` / `task_prompt` are populated.

    Auto-detects the pattern from the config (mirrors upstream
    `update_configuration:detect_pattern_from_config`). Defers the heavy
    lifting to ``idp_common.config.merge_utils.merge_config_with_defaults``,
    which is shipped via the Lambda layer.

    On any failure (system defaults not packaged in the layer, parse errors,
    etc.), we log the failure and return the original user config unchanged
    so the seeder still writes *something* to DynamoDB. The runtime will
    surface a clearer error than a Lambda-level crash here.
    """
    try:
        from idp_common.config.merge_utils import merge_config_with_defaults
    except Exception as exc:  # pragma: no cover - layer wiring smoke
        logger.error(
            "idp_common is not available to the seeder Lambda — system "
            "defaults will NOT be merged. Check that base_layer_arn is "
            "attached. Error: %s",
            exc,
        )
        return user_config

    pattern = _detect_pattern(user_config)
    logger.info("Merging user config with system defaults for pattern=%s", pattern)
    try:
        # validate=False is required for the pass-through contract: it
        # deep-merges the user config onto system defaults (user keys win,
        # arbitrary keys preserved) WITHOUT running idp_common's Pydantic /
        # JSON-Schema validation, which carries a closed ALLOWED_KEYWORDS set
        # that would otherwise flag unknown x-aws-idp-* schema flags. Runtime
        # enforcement of those flags lives upstream in idp_common.
        merged = merge_config_with_defaults(user_config, pattern=pattern, validate=False)
    except FileNotFoundError as exc:
        # Upstream IDP v0.6.4 ships a broken pattern-1.yaml (see
        # _merge_with_defaults_tolerant): its _inherits list names
        # base-assessment.yaml, which was deleted when assessment was folded
        # into extraction. Retry with a tolerant defaults loader rather than
        # degrading to an unmerged config.
        logger.warning(
            "System defaults inheritance failed (%s); retrying with a "
            "tolerant defaults loader.",
            exc,
        )
        try:
            merged = _merge_with_defaults_tolerant(user_config, pattern)
        except Exception as retry_exc:
            logger.warning(
                "Tolerant system-defaults merge also failed; saving user "
                "config unchanged. Error: %s",
                retry_exc,
            )
            return user_config
    except Exception as exc:  # pragma: no cover - belt-and-braces
        logger.warning(
            "Error merging with system defaults; saving user config "
            "unchanged. Error: %s",
            exc,
        )
        return user_config

    user_keys = set(user_config.keys())
    merged_keys = set(merged.keys())
    logger.info(
        "Merged config: user provided %d sections (%s), merged has %d sections (%s)",
        len(user_keys),
        sorted(user_keys),
        len(merged_keys),
        sorted(merged_keys),
    )
    return merged


def _resolve_inherits_tolerant(
    config: Dict[str, Any],
    defaults_dir,
    load_yaml_file,
    deep_update,
    seen: Optional[set] = None,
) -> Dict[str, Any]:
    """
    Resolve an ``_inherits`` chain, skipping entries whose file is absent.

    Byte-for-byte equivalent to ``merge_utils._resolve_inheritance`` except that
    a missing inherited file is logged and skipped instead of raising
    ``FileNotFoundError``. Ordering, cycle detection, and the
    "current config wins over everything it inherits" precedence are preserved.
    """
    seen = set() if seen is None else seen
    config = dict(config)
    inherits = config.pop("_inherits", None)
    if inherits is None:
        return config

    inherits_list = [inherits] if isinstance(inherits, str) else list(inherits)

    result: Dict[str, Any] = {}
    for inherit_file in inherits_list:
        if inherit_file in seen:
            logger.warning("Circular inheritance detected: %s", inherit_file)
            continue
        seen.add(inherit_file)

        inherit_path = defaults_dir / inherit_file
        if not inherit_path.exists():
            # The upstream v0.6.4 defect. Skipping is semantically correct:
            # the only missing file is base-assessment.yaml, and assessment
            # was retired as a standalone section in the v0.6 config model.
            logger.warning(
                "System defaults file %s is referenced by _inherits but does "
                "not exist; skipping it.",
                inherit_file,
            )
            continue

        inherited = _resolve_inherits_tolerant(
            load_yaml_file(inherit_path),
            defaults_dir,
            load_yaml_file,
            deep_update,
            seen.copy(),
        )
        deep_update(result, inherited)

    deep_update(result, config)
    return result


def _merge_with_defaults_tolerant(
    user_config: Dict[str, Any], pattern: str
) -> Dict[str, Any]:
    """
    Reproduce ``merge_config_with_defaults`` with a fault-tolerant defaults load.

    Why this exists: upstream IDP v0.6.4's
    ``system_defaults/pattern-1.yaml`` inherits ``base-assessment.yaml``, a file
    that no longer ships in v0.6.4 (assessment was folded into ``extraction``).
    ``merge_utils._resolve_inheritance`` raises ``FileNotFoundError`` on a
    missing inherited file, so **every BDA (pattern-1) deployment** would
    otherwise fall back to seeding the raw, unmerged user config — no default
    prompts, models, or classes.

    Fixing this in ``sources/`` is forbidden (`.kiro/steering/sources-readonly.md`),
    and the ``IDP_SYSTEM_DEFAULTS_DIR`` env-var override cannot help either:
    ``merge_utils.get_system_defaults_dir`` resolves the packaged resource
    directory at priority 1 and only consults the env var if that lookup fails,
    which it never does in a Lambda where ``idp_common`` is installed. So the
    repair lives here, in the wrapper's own Lambda.

    This is a fallback, not a replacement: ``_merge_with_system_defaults`` still
    calls upstream first and only lands here on ``FileNotFoundError``. When
    upstream repairs ``pattern-1.yaml`` (or drops the stale ``_inherits`` entry),
    the pristine path resumes automatically and this code stops executing.

    The migrate-then-merge ordering is preserved from upstream, and matters: see
    the "IMPORTANT -- migrate BEFORE merge" note in
    ``merge_utils.merge_config_with_defaults``.
    """
    from copy import deepcopy

    from idp_common.config.merge_utils import (
        deep_update,
        get_system_defaults_dir,
        load_yaml_file,
    )
    from idp_common.config.migrations.v05_to_v06 import migrate_v05_to_v06

    migrated = migrate_v05_to_v06(deepcopy(user_config))

    defaults_dir = get_system_defaults_dir()
    pattern_config = load_yaml_file(defaults_dir / f"{pattern}.yaml")
    defaults = _resolve_inherits_tolerant(
        pattern_config, defaults_dir, load_yaml_file, deep_update
    )

    result = deepcopy(defaults)
    deep_update(result, migrated)
    return result


def _detect_pattern(config: Dict[str, Any]) -> str:
    """
    Auto-detect the IDP pattern for system-default merging.

    Only ``pattern-1`` (BDA) and ``pattern-2`` (Bedrock LLM pipeline) exist:
    upstream removed Pattern 3 in IDP v0.5.0, and
    ``idp_common.config.merge_utils`` enforces that with
    ``VALID_PATTERNS = ["pattern-1", "pattern-2"]`` — asking it for
    ``pattern-3`` raises ``ValueError``.

    UDOP therefore maps to ``pattern-2``, not ``pattern-3``. In this wrapper
    SageMaker-UDOP is a façade over the unified (pattern-2 shaped) pipeline
    that swaps only the classification step for a UDOP endpoint bridge, so the
    pattern-2 defaults are the correct base for it: it needs the same OCR,
    extraction, assessment, summarization and evaluation defaults, and only its
    classification section differs.

    Previously UDOP returned ``pattern-3``, which made the merge raise; the
    caller's broad ``except`` then swallowed it and seeded the RAW user config
    with no system defaults merged in — silently omitting every default prompt
    and model setting.
    """
    if not isinstance(config, dict):
        return "pattern-2"
    method = (
        config.get("classification", {}).get("classificationMethod", "")
        if isinstance(config.get("classification"), dict)
        else ""
    )
    if method == "bda":
        return "pattern-1"
    return "pattern-2"


def _put_config_default(
    table,
    version: str,
    merged_config: Dict[str, Any],
    description: str,
    is_active: bool = True,
    managed: bool = False,
    bda_project_arn: Optional[str] = None,
    preserve_edits: bool = False,
) -> Dict[str, Any]:
    """
    Write a versioned Config item to DynamoDB, preserving operator edits.

    DynamoDB key shape: ``Configuration = "Config#<version>"``.
    Merged config sections are spread as top-level attributes (matching
    the v0.4.8 seeder convention and the IDPConfig.model_dump shape).

    ``is_active`` defaults to ``True`` so the runtime config loader resolves
    the seeded ``default`` version when no active version is explicitly
    tracked. Managed baseline configs are seeded with ``is_active=False`` so
    they remain selectable templates without hijacking the active runtime
    config.

    ``managed`` writes the top-level ``Managed`` attribute that the upstream
    ``idp_common`` config layer reads back as ``managed`` (see
    ``configuration_manager.py`` ``_DYNAMODB_METADATA_FIELDS`` /
    ``list_config_versions``). Rows flagged ``Managed=true`` are rejected by
    the upstream config-write path, making them non-editable through the
    normal config-edit operations.

    ``bda_project_arn``, when non-empty, links this version to a BDA project by
    stamping the top-level ``BdaProjectArn`` / ``BdaSyncStatus`` /
    ``BdaLastSyncedAt`` metadata (mirroring upstream ``set_bda_project_arn``);
    ``queue_processor`` reads it back and injects ``document.bda_project_arn`` so
    a ``use_bda: true`` version routes to BDA. Absent leaves the item unchanged,
    like the ``Managed`` marker.

    With ``preserve_edits`` (the active, non-managed ``default`` row) the write
    is read-modify-write: absent row → create + stamp; present with no marker →
    adopt once (first upgrade) + stamp; marker matches stored config → update +
    re-stamp, preserving ``CreatedAt``; marker mismatches → operator edit, skip.
    A ``ConditionExpression`` guards against a concurrent write. To overwrite a
    diverged row, delete its ``TerraformSeed#<version>`` marker and re-invoke
    (falls into the adopt branch); see the processor-configuration module.

    Without ``preserve_edits`` (managed baselines / non-active additional
    versions) the historical unconditional ``put_item`` is kept.
    """
    config_key = f"Config#{version}"

    existing_item: Optional[Dict[str, Any]] = None
    if preserve_edits:
        # Read error must fail the invocation, never default to overwrite.
        existing_item = _get_item(table, config_key)
        if existing_item is not None:
            stored_marker = _get_marker(table, version)
            decision = _reseed_decision(existing_item, stored_marker, merged_config)
            if decision == "skip":
                logger.info(
                    "Config#%s has diverged from what Terraform last seeded "
                    "(operator-owned) — skipping re-seed to preserve edits. "
                    "To overwrite, delete the TerraformSeed#%s marker item and "
                    "re-invoke.",
                    version,
                    version,
                )
                return {
                    "seeded": False,
                    "reason": "operator-owned-row-preserved",
                    "version": version,
                }
            logger.info("Config#%s re-seed decision: %s", version, decision)

    now = _isoformat_now()
    # Preserve CreatedAt on update; only a genuine create stamps it fresh.
    created_at = (
        existing_item.get("CreatedAt", now)
        if isinstance(existing_item, dict)
        else now
    )

    item: Dict[str, Any] = {
        "Configuration": config_key,
        "IsActive": is_active,
        "Description": description,
        "CreatedAt": created_at,
        "UpdatedAt": now,
        **_stringify_values(merged_config),
    }

    if managed:
        item["Managed"] = True

    # Mirrors upstream set_bda_project_arn; only stamped when a link is supplied.
    if bda_project_arn:
        item["BdaProjectArn"] = bda_project_arn
        item["BdaSyncStatus"] = "synced"
        item["BdaLastSyncedAt"] = now

    if preserve_edits:
        # Guard against a concurrent write between our read and this write:
        # absent row → require still-absent; present → require unchanged UpdatedAt.
        if existing_item is None:
            condition = "attribute_not_exists(Configuration)"
            expr_values = None
        else:
            prior_updated = existing_item.get("UpdatedAt")
            if prior_updated is None:
                condition = "attribute_exists(Configuration)"
                expr_values = None
            else:
                condition = "UpdatedAt = :prev"
                expr_values = {":prev": prior_updated}
        try:
            kwargs: Dict[str, Any] = {"Item": item, "ConditionExpression": condition}
            if expr_values is not None:
                kwargs["ExpressionAttributeValues"] = expr_values
            response = table.put_item(**kwargs)
        except ClientError as exc:
            if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
                logger.warning(
                    "Config#%s changed between read and write (concurrent "
                    "edit) — skipping re-seed to avoid clobbering it.",
                    version,
                )
                return {
                    "seeded": False,
                    "reason": "concurrent-modification",
                    "version": version,
                }
            raise
        _put_marker(table, version, merged_config)
        return response

    return table.put_item(Item=item)


def _get_item(table, config_key: str) -> Optional[Dict[str, Any]]:
    """Read a row by partition key, raising on any error (never swallow)."""
    response = table.get_item(Key={"Configuration": config_key})
    return response.get("Item")


def _get_marker(table, version: str) -> Optional[str]:
    """Read the stored provenance hash for a version, or None if unstamped."""
    response = table.get_item(Key={"Configuration": _marker_key(version)})
    item = response.get("Item")
    if not item:
        return None
    return item.get("SeedHash")


def _put_marker(table, version: str, merged_config: Dict[str, Any]) -> None:
    """Stamp the provenance sibling row with the hash of what we just wrote."""
    table.put_item(
        Item={
            "Configuration": _marker_key(version),
            "SeedHash": _seed_hash(merged_config),
            "UpdatedAt": _isoformat_now(),
        }
    )


def _reseed_decision(
    existing_item: Dict[str, Any],
    stored_marker: Optional[str],
    merged_config: Dict[str, Any],
) -> str:
    """Classify a present row: ``adopt`` (no marker → first upgrade), ``update``
    (stored config matches provenance → Terraform owns it), or ``skip`` (stored
    config diverged → operator edit, leave intact). Divergence is conservative:
    any byte change, including a benign runtime re-compress, counts as an edit."""
    if stored_marker is None:
        return "adopt"
    current_hash = _seed_hash(_stored_config_data(existing_item))
    return "update" if current_hash == stored_marker else "skip"


def _put_schema(table, schema: Dict[str, Any]) -> Dict[str, Any]:
    """Write the schema item, matching upstream's nested-under-Schema shape."""
    item = {
        "Configuration": "Schema",
        "Schema": _stringify_values(schema),
    }
    return table.put_item(Item=item)


def _delete_legacy_default_if_present(table) -> Optional[Dict[str, Any]]:
    """
    Remove the v0.4.8 legacy ``Default`` item if it exists.

    The new seeder always writes ``Config#default`` and never the legacy
    key, but this gives us idempotent recovery for stacks that were
    previously deployed against the old seeder. Mirrors the cleanup half
    of upstream ``detect_and_migrate_legacy_format``.
    """
    try:
        response = table.get_item(Key={"Configuration": "Default"})
    except Exception as exc:  # pragma: no cover
        logger.warning("Could not check for legacy Default item: %s", exc)
        return None

    if "Item" not in response:
        return None

    logger.info(
        "Legacy 'Default' item detected — deleting (replaced by Config#default)."
    )
    return table.delete_item(Key={"Configuration": "Default"})


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Seed the IDP configuration table with one of:

    * ``{"Key": "Default", "Value": {...config dict...}}`` — merges with
      system defaults and writes ``Configuration = "Config#default"`` with
      ``IsActive = true``. Also deletes any pre-existing legacy
      ``Configuration = "Default"`` item for fresh-deploy recovery.
    * ``{"Key": "Schema", "Value": {...schema dict...}}`` — writes
      ``Configuration = "Schema"``.

    Optional fields on a Default invocation:

    * ``Version``: version name to write under (defaults to ``"default"``).
    * ``Description``: free-text description stored on the item.
    * ``BdaProjectArn``: when non-empty, links this version to a BDA project
      (stamps ``BdaProjectArn`` / ``BdaSyncStatus`` / ``BdaLastSyncedAt``).

    Returns ``{"statusCode": 200, "body": json-string}`` on success or
    ``{"statusCode": 500, "body": json-string-with-error}`` on failure.
    """
    logger.info("Configuration seeder event: %s", json.dumps(event, default=str))
    try:
        key = event["Key"]
        value = event["Value"]
        table_name = os.environ["TABLE_NAME"]

        if key not in {"Default", "Schema"}:
            raise ValueError(f"Invalid Key: {key!r}. Must be 'Default' or 'Schema'.")

        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table(table_name)

        if key == "Schema":
            response = _put_schema(table, value)
            return {
                "statusCode": 200,
                "body": json.dumps(
                    {"message": "Stored Schema", "key": "Schema", "response": response},
                    default=str,
                ),
            }

        # key == "Default"
        version = event.get("Version", "default")
        description = event.get("Description", "Default IDP configuration")
        managed = bool(event.get("Managed", False))
        is_active = bool(event.get("IsActive", not managed))
        bda_project_arn = event.get("BdaProjectArn") or None
        # Only the active, non-managed default is the runtime's resolved config
        # (the only row an operator edits), so preservation applies there. Managed baselines (upstream-protected)
        # and additional versions (IsActive=false) keep the unconditional write.
        preserve_edits = is_active and not managed

        if not isinstance(value, dict):
            raise ValueError(
                "Default Value must be a dictionary; got "
                f"{type(value).__name__}."
            )

        # Belt-and-braces cleanup of any stale v0.4.8 record — only relevant
        # to the active default version, never to managed baselines.
        if not managed:
            _delete_legacy_default_if_present(table)

        merged = _merge_with_system_defaults(value)
        response = _put_config_default(
            table,
            version,
            merged,
            description,
            is_active=is_active,
            managed=managed,
            bda_project_arn=bda_project_arn,
            preserve_edits=preserve_edits,
        )

        seeded = not (isinstance(response, dict) and response.get("seeded") is False)

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": (
                        f"Stored Config#{version}"
                        if seeded
                        else f"Preserved existing Config#{version} "
                        f"({response.get('reason')})"
                    ),
                    "key": "Default",
                    "version": version,
                    "managed": managed,
                    "isActive": is_active,
                    "seeded": seeded,
                    "bdaProjectArn": bda_project_arn,
                    "merged_sections": sorted(merged.keys()),
                    "response": response,
                },
                default=str,
            ),
        }

    except Exception as exc:
        logger.exception("Configuration seeder failed")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(exc), "type": type(exc).__name__}),
        }
