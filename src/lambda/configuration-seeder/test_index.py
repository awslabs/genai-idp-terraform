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
class FakeTable:
    """Captures the item handed to `put_item` without touching AWS."""

    def __init__(self):
        self.put_items = []

    def put_item(self, Item):  # noqa: N803 - boto3 kwarg name
        # Deep-copy so later mutation of the source dict can't retroactively
        # change what we assert on.
        self.put_items.append(copy.deepcopy(Item))
        return {"ResponseMetadata": {"HTTPStatusCode": 200}}


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
