# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Bundle assembler Lambda.

Merges multiple loose files that share a bundle prefix in a staging bucket into
one multi-page PDF, then writes that single file to the IDP input bucket so the
accelerator processes them as ONE bundle (one document, section-split, one
post-processing-hook invocation).

Triggered by an EventBridge rule on the staging bucket for
`bundles/<bundle-id>/manifest.json` objects (the manifest is written LAST, after
all parts, as the completion sentinel).
"""

import io
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Image extensions the accelerator's OCR supports; anything else in a bundle is
# an error (fail loudly rather than silently drop a page).
_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".tif", ".webp"}

# Lazy S3 client — do NOT create at import (a module-level boto3.client("s3")
# raises NoRegionError when no region is configured, e.g. in unit tests).
_s3_client = None


def _s3():
    """Return a lazily-created S3 client (avoids import-time region errors)."""
    global _s3_client
    if _s3_client is None:
        _s3_client = boto3.client("s3")
    return _s3_client


def resolve_bundle(s3, staging_bucket, manifest_key, manifest_body):
    """Resolve the ordered part keys and config version for a bundle.

    Args:
        s3: boto3 S3 client.
        staging_bucket (str): staging bucket name.
        manifest_key (str): key of the manifest.json that triggered assembly,
            of the form ``bundles/<id>/manifest.json``.
        manifest_body (bytes): raw manifest content
            (``{"order": [...], "config_version": "..."}``; both optional).

    Returns:
        tuple[list[str], str | None]: (ordered part S3 keys, config version).

    Raises:
        ValueError: if the manifest ``order`` does not match the uploaded parts.
    """
    prefix = manifest_key.rsplit("/", 1)[0] + "/"
    manifest = json.loads(manifest_body or b"{}")

    # List all objects under the bundle prefix, excluding the manifest and any
    # zero-byte "folder" placeholder keys.
    keys = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=staging_bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            if obj["Key"] != manifest_key and not obj["Key"].endswith("/"):
                keys.append(obj["Key"])

    order = manifest.get("order")
    if order:
        rank = {f"{prefix}{name}": i for i, name in enumerate(order)}
        # Fail loudly: a manifest order that names a missing part, or omits an
        # uploaded part, is a real error — silently dropping pages corrupts the
        # bundle.
        listed = set(keys)
        missing = [n for n in order if f"{prefix}{n}" not in listed]
        extra = [k for k in keys if k not in rank]
        if missing or extra:
            raise ValueError(
                f"Manifest order does not match uploaded parts for {prefix}: "
                f"missing={missing} extra={[k[len(prefix):] for k in extra]}"
            )
        keys.sort(key=lambda k: rank[k])
    else:
        keys.sort()

    return keys, manifest.get("config_version")


def merge_to_pdf(parts):
    """Merge ordered parts into a single multi-page PDF.

    Args:
        parts (list[tuple[str, bytes]]): (filename, content) in final order.

    Returns:
        bytes: the merged multi-page PDF.

    Raises:
        ValueError: if a part has an unsupported extension.
    """
    from pypdf import PdfReader, PdfWriter
    from PIL import Image, ImageSequence

    writer = PdfWriter()
    for name, data in parts:
        ext = os.path.splitext(name.lower())[1]
        if ext == ".pdf":
            for page in PdfReader(io.BytesIO(data)).pages:
                writer.add_page(page)
        elif ext in _IMAGE_EXTS:
            # Iterate every frame so multi-page TIFFs and animated GIFs keep all
            # pages — a plain convert("RGB").save("PDF") emits only frame 0.
            frames = [
                f.convert("RGB")
                for f in ImageSequence.Iterator(Image.open(io.BytesIO(data)))
            ]
            if not frames:
                logger.warning("No frames decoded from image part %s", name)
                continue
            pbuf = io.BytesIO()
            frames[0].save(pbuf, "PDF", save_all=True, append_images=frames[1:])
            for page in PdfReader(io.BytesIO(pbuf.getvalue())).pages:
                writer.add_page(page)
        else:
            # Fail loudly: an unexpected extension means the manifest/upload is
            # wrong. Raise rather than silently dropping a page.
            raise ValueError(f"Unsupported bundle part type: {name}")

    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def handler(event, context):
    """Assemble a bundle from an EventBridge manifest-created event.

    Args:
        event (dict): EventBridge S3 "Object Created" event for the manifest.
        context: Lambda context (unused).

    Returns:
        dict: assembly outcome (assembled flag, output key, part count).
    """
    s3_client = _s3()
    idp_input_bucket = os.environ["IDP_INPUT_BUCKET"]
    default_config_version = os.environ.get("DEFAULT_CONFIG_VERSION", "default")

    detail = event["detail"]
    staging_bucket = detail["bucket"]["name"]
    manifest_key = detail["object"]["key"]
    logger.info(
        "Assembling bundle for manifest s3://%s/%s", staging_bucket, manifest_key
    )

    manifest_body = s3_client.get_object(Bucket=staging_bucket, Key=manifest_key)[
        "Body"
    ].read()
    part_keys, cfg_version = resolve_bundle(
        s3_client, staging_bucket, manifest_key, manifest_body
    )
    if not part_keys:
        logger.warning("No parts found for %s; nothing to assemble", manifest_key)
        return {"assembled": False, "reason": "no parts"}

    bundle_id = manifest_key.rsplit("/", 1)[0].rsplit("/", 1)[-1]
    out_key = f"{bundle_id}.pdf"

    # Idempotency guard: EventBridge is at-least-once and the target retries, so
    # the same manifest can fire more than once. If the merged bundle already
    # exists, skip — otherwise we'd overwrite it and spawn a SECOND IDP
    # execution for the same bundle.
    try:
        s3_client.head_object(Bucket=idp_input_bucket, Key=out_key)
        logger.info("Bundle %s already assembled; skipping (idempotent)", out_key)
        return {"assembled": False, "reason": "already exists", "outputKey": out_key}
    except s3_client.exceptions.ClientError as e:
        if e.response["Error"]["Code"] not in ("404", "NoSuchKey", "NotFound"):
            raise

    parts = []
    for k in part_keys:
        data = s3_client.get_object(Bucket=staging_bucket, Key=k)["Body"].read()
        parts.append((k.rsplit("/", 1)[-1], data))

    merged = merge_to_pdf(parts)

    s3_client.put_object(
        Bucket=idp_input_bucket,
        Key=out_key,
        Body=merged,
        ContentType="application/pdf",
        Metadata={"config-version": cfg_version or default_config_version},
    )
    logger.info(
        "Wrote merged bundle to s3://%s/%s (%d parts)",
        idp_input_bucket,
        out_key,
        len(parts),
    )
    return {"assembled": True, "outputKey": out_key, "partCount": len(parts)}
