# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Multi-Document Discovery: Prepare & List Documents handler.

Step Functions step 1: Validates input, extracts zip if uploaded,
lists documents in S3 prefix, and returns document keys.
"""

import logging
import os
import tempfile
import zipfile

import boto3

from appsync_status import update_status

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

DISCOVERY_BUCKET = os.environ.get("DISCOVERY_BUCKET", "")
SUPPORTED_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".tif", ".webp"}
MAX_DOCUMENTS = 500


def handler(event, context):
    """
    Prepare step: validate input, extract zip, list documents.

    Input (from Step Functions):
        jobId: str
        bucket: str
        prefix: str
        configVersion: str
        isZipUpload: bool

    Returns:
        bucket: str - bucket containing documents
        prefix: str - prefix containing documents
        s3Keys: list[str] - list of S3 keys for documents
        documentCount: int - number of documents found
    """
    job_id = event["jobId"]
    bucket = event.get("bucket", DISCOVERY_BUCKET)
    prefix = event.get("prefix", "")
    is_zip = event.get("isZipUpload", False)

    logger.info(
        f"Preparing multi-doc discovery job {job_id}: "
        f"bucket={bucket}, prefix={prefix}, isZip={is_zip}"
    )

    # Notify UI: PREPARING status
    update_status(job_id, "PREPARING", current_step="Listing documents")

    s3_client = boto3.client("s3")

    # If zip upload, extract first
    if is_zip:
        prefix = _extract_zip(s3_client, bucket, prefix, job_id)

    # List documents
    s3_keys = _list_documents(s3_client, bucket, prefix)

    logger.info(f"Found {len(s3_keys)} documents for job {job_id}")

    return {
        "bucket": bucket,
        "prefix": prefix,
        "s3Keys": s3_keys,
        "documentCount": len(s3_keys),
    }


def _extract_zip(s3_client, bucket, zip_key, job_id):
    """Extract zip file to a job-specific prefix and return the new prefix."""
    extract_prefix = f"multi-doc-discovery/{job_id}/documents/"

    logger.info(f"Extracting zip {zip_key} to {extract_prefix}")

    # Download zip to temp file
    with tempfile.NamedTemporaryFile(suffix=".zip", delete=True) as tmp:
        s3_client.download_file(bucket, zip_key, tmp.name)

        with zipfile.ZipFile(tmp.name, "r") as zf:
            for member in zf.namelist():
                # Skip directories and hidden files
                if member.endswith("/") or member.startswith("__MACOSX"):
                    continue

                # Check if supported file type
                ext = os.path.splitext(member.lower())[1]
                if ext not in SUPPORTED_EXTENSIONS:
                    continue

                # Extract filename (strip directory structure)
                filename = os.path.basename(member)
                if not filename:
                    continue

                target_key = f"{extract_prefix}{filename}"

                # Read and upload
                with zf.open(member) as f:
                    s3_client.put_object(
                        Bucket=bucket,
                        Key=target_key,
                        Body=f.read(),
                    )

    # Optionally delete the zip file
    try:
        s3_client.delete_object(Bucket=bucket, Key=zip_key)
        logger.info(f"Deleted zip file: {zip_key}")
    except Exception as e:
        logger.warning(f"Failed to delete zip: {e}")

    return extract_prefix


def _list_documents(s3_client, bucket, prefix):
    """List supported document files in S3."""
    keys = []
    paginator = s3_client.get_paginator("list_objects_v2")

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            ext = os.path.splitext(key.lower())[1]
            if ext in SUPPORTED_EXTENSIONS:
                keys.append(key)
                if len(keys) > MAX_DOCUMENTS:
                    raise ValueError(
                        f"Too many documents (>{MAX_DOCUMENTS}). "
                        "Use a more specific prefix."
                    )

    if not keys:
        raise ValueError(
            f"No supported documents found in s3://{bucket}/{prefix}. "
            f"Supported types: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )

    return keys
