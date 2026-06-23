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
#
# Captures NOTE-014 / NOTE-014b in
# `.kiro/terraform-upgrades/history/v0.4.8-to-v0.4.16/notes.md`.

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

    Pass-through contract (B9/B10/B12): this recursion is intentionally
    *generic* — it walks dicts and lists without any key allow-list or closed
    schema. Author-supplied ``x-aws-idp-*`` schema flags
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
        # validate=False is required for the B9/B10/B12 pass-through contract:
        # it deep-merges the user config onto system defaults (user keys win,
        # arbitrary keys preserved) WITHOUT running idp_common's Pydantic /
        # JSON-Schema validation, which carries a closed ALLOWED_KEYWORDS set
        # that would otherwise flag unknown x-aws-idp-* schema flags. Runtime
        # enforcement of those flags lives upstream in idp_common.
        merged = merge_config_with_defaults(user_config, pattern=pattern, validate=False)
    except FileNotFoundError as exc:
        logger.warning(
            "System defaults YAMLs missing from the Lambda layer (%s); "
            "saving user config unchanged.",
            exc,
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


def _detect_pattern(config: Dict[str, Any]) -> str:
    """
    Auto-detect the IDP pattern from a user config.

    Mirrors upstream ``update_configuration.detect_pattern_from_config``:
    BDA → pattern-1, UDOP → pattern-3, otherwise pattern-2 (Bedrock LLM,
    the most common case).
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
    if method == "udop":
        return "pattern-3"
    return "pattern-2"


def _put_config_default(
    table,
    version: str,
    merged_config: Dict[str, Any],
    description: str,
    is_active: bool = True,
    managed: bool = False,
) -> Dict[str, Any]:
    """
    Write a versioned Config item to DynamoDB.

    DynamoDB key shape: ``Configuration = "Config#<version>"``.
    Merged config sections are spread as top-level attributes (matching
    the v0.4.8 seeder convention and the IDPConfig.model_dump shape).

    ``is_active`` defaults to ``True`` so the runtime config loader resolves
    the seeded ``default`` version when no active version is explicitly
    tracked. Managed baseline configs (B11) are seeded with
    ``is_active=False`` so they remain selectable templates without
    hijacking the active runtime config.

    ``managed`` writes the top-level ``Managed`` attribute that the upstream
    ``idp_common`` config layer reads back as ``managed`` (see
    ``configuration_manager.py`` ``_DYNAMODB_METADATA_FIELDS`` /
    ``list_config_versions``). Rows flagged ``Managed=true`` are rejected by
    the upstream config-write path, making them non-editable through the
    normal config-edit operations.
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
        # B11: managed baseline configs are seeded as non-active, non-editable
        # rows. Default invocations keep the historical is_active=true behavior.
        managed = bool(event.get("Managed", False))
        is_active = bool(event.get("IsActive", not managed))

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
