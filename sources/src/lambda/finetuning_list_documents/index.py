"""
Lambda function to list documents in a Test Set for fine-tuning.

This function:
1. Lists all documents in the test set's input folder
2. Gets baselines for each document
3. Returns an array of document references for parallel processing

Called by Step Functions as the first step before Distributed Map.
"""

import json
import logging
import os
from typing import Any, Dict, List, Optional

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
TRACKING_TABLE_NAME = os.environ.get("TRACKING_TABLE", "")
TEST_SET_BUCKET = os.environ.get("TEST_SET_BUCKET", "")
FINETUNING_BUCKET = os.environ.get("FINETUNING_DATA_BUCKET", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize clients
dynamodb = boto3.resource("dynamodb", region_name=REGION)
s3_client = boto3.client("s3", region_name=REGION)

# DynamoDB key prefixes
FINETUNING_JOB_PREFIX = "finetuning#"


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for listing documents in a test set."""
    logger.info(f"Listing documents for testSetId={event.get('testSetId')}")

    job_id = event.get("jobId")
    test_set_id = event.get("testSetId")
    train_split = event.get("trainSplit", 0.9)

    if not job_id:
        raise ValueError("jobId is required")
    if not test_set_id:
        raise ValueError("testSetId is required")

    try:
        # Update job status to LISTING_DOCUMENTS
        _update_job_status(job_id, "LISTING_DOCUMENTS")

        # List all documents in the test set
        documents = _list_test_set_documents(test_set_id)
        logger.info(f"Found {len(documents)} documents in test set {test_set_id}")

        if not documents:
            raise ValueError(f"No documents found in test set {test_set_id}")

        # Get all unique classes from baselines
        all_classes = _get_all_classes(documents)
        logger.info(f"Found {len(all_classes)} unique classes: {all_classes}")

        # Update job status to GENERATING_DATA
        _update_job_status(job_id, "GENERATING_DATA")

        return {
            "jobId": job_id,
            "testSetId": test_set_id,
            "trainSplit": train_split,
            "documents": documents,
            "classes": all_classes,
            "totalDocuments": len(documents),
            "finetuningBucket": FINETUNING_BUCKET,
            "testSetBucket": TEST_SET_BUCKET,
        }

    except Exception as e:
        logger.error(f"Error listing documents: {str(e)}", exc_info=True)
        _update_job_status(job_id, "FAILED", str(e))
        raise


def _list_test_set_documents(test_set_id: str) -> List[Dict[str, Any]]:
    """List all documents in a test set with their baseline references.
    
    Test sets are stored in S3 with structure:
    - {test_set_id}/input/{filename} - input document files
    - {test_set_id}/baseline/{filename}/ - baseline folder for each document
    """
    bucket = TEST_SET_BUCKET
    if not bucket:
        raise ValueError("TEST_SET_BUCKET environment variable not set")
    
    documents = []
    
    # List all input files
    paginator = s3_client.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=bucket, Prefix=f"{test_set_id}/input/"):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if not key.endswith('/'):  # Skip directories
                filename = key.split('/')[-1]
                
                # Check if baseline exists
                baseline_key = _find_baseline_key(bucket, test_set_id, filename)
                if baseline_key:
                    documents.append({
                        'filename': filename,
                        'inputKey': key,
                        'inputUri': f"s3://{bucket}/{key}",
                        'baselineKey': baseline_key,
                        'baselineUri': f"s3://{bucket}/{baseline_key}",
                    })
                else:
                    logger.warning(f"No baseline found for {filename}, skipping")
    
    return documents


def _find_baseline_key(bucket: str, test_set_id: str, filename: str) -> Optional[str]:
    """Find the baseline JSON file for a document."""
    baseline_prefix = f"{test_set_id}/baseline/{filename}/"
    
    try:
        response = s3_client.list_objects_v2(
            Bucket=bucket,
            Prefix=baseline_prefix
        )
        
        for obj in response.get('Contents', []):
            key = obj['Key']
            if key.endswith('.json'):
                return key
    except Exception as e:
        logger.warning(f"Error finding baseline for {filename}: {e}")
    
    return None


def _get_all_classes(documents: List[Dict[str, Any]]) -> List[str]:
    """Extract all unique classes from document baselines."""
    classes = set()
    bucket = TEST_SET_BUCKET
    
    for doc in documents:
        baseline_key = doc.get("baselineKey")
        if not baseline_key:
            continue
            
        try:
            response = s3_client.get_object(Bucket=bucket, Key=baseline_key)
            baseline = json.loads(response['Body'].read().decode('utf-8'))
            
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
                
        except Exception as e:
            logger.warning(f"Error reading baseline {baseline_key}: {e}")
            continue
    
    # If no classes found, use a default
    if not classes:
        classes.add("document")
    
    return sorted(list(classes))


def _update_job_status(
    job_id: str, status: str, error_message: str = None
) -> None:
    """Update fine-tuning job status in DynamoDB."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    update_expression = "SET #status = :status"
    expression_values = {":status": status}
    expression_names = {"#status": "status"}

    if error_message:
        update_expression += ", errorMessage = :err, errorStep = :step"
        expression_values[":err"] = error_message
        expression_values[":step"] = "LISTING_DOCUMENTS"

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression=update_expression,
        ExpressionAttributeNames=expression_names,
        ExpressionAttributeValues=expression_values,
    )