# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
SageMaker-backed classification handler for the SageMaker-UDOP processor.

Mirrors the vendored unified classification handler
(sources/patterns/unified/src/classification_function/index.py) but constructs
the ClassificationService with backend="sagemaker". The native SageMaker path in
idp_common (classify_page_sagemaker) calls the endpoint directly with the
{input_image, input_textract} schema the UDOP model expects, reading the
endpoint name from the SAGEMAKER_ENDPOINT_NAME environment variable.
"""

import json
import logging
import os
import time

from idp_common import classification, metrics, get_config
from idp_common.models import Document, Status
from idp_common.docs_service import create_document_service
from idp_common.utils import calculate_lambda_metering, merge_metering_data
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

region = os.environ["AWS_REGION"]
MAX_WORKERS = int(os.environ.get("MAX_WORKERS", 20))

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


@xray_recorder.capture("classification_function")
def handler(event, context):
    """Lambda handler for SageMaker-backed document classification."""
    start_time = time.time()
    logger.info(f"Event: {json.dumps(event)}")

    working_bucket = os.environ.get("WORKING_BUCKET")
    document = Document.load_document(
        event["OCRResult"]["document"], working_bucket, logger
    )

    config_version = getattr(document, "config_version", None)
    config = get_config(as_model=True, version=config_version)

    logger.info(f"Loaded document - ID: {document.id}, input_key: {document.input_key}")
    logger.info(f"Document status: {document.status}, num_pages: {document.num_pages}")

    xray_recorder.put_annotation("document_id", {document.id})
    xray_recorder.put_annotation("processing_stage", "classification")

    # Skip if every page is already classified.
    pages_with_classification = sum(
        1
        for page in document.pages.values()
        if page.classification and page.classification.strip()
    )
    if pages_with_classification == len(document.pages) and len(document.pages) > 0:
        logger.info(
            f"Skipping classification for document {document.id} - all pages classified"
        )
        document.workflow_execution_arn = event.get("execution_arn")
        document_service = create_document_service()
        document_service.update_document(document)
        try:
            lambda_metering = calculate_lambda_metering(
                "Classification", context, start_time
            )
            document.metering = merge_metering_data(document.metering, lambda_metering)
        except Exception as e:
            logger.warning(f"Failed to add Lambda metering for classification skip: {e}")
        return {
            "document": document.serialize_document(
                working_bucket, "classification_skip", logger
            )
        }

    document.status = Status.CLASSIFYING
    document.workflow_execution_arn = event.get("execution_arn")
    document_service = create_document_service()
    document_service.update_document(document)

    if not document.pages:
        error_message = "Document has no pages to classify"
        logger.error(error_message)
        document.status = Status.FAILED
        document.errors.append(error_message)

    t0 = time.time()
    metrics.put_metric("BedrockRequestsTotal", len(document.pages))

    cache_table = os.environ.get("TRACKING_TABLE")
    service = classification.ClassificationService(
        region=region,
        max_workers=MAX_WORKERS,
        config=config,
        cache_table=cache_table,
        backend="sagemaker",
    )

    document = service.classify_document(document)

    failed_page_exceptions = None
    primary_exception = None
    if document.metadata and "failed_page_exceptions" in document.metadata:
        failed_page_exceptions = document.metadata["failed_page_exceptions"]
        primary_exception = document.metadata.get("primary_exception")
        logger.error(
            f"Document {document.id} has {len(failed_page_exceptions)} pages that failed to classify"
        )

    if document.status == Status.FAILED or failed_page_exceptions:
        error_message = f"Classification failed for document {document.id}"
        if failed_page_exceptions:
            error_message += f" - {len(failed_page_exceptions)} pages failed to classify"
        logger.error(error_message)
        document_service.update_document(document)
        if primary_exception:
            raise primary_exception
        raise Exception(error_message)

    logger.info(f"Time taken for classification: {time.time() - t0:.2f} seconds")

    try:
        lambda_metering = calculate_lambda_metering("Classification", context, start_time)
        document.metering = merge_metering_data(document.metering, lambda_metering)
    except Exception as e:
        logger.warning(f"Failed to add Lambda metering for classification: {e}")

    document_service.update_document(document)

    return {
        "document": document.serialize_document(working_bucket, "classification", logger)
    }
