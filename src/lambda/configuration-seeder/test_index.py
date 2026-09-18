# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the IDP configuration seeder (wrapper-owned Lambda).
#
# The schema flags are a *pass-through* slice: the upstream `idp_common`
# runtime enforces the `x-aws-idp-*` schema flags, and the wrapper's only
# obligation is to persist them into the configuration DynamoDB item
# unchanged. These tests pin that contract:
#
#   (a) a config carrying all three flag families survives the seeder's
#       merge + item-construction path with every flag key present, unchanged,
#       in the constructed item; and
#   (b) a config WITHOUT the flags produces output byte-identical to the
#       flag-free seeder output — no flag is injected by default.
#
# The tests run fully offline: DynamoDB `put_item` is captured by a fake table
# (never called against AWS), and the layer-provided `idp_common` merge is
# stubbed with an identity-preserving merge that mirrors the upstream
# `validate=False` contract (user keys win, arbitrary keys preserved).

import copy
import importlib.util
import sys
import types
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Load the seeder module (the directory name `configuration-seeder` contains a
# hyphen, so it is not importable as a package — load index.py by path).
# ---------------------------------------------------------------------------
_SEEDER_PATH = Path(__file__).resolve().parent / "index.py"
_spec = importlib.util.spec_from_file_location("configuration_seeder_index", _SEEDER_PATH)
seeder = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(seeder)


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------
from botocore.exceptions import ClientError


def ConditionalCheckFailed():
    """Real botocore ClientError with the ConditionalCheckFailed code (the
    seeder inspects response['Error']['Code'], so a look-alike won't do)."""
    return ClientError(
        {"Error": {"Code": "ConditionalCheckFailedException", "Message": "conditional failed"}},
        "PutItem",
    )


class FakeTable:
    """In-memory DynamoDB stand-in: a keyed store (so read-modify-write and
    marker reads work offline) that also records the raw put sequence and
    honours the ConditionExpression shapes the seeder uses."""

    def __init__(self):
        self.put_items = []
        self.store = {}

    def put_item(self, Item, ConditionExpression=None, ExpressionAttributeValues=None):  # noqa: N803
        key = Item["Configuration"]
        if ConditionExpression == "attribute_not_exists(Configuration)":
            if key in self.store:
                raise ConditionalCheckFailed()
        elif ConditionExpression == "attribute_exists(Configuration)":
            if key not in self.store:
                raise ConditionalCheckFailed()
        elif ConditionExpression == "UpdatedAt = :prev":
            prev = (ExpressionAttributeValues or {}).get(":prev")
            current = self.store.get(key, {})
            if current.get("UpdatedAt") != prev:
                raise ConditionalCheckFailed()
        # Deep-copy so later mutation of the source dict can't retroactively
        # change what we assert on / what the store holds.
        stored = copy.deepcopy(Item)
        self.put_items.append(copy.deepcopy(Item))
        self.store[key] = stored
        return {"ResponseMetadata": {"HTTPStatusCode": 200}}

    def get_item(self, Key, **kwargs):  # noqa: N803 - boto3 kwarg name
        item = self.store.get(Key["Configuration"])
        return {"Item": copy.deepcopy(item)} if item is not None else {}

    def delete_item(self, Key, **kwargs):  # noqa: N803 - boto3 kwarg name
        self.store.pop(Key["Configuration"], None)
        return {"ResponseMetadata": {"HTTPStatusCode": 200}}

    # --- test conveniences ---------------------------------------------------
    def config_puts(self, version="default"):
        """Raw puts targeting the Config#<version> row, in order."""
        return [p for p in self.put_items if p["Configuration"] == f"Config#{version}"]


@pytest.fixture(autouse=True)
def _frozen_clock(monkeypatch):
    """Freeze the seeder clock so item construction is deterministic."""
    monkeypatch.setattr(seeder, "_isoformat_now", lambda: "2026-06-01T00:00:00Z")


@pytest.fixture(autouse=True)
def _identity_merge(monkeypatch):
    """
    Stub the layer-provided `idp_common` deep-merge with an identity merge.

    `_merge_with_system_defaults` imports
    `idp_common.config.merge_utils.merge_config_with_defaults` (shipped via the
    Lambda layer, absent in the offline test env). We inject a fake module so
    the seeder's real merge-invocation path runs deterministically. The stub
    mirrors the upstream `validate=False` contract the seeder relies on: it
    returns the user config unchanged (user keys win, arbitrary `x-aws-idp-*`
    keys preserved verbatim, no closed-schema stripping).
    """
    fake_pkg = types.ModuleType("idp_common")
    fake_config = types.ModuleType("idp_common.config")
    fake_merge_utils = types.ModuleType("idp_common.config.merge_utils")

    def merge_config_with_defaults(user_config, pattern=None, validate=True):
        # Identity merge: faithful to the pass-through contract under test.
        return copy.deepcopy(user_config)

    fake_merge_utils.merge_config_with_defaults = merge_config_with_defaults
    fake_config.merge_utils = fake_merge_utils
    fake_pkg.config = fake_config

    monkeypatch.setitem(sys.modules, "idp_common", fake_pkg)
    monkeypatch.setitem(sys.modules, "idp_common.config", fake_config)
    monkeypatch.setitem(sys.modules, "idp_common.config.merge_utils", fake_merge_utils)


# ---------------------------------------------------------------------------
# Flag fixtures — exact key names verified against
# sources/lib/idp_common_pkg/idp_common/config/schema_constants.py
# ---------------------------------------------------------------------------
# Per-class / per-attribute extraction-model override
B9_KEY = "x-aws-idp-extraction-model"
# Exclude-from-processing + its reason key
B10_KEY = "x-aws-idp-exclude-from-processing"
B10_REASON_KEY = "x-aws-idp-exclusion-reason"
# Page-type / source-page-type presence hints
B12_PAGE_TYPES_KEY = "x-aws-idp-page-types"
B12_SOURCE_PAGE_TYPES_KEY = "x-aws-idp-source-page-types"


def _config_without_flags():
    """A representative pattern-2 config carrying none of the schema flags."""
    return {
        "classes": [
            {
                "name": "Invoice",
                "description": "An invoice document",
                "attributes": [
                    {"name": "invoice_number", "description": "The invoice id"},
                    {"name": "total", "description": "Grand total"},
                ],
            },
            {
                "name": "PassportApplicationInstructions",
                "description": "Static instruction pages",
                "attributes": [],
            },
        ],
        "extraction": {"model": "us.anthropic.claude-3-5-sonnet"},
    }


def _config_with_all_flags():
    """The flag-free config with all three flag families layered on."""
    config = _config_without_flags()
    # Per-class extraction-model override + a per-attribute override.
    config["classes"][0][B9_KEY] = "us.anthropic.claude-3-haiku"
    config["classes"][0]["attributes"][0][B9_KEY] = "us.amazon.nova-pro"
    # Exclude a whole class from processing, with a reason.
    config["classes"][1][B10_KEY] = True
    config["classes"][1][B10_REASON_KEY] = "instructions"
    # Page-type declarations + per-attribute source-page-type hint.
    config["classes"][0][B12_PAGE_TYPES_KEY] = [
        {"name": "header", "description": "Invoice header page"},
    ]
    config["classes"][0]["attributes"][1][B12_SOURCE_PAGE_TYPES_KEY] = ["header"]
    return config


def _seed_default(table, value):
    """Run a config through the seeder's merge + item-construction path."""
    merged = seeder._merge_with_system_defaults(value)
    seeder._put_config_default(
        table,
        version="default",
        merged_config=merged,
        description="Default IDP configuration",
    )
    assert len(table.put_items) == 1, "expected exactly one put_item"
    return table.put_items[0]


# ---------------------------------------------------------------------------
# (a): all three flag families survive seeding unchanged
# ---------------------------------------------------------------------------
def test_all_three_flag_families_survive_seeding():
    """
    Every x-aws-idp-* flag key supplied by the author is present, unchanged,
    in the constructed configuration item.
    """
    table = FakeTable()
    item = _seed_default(table, _config_with_all_flags())

    classes = item["classes"]
    invoice, instructions = classes[0], classes[1]

    # B9 — class-level and attribute-level extraction-model override.
    assert invoice[B9_KEY] == "us.anthropic.claude-3-haiku"
    assert invoice["attributes"][0][B9_KEY] == "us.amazon.nova-pro"

    # B10 — exclude-from-processing flag + reason, both preserved.
    assert instructions[B10_KEY] is True
    assert instructions[B10_REASON_KEY] == "instructions"

    # B12 — page-types and source-page-types hints preserved (incl. structure).
    assert invoice[B12_PAGE_TYPES_KEY] == [
        {"name": "header", "description": "Invoice header page"},
    ]
    assert invoice["attributes"][1][B12_SOURCE_PAGE_TYPES_KEY] == ["header"]


def test_flag_keys_not_renamed_or_dropped():
    """
    The merge must not drop or overwrite any author-supplied flag family.
    """
    table = FakeTable()
    item = _seed_default(table, _config_with_all_flags())

    # Collect every key that appears anywhere in the constructed item.
    seen_keys = set()

    def _walk(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                seen_keys.add(k)
                _walk(v)
        elif isinstance(obj, list):
            for el in obj:
                _walk(el)

    _walk(item)

    for key in (
        B9_KEY,
        B10_KEY,
        B10_REASON_KEY,
        B12_PAGE_TYPES_KEY,
        B12_SOURCE_PAGE_TYPES_KEY,
    ):
        assert key in seen_keys, f"flag key {key!r} was dropped or renamed"


# ---------------------------------------------------------------------------
# (b): a flag-free config is byte-identical to the flag-free output
# ---------------------------------------------------------------------------
def test_config_without_flags_is_byte_identical_to_pre_round3():
    """
    A config carrying none of the schema flags produces output byte-identical
    to the flag-free seeder item — no flag is injected by default.
    """
    table = FakeTable()
    source = _config_without_flags()
    item = _seed_default(table, source)

    # The flag-free seeder wraps the (stringified) config in the versioned
    # metadata envelope and adds nothing else. This is the golden output.
    expected = {
        "Configuration": "Config#default",
        "IsActive": True,
        "Description": "Default IDP configuration",
        "CreatedAt": "2026-06-01T00:00:00Z",
        "UpdatedAt": "2026-06-01T00:00:00Z",
        **seeder._stringify_values(source),
    }

    assert item == expected

    # And explicitly: none of the schema flag keys were injected.
    serialized = repr(item)
    for key in (
        B9_KEY,
        B10_KEY,
        B10_REASON_KEY,
        B12_PAGE_TYPES_KEY,
        B12_SOURCE_PAGE_TYPES_KEY,
    ):
        assert key not in serialized, f"flag key {key!r} was injected by default"


def test_put_item_not_called_against_aws():
    """The constructed item is asserted offline; no real DynamoDB call occurs."""
    table = FakeTable()
    _seed_default(table, _config_with_all_flags())
    # FakeTable captured the item; boto3 was never used for put_item.
    assert table.put_items, "put_item should have been invoked on the fake table"


# ---------------------------------------------------------------------------
# BDA project linking: `BdaProjectArn` set iff supplied, else the item is
# unchanged from the no-arn seeder output.
# ---------------------------------------------------------------------------
_BDA_PROJECT_ARN = (
    "arn:aws:bedrock:us-west-2:123456789012:data-automation-project/abc123"
)

# The three top-level metadata attributes upstream `set_bda_project_arn`
# stamps together; the seeder mirrors that exact set.
_BDA_KEYS = ("BdaProjectArn", "BdaSyncStatus", "BdaLastSyncedAt")


def _seed_default_with_arn(table, value, bda_project_arn):
    """Run a config through the seeder's item-construction path with an ARN."""
    merged = seeder._merge_with_system_defaults(value)
    seeder._put_config_default(
        table,
        version="default",
        merged_config=merged,
        description="Default IDP configuration",
        bda_project_arn=bda_project_arn,
    )
    assert len(table.put_items) == 1, "expected exactly one put_item"
    return table.put_items[0]


def test_bda_project_arn_supplied_stamps_link_metadata():
    """
    With a non-empty `BdaProjectArn`, the constructed item carries
    `BdaProjectArn` (equal to the input) plus the companion
    `BdaSyncStatus = "synced"` and a `BdaLastSyncedAt` timestamp, mirroring
    upstream `set_bda_project_arn`.
    """
    table = FakeTable()
    item = _seed_default_with_arn(table, _config_without_flags(), _BDA_PROJECT_ARN)

    assert item["BdaProjectArn"] == _BDA_PROJECT_ARN
    assert item["BdaSyncStatus"] == "synced"
    # Frozen clock — deterministic, ISO-8601 Z-suffixed timestamp.
    assert item["BdaLastSyncedAt"] == "2026-06-01T00:00:00Z"


def test_no_bda_project_arn_is_byte_identical_to_no_arn_output():
    """
    Without a `BdaProjectArn`, the item is byte-identical to the no-arn output
    for the same input: the three BDA link attributes are purely additive and
    never injected by default.
    """
    source = _config_without_flags()

    # Pre-change output: the seeder called with no BDA arn.
    baseline_table = FakeTable()
    baseline_item = _seed_default(baseline_table, source)

    # Same input, still no arn (empty / None short-circuits to no-op).
    for empty in (None, ""):
        table = FakeTable()
        item = _seed_default_with_arn(table, source, empty)
        assert item == baseline_item, (
            f"BdaProjectArn={empty!r} must leave the item byte-identical to "
            "the no-arn output"
        )
        for key in _BDA_KEYS:
            assert key not in item, f"{key!r} injected when no arn supplied"


def test_bda_link_item_equals_no_arn_item_without_bda_keys():
    """
    The arn-supplied item differs from the no-arn item by exactly the three
    BDA link attributes: stripping those keys yields the byte-identical
    pre-change item.
    """
    source = _config_without_flags()

    baseline_table = FakeTable()
    baseline_item = _seed_default(baseline_table, source)

    linked_table = FakeTable()
    linked_item = _seed_default_with_arn(linked_table, source, _BDA_PROJECT_ARN)

    # The only difference is the additive BDA link block.
    assert set(linked_item) - set(baseline_item) == set(_BDA_KEYS)

    stripped = {k: v for k, v in linked_item.items() if k not in _BDA_KEYS}
    assert stripped == baseline_item


def test_bda_link_put_item_not_called_against_aws():
    """The linked item is asserted offline; no real DynamoDB call occurs."""
    table = FakeTable()
    _seed_default_with_arn(table, _config_without_flags(), _BDA_PROJECT_ARN)
    assert table.put_items, "put_item should have been invoked on the fake table"


# ---------------------------------------------------------------------------
# Edit preservation + provenance (config-ownership-and-seeding): the
# read-modify-write path for the active `default` version (preserve_edits=True).


def _seed_preserving(table, value, *, description="Default IDP configuration"):
    """Drive the seeder's active-default (preserving) path for one config."""
    merged = seeder._merge_with_system_defaults(value)
    return seeder._put_config_default(
        table,
        version="default",
        merged_config=merged,
        description=description,
        is_active=True,
        preserve_edits=True,
    )


def _config_v1():
    return {"extraction": {"model": "us.amazon.nova-lite-v1:0"}, "classes": []}


def _config_v2():
    return {"extraction": {"model": "us.anthropic.claude-3-5-sonnet"}, "classes": []}


def _marker_row(table):
    return table.store.get("TerraformSeed#default")


def test_create_writes_config_and_stamps_marker():
    """First seed of an absent row creates the Config row and a provenance row."""
    table = FakeTable()
    _seed_preserving(table, _config_v1())

    # Config row present, IsActive, and the provenance sibling stamped.
    config = table.store["Config#default"]
    assert config["IsActive"] is True
    marker = _marker_row(table)
    assert marker is not None
    assert marker["Configuration"] == "TerraformSeed#default"
    assert marker["SeedHash"] == seeder._seed_hash(
        seeder._merge_with_system_defaults(_config_v1())
    )
    # The marker is a SEPARATE item — never a top-level attr on the config row.
    assert "SeedHash" not in config


def test_update_of_unmodified_row_rewrites_and_preserves_created_at():
    """An untouched row is updated to new desired config; CreatedAt survives."""
    table = FakeTable()
    _seed_preserving(table, _config_v1())
    original_created = table.store["Config#default"]["CreatedAt"]

    # Advance the clock so a create would stamp a different CreatedAt.
    seeder._isoformat_now = lambda: "2027-01-01T00:00:00Z"  # type: ignore[assignment]
    try:
        _seed_preserving(table, _config_v2())
    finally:
        seeder._isoformat_now = lambda: "2026-06-01T00:00:00Z"  # type: ignore[assignment]

    updated = table.store["Config#default"]
    assert updated["extraction"]["model"] == "us.anthropic.claude-3-5-sonnet"
    assert updated["CreatedAt"] == original_created  # preserved
    assert updated["UpdatedAt"] == "2027-01-01T00:00:00Z"  # advanced
    # Marker re-stamped to the new content.
    assert _marker_row(table)["SeedHash"] == seeder._seed_hash(
        seeder._merge_with_system_defaults(_config_v2())
    )


def test_operator_edited_row_is_preserved():
    """A row diverged from the stamped provenance is left intact and skipped."""
    table = FakeTable()
    _seed_preserving(table, _config_v1())

    # Simulate an operator UI edit: mutate the stored config, marker unchanged.
    table.store["Config#default"]["extraction"]["model"] = "operator.custom.model"
    table.store["Config#default"]["UpdatedAt"] = "2026-07-01T00:00:00Z"

    result = _seed_preserving(table, _config_v2())

    assert result == {
        "seeded": False,
        "reason": "operator-owned-row-preserved",
        "version": "default",
    }
    # Untouched: still the operator's value, not the desired v2 value.
    assert table.store["Config#default"]["extraction"]["model"] == "operator.custom.model"


def test_deleting_marker_readopts_and_overwrites_diverged_row():
    """Documented force procedure: deleting the marker makes the seeder adopt
    (overwrite once) a diverged row on the next invocation."""
    table = FakeTable()
    _seed_preserving(table, _config_v1())

    # Operator edits the row; with the marker present this would be preserved.
    table.store["Config#default"]["extraction"]["model"] = "operator.custom.model"
    table.store["Config#default"]["UpdatedAt"] = "2026-07-01T00:00:00Z"
    assert _seed_preserving(table, _config_v2())["reason"] == "operator-owned-row-preserved"

    # Delete the provenance marker (the documented break-glass step), then
    # re-invoke: the row now looks unstamped -> adopt -> overwrite once.
    del table.store["TerraformSeed#default"]
    _seed_preserving(table, _config_v2())

    assert table.store["Config#default"]["extraction"]["model"] == (
        "us.anthropic.claude-3-5-sonnet"
    )
    # Provenance re-stamped to the reasserted content.
    assert _marker_row(table)["SeedHash"] == seeder._seed_hash(
        seeder._merge_with_system_defaults(_config_v2())
    )


def test_missing_marker_is_adopted_on_first_upgrade():
    """A pre-existing row with no marker is adopted (written once + stamped)."""
    table = FakeTable()
    # A pre-existing row with NO TerraformSeed# marker (legacy deployment).
    table.store["Config#default"] = {
        "Configuration": "Config#default",
        "IsActive": True,
        "Description": "Default IDP configuration",
        "CreatedAt": "2025-01-01T00:00:00Z",
        "UpdatedAt": "2025-01-01T00:00:00Z",
        "extraction": {"model": "legacy.model"},
        "classes": [],
    }

    _seed_preserving(table, _config_v2())

    updated = table.store["Config#default"]
    assert updated["extraction"]["model"] == "us.anthropic.claude-3-5-sonnet"
    # CreatedAt from the legacy row is preserved even on adopt.
    assert updated["CreatedAt"] == "2025-01-01T00:00:00Z"
    assert _marker_row(table) is not None


def test_marker_is_stable_for_identical_input():
    """Re-seeding identical config updates in place and keeps the same hash."""
    table = FakeTable()
    _seed_preserving(table, _config_v1())
    first_hash = _marker_row(table)["SeedHash"]

    # Re-seed the SAME desired config: decision is "update" (matches marker),
    # and the recomputed hash is identical.
    _seed_preserving(table, _config_v1())
    assert _marker_row(table)["SeedHash"] == first_hash
    # Two config puts total (create + idempotent update), never a skip.
    assert len(table.config_puts()) == 2


def test_read_failure_raises_rather_than_overwriting():
    """A read error must fail the invocation, never default to overwrite."""

    class ExplodingTable(FakeTable):
        def get_item(self, Key, **kwargs):  # noqa: N803
            raise RuntimeError("dynamodb unavailable")

    table = ExplodingTable()
    merged = seeder._merge_with_system_defaults(_config_v1())
    with pytest.raises(RuntimeError, match="dynamodb unavailable"):
        seeder._put_config_default(
            table,
            version="default",
            merged_config=merged,
            description="Default IDP configuration",
            is_active=True,
            preserve_edits=True,
        )
    # Nothing was written.
    assert table.put_items == []


def test_concurrent_modification_between_read_and_write_is_not_clobbered():
    """A conditional-check failure on write is treated as skip, not clobber."""

    class RaceTable(FakeTable):
        def put_item(self, Item, ConditionExpression=None, ExpressionAttributeValues=None):  # noqa: N803
            # Only the Config row write is guarded; simulate a concurrent edit
            # by failing the conditional exactly once for it.
            if (
                Item["Configuration"] == "Config#default"
                and ConditionExpression == "UpdatedAt = :prev"
            ):
                raise ConditionalCheckFailed()
            return super().put_item(Item, ConditionExpression, ExpressionAttributeValues)

    table = RaceTable()
    # Seed once (create path) so an update path is exercised next.
    _seed_preserving(table, _config_v1())
    result = _seed_preserving(table, _config_v2())
    assert result == {
        "seeded": False,
        "reason": "concurrent-modification",
        "version": "default",
    }


def test_non_default_versions_keep_unconditional_write():
    """
    Managed / additional (non-active) versions do NOT read-modify-write: they
    keep the historical unconditional put and never stamp a provenance row.
    """
    table = FakeTable()
    merged = seeder._merge_with_system_defaults(_config_v1())
    seeder._put_config_default(
        table,
        version="lending",
        merged_config=merged,
        description="Managed configuration: lending",
        is_active=False,
        managed=True,
        preserve_edits=False,
    )
    assert table.store["Config#lending"]["Managed"] is True
    assert table.store["Config#lending"]["IsActive"] is False
    # No provenance sibling for non-preserved rows.
    assert "TerraformSeed#lending" not in table.store
