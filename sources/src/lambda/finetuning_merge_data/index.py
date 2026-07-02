"""
Lambda function to merge individual training examples into final JSONL files.

This function:
1. Reads map results from S3 (written by Distributed Map ResultWriter)
2. Lists all individual JSONL files from parallel processing
3. Shuffles and splits into training and validation sets
4. Combines into train.jsonl and validation.jsonl
5. Updates job status with data URIs

Called by Step Functions after the Distributed Map completes.
"""

import json
import logging
import os
import random
from typing import Any, Dict, List, Optional

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
TRACKING_TABLE_NAME = os.environ.get("TRACKING_TABLE", "")
FINETUNING_BUCKET = os.environ.get("FINETUNING_DATA_BUCKET", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize clients
dynamodb = boto3.resource("dynamodb", region_name=REGION)
s3_client = boto3.client("s3", region_name=REGION)

# DynamoDB key prefixes
FINETUNING_JOB_PREFIX = "finetuning#"


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for merging training data."""
    logger.info(f"Merging finetuning data: jobId={event.get('jobId')}")

    job_id = event.get("jobId")
    train_split = event.get("trainSplit", 0.9)
    classes = event.get("classes", [])
    
    # For Distributed Map with ResultWriter, results are written to S3
    # The event contains the bucket and prefix where results are stored
    map_results_bucket = event.get("mapResultsBucket")
    map_results_prefix = event.get("mapResultsPrefix")
    
    # Legacy support: also check for inline mapResults
    map_results = event.get("mapResults", [])

    if not job_id:
        raise ValueError("jobId is required")

    try:
        # Update job status
        _update_job_status(job_id, "MERGING_DATA")

        # Collect all successful example URIs
        example_keys = []
        failed_count = 0
        
        # If using Distributed Map with ResultWriter, read results from S3
        if map_results_bucket and map_results_prefix:
            # The ResultWriterDetails.Key may be the manifest.json path, not the directory
            # Extract the directory prefix from the path
            actual_prefix = map_results_prefix
            if actual_prefix.endswith('/manifest.json'):
                actual_prefix = actual_prefix[:-len('/manifest.json')] + '/'
            elif actual_prefix.endswith('manifest.json'):
                actual_prefix = actual_prefix[:-len('manifest.json')]
            
            logger.info(f"Reading map results from S3: s3://{map_results_bucket}/{actual_prefix}")
            map_results = _read_map_results_from_s3(map_results_bucket, actual_prefix)
        
        for result in map_results:
            if result.get("success"):
                output_key = result.get("outputKey")
                if output_key:
                    example_keys.append(output_key)
            else:
                failed_count += 1
                logger.warning(f"Failed document: {result.get('filename')} - {result.get('reason')}")

        logger.info(f"Collected {len(example_keys)} successful examples, {failed_count} failed")

        if not example_keys:
            raise ValueError("No training examples were generated successfully")

        # Load all examples from S3
        examples = []
        for key in example_keys:
            try:
                response = s3_client.get_object(Bucket=FINETUNING_BUCKET, Key=key)
                example = json.loads(response['Body'].read().decode('utf-8'))
                examples.append(example)
            except Exception as e:
                logger.warning(f"Failed to load example {key}: {e}")
                continue

        logger.info(f"Loaded {len(examples)} training examples")

        if not examples:
            raise ValueError("Failed to load any training examples")

        # Shuffle and split into train/validation
        random.seed(42)  # For reproducibility
        random.shuffle(examples)

        split_idx = int(len(examples) * train_split)
        train_examples = examples[:split_idx]
        validation_examples = examples[split_idx:]

        # Ensure we have at least 1 validation example
        if not validation_examples and len(train_examples) > 1:
            validation_examples = [train_examples.pop()]

        logger.info(
            f"Split into {len(train_examples)} training and {len(validation_examples)} validation examples"
        )

        # Upload combined JSONL files
        training_data_uri = _upload_jsonl(train_examples, job_id, "train.jsonl")
        validation_data_uri = _upload_jsonl(validation_examples, job_id, "validation.jsonl")

        # Clean up individual example files (optional, can be done async)
        _cleanup_example_files(job_id)
        
        # Clean up map results from S3 if they exist
        if map_results_bucket and map_results_prefix:
            _cleanup_map_results(map_results_bucket, map_results_prefix)

        # Update job with data URIs
        _update_job_data_uris(job_id, training_data_uri, validation_data_uri)

        return {
            "jobId": job_id,
            "trainingDataUri": training_data_uri,
            "validationDataUri": validation_data_uri,
            "trainCount": len(train_examples),
            "validationCount": len(validation_examples),
            "failedCount": failed_count,
            "classes": classes,
        }

    except Exception as e:
        logger.error(f"Error merging training data: {str(e)}", exc_info=True)
        _update_job_status(job_id, "FAILED", str(e))
        raise


def _read_map_results_from_s3(bucket: str, prefix: str) -> List[Dict[str, Any]]:
    """
    Read map results from S3 written by Distributed Map ResultWriter.
    
    The ResultWriter writes results as JSON files in the specified prefix.
    Each file contains an array of results from child executions.
    
    The format is:
    [
        {
            "Output": "{\"success\": true, ...}",  // JSON string of Lambda output
            "OutputDetails": {...}
        },
        ...
    ]
    """
    results = []
    
    try:
        # List all files in the prefix to understand the structure
        logger.info(f"Listing S3 objects in bucket={bucket}, prefix={prefix}")
        
        paginator = s3_client.get_paginator('list_objects_v2')
        all_keys = []
        
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get('Contents', []):
                all_keys.append(obj['Key'])
        
        logger.info(f"Found {len(all_keys)} objects in S3 prefix: {all_keys[:20]}")  # Log first 20 keys
        
        for key in all_keys:
            # Skip manifest files, only process result files
            # ResultWriter creates files like: SUCCEEDED_0.json, FAILED_0.json
            if key.endswith('.json') and 'manifest' not in key.lower():
                try:
                    logger.info(f"Reading result file: {key}")
                    response = s3_client.get_object(Bucket=bucket, Key=key)
                    content = response['Body'].read().decode('utf-8')
                    
                    # Log first 500 chars of content for debugging
                    logger.info(f"File content preview ({key}): {content[:500]}...")
                    
                    data = json.loads(content)
                    
                    # ResultWriter writes results as an array of execution results
                    # Each item has an "Output" field with the JSON-stringified Lambda output
                    if isinstance(data, list):
                        logger.info(f"File contains array with {len(data)} items")
                        for idx, item in enumerate(data):
                            parsed_output = _parse_result_item(item)
                            if parsed_output:
                                results.append(parsed_output)
                                logger.info(f"Parsed item {idx}: success={parsed_output.get('success')}")
                            else:
                                logger.warning(f"Failed to parse item {idx}: {str(item)[:200]}")
                    elif isinstance(data, dict):
                        logger.info(f"File contains single object with keys: {list(data.keys())}")
                        # Single result object
                        parsed_output = _parse_result_item(data)
                        if parsed_output:
                            results.append(parsed_output)
                        else:
                            logger.warning(f"Failed to parse single object: {str(data)[:200]}")
                            
                except Exception as e:
                    logger.warning(f"Failed to read result file {key}: {e}", exc_info=True)
                    continue
        
        logger.info(f"Read {len(results)} results from S3 prefix: {prefix}")
        
    except Exception as e:
        logger.error(f"Error reading map results from S3: {e}", exc_info=True)
        raise
    
    return results


def _parse_result_item(item: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Parse a single result item from the Distributed Map ResultWriter output.
    
    The item format from ResultWriter is:
    {
        "Output": "{\"success\": true, \"filename\": \"...\", ...}",  // JSON string
        "OutputDetails": {...}
    }
    
    Or it could be the direct Lambda output if passed inline.
    """
    if not isinstance(item, dict):
        return None
    
    # Check if this is a ResultWriter format with "Output" field
    if 'Output' in item:
        output = item['Output']
        # Output is typically a JSON string that needs to be parsed
        if isinstance(output, str):
            try:
                return json.loads(output)
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse Output JSON: {e}")
                return None
        elif isinstance(output, dict):
            return output
        else:
            return None
    
    # Check if this is already the Lambda output format (has success/filename keys)
    if 'success' in item or 'filename' in item or 'outputKey' in item:
        return item
    
    # Unknown format, skip
    logger.warning(f"Unknown result item format: {list(item.keys())}")
    return None


def _cleanup_map_results(bucket: str, prefix: str) -> None:
    """Clean up map result files from S3 after processing."""
    try:
        paginator = s3_client.get_paginator('list_objects_v2')
        
        objects_to_delete = []
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get('Contents', []):
                objects_to_delete.append({'Key': obj['Key']})
        
        # Delete in batches of 1000 (S3 limit)
        for i in range(0, len(objects_to_delete), 1000):
            batch = objects_to_delete[i:i+1000]
            if batch:
                s3_client.delete_objects(
                    Bucket=bucket,
                    Delete={'Objects': batch}
                )
        
        logger.info(f"Cleaned up {len(objects_to_delete)} map result files")
        
    except Exception as e:
        # Don't fail the job if cleanup fails
        logger.warning(f"Failed to cleanup map result files: {e}")


def _upload_jsonl(
    examples: List[Dict[str, Any]], job_id: str, filename: str
) -> str:
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


def _cleanup_example_files(job_id: str) -> None:
    """Clean up individual example files after merging."""
    try:
        prefix = f"finetuning/{job_id}/examples/"
        paginator = s3_client.get_paginator('list_objects_v2')
        
        objects_to_delete = []
        for page in paginator.paginate(Bucket=FINETUNING_BUCKET, Prefix=prefix):
            for obj in page.get('Contents', []):
                objects_to_delete.append({'Key': obj['Key']})
        
        # Delete in batches of 1000 (S3 limit)
        for i in range(0, len(objects_to_delete), 1000):
            batch = objects_to_delete[i:i+1000]
            if batch:
                s3_client.delete_objects(
                    Bucket=FINETUNING_BUCKET,
                    Delete={'Objects': batch}
                )
        
        logger.info(f"Cleaned up {len(objects_to_delete)} individual example files")
        
    except Exception as e:
        # Don't fail the job if cleanup fails
        logger.warning(f"Failed to cleanup example files: {e}")


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
        expression_values[":step"] = "MERGING_DATA"

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