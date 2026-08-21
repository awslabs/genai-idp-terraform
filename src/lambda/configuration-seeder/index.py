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
#   2. Always treats the call as a Create — the previous version of this
#      Lambda was idempotent on `put_item`, and aws_lambda_invocation
#      already triggers only when its input hash changes.

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import boto3
import yaml  # noqa: F401 — kept for parity with upstream; not used in current invocation shape

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def _isoformat_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


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
) -> Dict[str, Any]:
    """
    Write a versioned Config item to DynamoDB.

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
    """
    now = _isoformat_now()

    item: Dict[str, Any] = {
        "Configuration": f"Config#{version}",
        "IsActive": is_active,
        "Description": description,
        "CreatedAt": now,
        "UpdatedAt": now,
        **_stringify_values(merged_config),
    }

    # Only stamp the Managed marker when requested so non-managed rows are
    # byte-identical to the pre-B11 seeder output.
    if managed:
        item["Managed"] = True

    # Stamp the BDA link only when supplied, so unlinked rows are unchanged.
    # Mirrors upstream set_bda_project_arn (BdaProjectArn + BdaSyncStatus +
    # BdaLastSyncedAt as top-level metadata).
    if bda_project_arn:
        item["BdaProjectArn"] = bda_project_arn
        item["BdaSyncStatus"] = "synced"
        item["BdaLastSyncedAt"] = now

    return table.put_item(Item=item)


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
        # Managed baseline configs are seeded as non-active, non-editable
        # rows. Default invocations keep the historical is_active=true behavior.
        managed = bool(event.get("Managed", False))
        is_active = bool(event.get("IsActive", not managed))
        # Optional BDA project link (empty/absent leaves the item unchanged).
        bda_project_arn = event.get("BdaProjectArn") or None

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
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Stored Config#{version}",
                    "key": "Default",
                    "version": version,
                    "managed": managed,
                    "isActive": is_active,
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
