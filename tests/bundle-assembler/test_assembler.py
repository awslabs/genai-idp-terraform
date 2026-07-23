# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Unit tests for the bundle assembler Lambda."""

import importlib
import io
import json

import boto3
import pytest
from moto import mock_aws

STAGING = "stg-bucket"


# --------------------------------------------------------------------------
# Fixtures
# --------------------------------------------------------------------------
def _one_page_pdf():
    from pypdf import PdfWriter

    w = PdfWriter()
    w.add_blank_page(width=200, height=200)
    buf = io.BytesIO()
    w.write(buf)
    return buf.getvalue()


def _one_px_png():
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", (10, 10), "white").save(buf, "PNG")
    return buf.getvalue()


def _two_frame_tiff():
    from PIL import Image

    f1 = Image.new("RGB", (10, 10), "white")
    f2 = Image.new("RGB", (10, 10), "black")
    buf = io.BytesIO()
    f1.save(buf, "TIFF", save_all=True, append_images=[f2])
    return buf.getvalue()


# --------------------------------------------------------------------------
# resolve_bundle
# --------------------------------------------------------------------------
@mock_aws
def test_resolve_parts_uses_manifest_order():
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket=STAGING)
    for k in ["bundles/b1/b.png", "bundles/b1/a.pdf", "bundles/b1/manifest.json"]:
        s3.put_object(Bucket=STAGING, Key=k, Body=b"x")
    mod = importlib.import_module("index")
    keys, cfg = mod.resolve_bundle(
        s3,
        STAGING,
        "bundles/b1/manifest.json",
        json.dumps({"order": ["a.pdf", "b.png"], "config_version": "v2"}).encode(),
    )
    assert keys == ["bundles/b1/a.pdf", "bundles/b1/b.png"]
    assert cfg == "v2"


@mock_aws
def test_resolve_parts_lexical_when_no_order():
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket=STAGING)
    for k in ["bundles/b1/z.pdf", "bundles/b1/a.pdf", "bundles/b1/manifest.json"]:
        s3.put_object(Bucket=STAGING, Key=k, Body=b"x")
    mod = importlib.import_module("index")
    keys, cfg = mod.resolve_bundle(s3, STAGING, "bundles/b1/manifest.json", b"{}")
    assert keys == ["bundles/b1/a.pdf", "bundles/b1/z.pdf"]
    assert cfg is None


@mock_aws
def test_resolve_parts_raises_on_order_mismatch():
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket=STAGING)
    for k in ["bundles/b1/a.pdf", "bundles/b1/manifest.json"]:
        s3.put_object(Bucket=STAGING, Key=k, Body=b"x")
    mod = importlib.import_module("index")
    with pytest.raises(ValueError):
        # order names a file that was not uploaded
        mod.resolve_bundle(
            s3,
            STAGING,
            "bundles/b1/manifest.json",
            json.dumps({"order": ["a.pdf", "missing.pdf"]}).encode(),
        )


# --------------------------------------------------------------------------
# merge_to_pdf
# --------------------------------------------------------------------------
def test_merge_pdf_and_image_yields_multipage_pdf():
    mod = importlib.import_module("index")
    from pypdf import PdfReader

    parts = [("a.pdf", _one_page_pdf()), ("b.png", _one_px_png())]
    merged = mod.merge_to_pdf(parts)
    assert PdfReader(io.BytesIO(merged)).get_num_pages() == 2


def test_merge_multiframe_tiff_keeps_all_pages():
    mod = importlib.import_module("index")
    from pypdf import PdfReader

    merged = mod.merge_to_pdf([("scan.tiff", _two_frame_tiff())])
    assert PdfReader(io.BytesIO(merged)).get_num_pages() == 2


def test_merge_rejects_unsupported_type():
    mod = importlib.import_module("index")
    with pytest.raises(ValueError):
        mod.merge_to_pdf([("notes.txt", b"hello")])


# --------------------------------------------------------------------------
# handler
# --------------------------------------------------------------------------
@mock_aws
def test_handler_writes_merged_pdf_with_config_metadata(monkeypatch):
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket=STAGING)
    s3.create_bucket(Bucket="idp-input")
    s3.put_object(Bucket=STAGING, Key="bundles/b1/a.pdf", Body=_one_page_pdf())
    s3.put_object(Bucket=STAGING, Key="bundles/b1/b.png", Body=_one_px_png())
    s3.put_object(
        Bucket=STAGING,
        Key="bundles/b1/manifest.json",
        Body=json.dumps(
            {"order": ["a.pdf", "b.png"], "config_version": "v2"}
        ).encode(),
    )
    monkeypatch.setenv("IDP_INPUT_BUCKET", "idp-input")
    monkeypatch.setenv("DEFAULT_CONFIG_VERSION", "default")
    mod = importlib.reload(importlib.import_module("index"))
    event = {
        "detail": {
            "bucket": {"name": STAGING},
            "object": {"key": "bundles/b1/manifest.json"},
        }
    }
    result = mod.handler(event, None)
    assert result["assembled"] is True
    assert result["partCount"] == 2

    head = s3.head_object(Bucket="idp-input", Key="b1.pdf")
    assert head["Metadata"]["config-version"] == "v2"

    from pypdf import PdfReader

    body = s3.get_object(Bucket="idp-input", Key="b1.pdf")["Body"].read()
    assert PdfReader(io.BytesIO(body)).get_num_pages() == 2


@mock_aws
def test_handler_is_idempotent(monkeypatch):
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket=STAGING)
    s3.create_bucket(Bucket="idp-input")
    s3.put_object(Bucket=STAGING, Key="bundles/b1/a.pdf", Body=_one_page_pdf())
    s3.put_object(Bucket=STAGING, Key="bundles/b1/manifest.json", Body=b"{}")
    # Pre-existing merged output → handler must skip.
    s3.put_object(Bucket="idp-input", Key="b1.pdf", Body=_one_page_pdf())
    monkeypatch.setenv("IDP_INPUT_BUCKET", "idp-input")
    mod = importlib.reload(importlib.import_module("index"))
    event = {
        "detail": {
            "bucket": {"name": STAGING},
            "object": {"key": "bundles/b1/manifest.json"},
        }
    }
    result = mod.handler(event, None)
    assert result["assembled"] is False
    assert result["reason"] == "already exists"
