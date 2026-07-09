"""
Lambda function to generate training data for fine-tuning from a Test Set.

This function:
1. Reads documents and baselines from a Test Set
2. Converts them to Bedrock JSONL format for multi-image classification
3. Splits into training and validation sets
4. Uploads to S3

Called by Step Functions as part of the fine-tuning workflow.
"""

import json
import logging
import os
import random
from typing import Any, Dict, List, Optional

import boto3
from idp_common.model_finetuning.training_data_utils import (
    format_baseline_for_training,
    get_document_images_from_uri,
    get_extraction_fields,
)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
TRACKING_TABLE_NAME = os.environ.get("TRACKING_TABLE", "")
FINETUNING_BUCKET = os.environ.get("FINETUNING_DATA_BUCKET", "")
TEST_SET_BUCKET = os.environ.get("TEST_SET_BUCKET", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize clients
dynamodb = boto3.resource("dynamodb", region_name=REGION)
s3_client = boto3.client("s3", region_name=REGION)

# DynamoDB key prefixes
FINETUNING_JOB_PREFIX = "finetuning#"


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for generating training data."""
    job_id = event.get("jobId")
    test_set_id = event.get("testSetId")
    train_split = event.get("trainSplit", 0.9)

    logger.info(
        f"Processing finetuning data generation: jobId={job_id}, "
        f"testSetId={test_set_id}, trainSplit={train_split}"
    )

    if not job_id:
        raise ValueError("jobId is required")
    if not test_set_id:
        raise ValueError("testSetId is required")

    # Validate trainSplit bounds
    if (
        not isinstance(train_split, (int, float))
        or train_split <= 0
        or train_split >= 1
    ):
        raise ValueError(
            f"trainSplit must be a number between 0 and 1 (exclusive), got: {train_split}"
        )

    try:
        # Update job status to GENERATING_DATA
        _update_job_status(job_id, "GENERATING_DATA")

        # Get test set documents and baselines
        documents = _get_test_set_documents(test_set_id)
        logger.info(f"Found {len(documents)} documents in test set {test_set_id}")

        if not documents:
            raise ValueError(f"No documents found in test set {test_set_id}")

        # Get all unique classes from baselines
        all_classes = _get_all_classes(documents)
        logger.info(f"Found {len(all_classes)} unique classes: {all_classes}")

        # Convert documents to training examples
        training_examples = _convert_to_training_examples(documents, all_classes)
        logger.info(f"Generated {len(training_examples)} training examples")

        # Shuffle and split into train/validation
        random.seed(42)  # For reproducibility
        random.shuffle(training_examples)

        split_idx = int(len(training_examples) * train_split)
        train_examples = training_examples[:split_idx]
        validation_examples = training_examples[split_idx:]

        logger.info(
            f"Split into {len(train_examples)} training and {len(validation_examples)} validation examples"
        )

        # Upload to S3
        training_data_uri = _upload_jsonl(train_examples, job_id, "train.jsonl")
        validation_data_uri = _upload_jsonl(
            validation_examples, job_id, "validation.jsonl"
        )

        # Update job with data URIs
        _update_job_data_uris(job_id, training_data_uri, validation_data_uri)

        return {
            "jobId": job_id,
            "trainingDataUri": training_data_uri,
            "validationDataUri": validation_data_uri,
            "trainCount": len(train_examples),
            "validationCount": len(validation_examples),
            "classes": all_classes,
        }

    except Exception as e:
        logger.error(f"Error generating training data: {str(e)}", exc_info=True)
        try:
            _update_job_status(job_id, "FAILED", str(e))
        except Exception as status_err:
            logger.error(
                f"Failed to update job status to FAILED: {status_err}",
                exc_info=True,
            )
        raise


def _get_test_set_documents(test_set_id: str) -> List[Dict[str, Any]]:
    """Get all documents from a test set with their baselines from S3.

    Test sets are stored in S3 with structure:
    - {test_set_id}/input/{filename} - input document files
    - {test_set_id}/baseline/{filename}/ - baseline folder for each document
    """
    bucket = TEST_SET_BUCKET
    if not bucket:
        raise ValueError("TEST_SET_BUCKET environment variable not set")

    documents = []

    # List all input files
    input_files = []
    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=f"{test_set_id}/input/"):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if not key.endswith("/"):  # Skip directories
                filename = key.split("/")[-1]
                input_files.append(
                    {
                        "filename": filename,
                        "input_key": key,
                        "input_uri": f"s3://{bucket}/{key}",
                    }
                )

    logger.info(f"Found {len(input_files)} input files in test set {test_set_id}")

    # For each input file, get its baseline
    for input_file in input_files:
        filename = input_file["filename"]
        baseline_prefix = f"{test_set_id}/baseline/{filename}/"

        # Get baseline JSON file using pagination to handle >1000 objects
        baseline_data = None
        try:
            baseline_paginator = s3_client.get_paginator("list_objects_v2")
            for baseline_page in baseline_paginator.paginate(
                Bucket=bucket, Prefix=baseline_prefix
            ):
                for obj in baseline_page.get("Contents", []):
                    key = obj["Key"]
                    if key.endswith(".json"):
                        # Read the baseline JSON
                        response = s3_client.get_object(Bucket=bucket, Key=key)
                        baseline_data = json.loads(
                            response["Body"].read().decode("utf-8")
                        )
                        break
                if baseline_data:
                    break
        except Exception as e:
            logger.warning(f"Failed to get baseline for {filename}: {e}")
            continue

        if baseline_data:
            doc = {
                "filename": filename,
                "input_uri": input_file["input_uri"],
                "baseline": baseline_data,
            }
            documents.append(doc)

    return documents


def _get_all_classes(documents: List[Dict[str, Any]]) -> List[str]:
    """Extract all unique classes from document baselines."""
    classes = set()
    for doc in documents:
        baseline = doc.get("baseline", {})
        # Try different baseline formats
        # Format 1: baseline has 'Sections' with 'DocumentClass'
        sections = baseline.get("Sections", [])
        for section in sections:
            doc_class = section.get("DocumentClass")
            if doc_class:
                classes.add(doc_class)
        # Format 2: baseline has 'documentClass' at top level
        doc_class = baseline.get("documentClass") or baseline.get("DocumentClass")
        if doc_class:
            classes.add(doc_class)

    # If no classes found, use a default
    if not classes:
        classes.add("document")

    return sorted(list(classes))


def _convert_to_training_examples(
    documents: List[Dict[str, Any]], all_classes: List[str]
) -> List[Dict[str, Any]]:
    """Convert test set documents to Bedrock training format."""
    examples = []

    for doc in documents:
        try:
            example = _create_training_example(doc, all_classes)
            if example:
                examples.append(example)
        except Exception as e:
            logger.warning(f"Failed to convert document {doc.get('filename')}: {e}")
            continue

    return examples


def _create_training_example(
    doc: Dict[str, Any], all_classes: List[str]
) -> Optional[Dict[str, Any]]:
    """Create a single training example from a document.

    For extraction fine-tuning, we create examples that teach the model
    to extract structured data from documents.

    Supports both image files and PDFs (PDFs are converted to images).
    """
    input_uri = doc.get("input_uri")
    baseline = doc.get("baseline", {})
    filename = doc.get("filename", "")

    if not input_uri or not baseline:
        return None

    # Build the conversation format for Bedrock fine-tuning
    # Create user message with document image(s)
    user_content = []

    # Add instruction text based on what's in the baseline
    extraction_fields = get_extraction_fields(baseline)
    if extraction_fields:
        fields_str = ", ".join(extraction_fields[:20])  # Limit to 20 fields
        user_content.append(
            {
                "text": f"Extract the following information from this document: {fields_str}. Return the results as a JSON object."
            }
        )
    else:
        user_content.append(
            {
                "text": "Extract all relevant information from this document. Return the results as a JSON object."
            }
        )

    # Add document image(s) - supports PDFs by converting to images
    try:
        images = get_document_images_from_uri(s3_client, input_uri)
        if not images:
            logger.warning(f"No images extracted from document: {filename}")
            return None

        # Add each image/page to the user content
        for image_data, image_format in images:
            user_content.append(
                {"image": {"format": image_format, "source": {"bytes": image_data}}}
            )

        logger.info(f"Added {len(images)} image(s) from document: {filename}")

    except Exception as e:
        logger.warning(f"Failed to load document {input_uri}: {e}")
        return None

    if len(user_content) < 2:  # Need at least text + 1 image
        return None

    # Build expected response from baseline extraction results
    extraction_result = format_baseline_for_training(baseline)
    assistant_response = json.dumps(extraction_result, indent=2)

    # Create the training example in Bedrock conversation format
    example = {
        "schemaVersion": "bedrock-conversation-2024",
        "system": [
            {
                "text": "You are a document extraction expert. Analyze the provided document and extract the requested information accurately. Return your results as a well-structured JSON object."
            }
        ],
        "messages": [
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": [{"text": assistant_response}]},
        ],
    }

    return example


def _upload_jsonl(examples: List[Dict[str, Any]], job_id: str, filename: str) -> str:
    """Upload training examples as JSONL to S3."""
    # Convert to JSONL format
    jsonl_content = "\n".join(json.dumps(ex) for ex in examples)

    # Upload to S3
    key = f"finetuning/{job_id}/{filename}"
    s3_client.put_object(
        Bucket=FINETUNING_BUCKET,
        Key=key,
        Body=jsonl_content.encode("utf-8"),
        ContentType="application/jsonl",
    )

    s3_uri = f"s3://{FINETUNING_BUCKET}/{key}"
    logger.info(f"Uploaded {len(examples)} examples to {s3_uri}")

    return s3_uri


def _update_job_status(job_id: str, status: str, error_message: str = None) -> None:
    """Update fine-tuning job status in DynamoDB."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    update_expression = "SET #status = :status"
    expression_values = {":status": status}
    expression_names = {"#status": "status"}

    if error_message:
        update_expression += ", errorMessage = :err, errorStep = :step"
        expression_values[":err"] = error_message
        expression_values[":step"] = "GENERATING_DATA"

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression=update_expression,
        ExpressionAttributeNames=expression_names,
        ExpressionAttributeValues=expression_values,
    )


def _update_job_data_uris(
    job_id: str, training_data_uri: str, validation_data_uri: str
) -> None:
    """Update job with training data URIs."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression="SET trainingDataUri = :train, validationDataUri = :val",
        ExpressionAttributeValues={
            ":train": training_data_uri,
            ":val": validation_data_uri,
        },
    )
