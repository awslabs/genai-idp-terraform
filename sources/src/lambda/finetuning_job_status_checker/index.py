"""
Lambda function to check the status of a Bedrock fine-tuning job.

This function:
1. Polls Bedrock GetModelCustomizationJob API
2. Returns the current status for Step Functions to decide next action
3. Updates DynamoDB with training metrics when available

Called by Step Functions as part of the fine-tuning workflow polling loop.
"""

import json
import logging
import os
from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, Optional, Union

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
TRACKING_TABLE_NAME = os.environ.get("TRACKING_TABLE", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize clients
dynamodb = boto3.resource("dynamodb", region_name=REGION)
bedrock_client = boto3.client("bedrock", region_name=REGION)

# DynamoDB key prefixes
FINETUNING_JOB_PREFIX = "finetuning#"

# Bedrock job status mapping
BEDROCK_STATUS_MAP = {
    "InProgress": "TRAINING",
    "Completed": "TRAINING_COMPLETE",
    "Failed": "FAILED",
    "Stopping": "TRAINING",
    "Stopped": "FAILED",
}


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for checking fine-tuning job status."""
    logger.info(f"Checking finetuning job status: jobId={event.get('jobId')}")

    job_id = event.get("jobId")
    bedrock_job_arn = event.get("bedrockJobArn")

    if not job_id:
        raise ValueError("jobId is required")
    if not bedrock_job_arn:
        raise ValueError("bedrockJobArn is required")

    try:
        # Get job status from Bedrock
        response = bedrock_client.get_model_customization_job(
            jobIdentifier=bedrock_job_arn
        )

        bedrock_status = response.get("status", "")
        logger.info(f"Bedrock job status: {bedrock_status}")

        # Map Bedrock status to our workflow status
        workflow_status = BEDROCK_STATUS_MAP.get(bedrock_status, "TRAINING")

        # Extract relevant information
        result = {
            "jobId": job_id,
            "bedrockJobArn": bedrock_job_arn,
            "bedrockStatus": bedrock_status,
            "workflowStatus": workflow_status,
            "isComplete": bedrock_status == "Completed",
            "isFailed": bedrock_status in ["Failed", "Stopped"],
        }

        # If completed, get the output model ARN
        if bedrock_status == "Completed":
            output_model_arn = response.get("outputModelArn", "")
            result["customModelArn"] = output_model_arn

            # Update DynamoDB with model ARN and training metrics
            _update_job_completion(job_id, output_model_arn, response)

        # If failed, get the failure reason
        if bedrock_status in ["Failed", "Stopped"]:
            failure_message = response.get("failureMessage", "Unknown error")
            result["errorMessage"] = failure_message

            # Update DynamoDB with failure
            _update_job_failure(job_id, failure_message)

        # Update training metrics if available
        training_metrics = _extract_training_metrics(response)
        if training_metrics:
            # Convert Decimal to float for JSON serialization in Step Functions response
            result["trainingMetrics"] = {
                k: float(v) for k, v in training_metrics.items()
            }
            _update_training_metrics(job_id, training_metrics)

        logger.info(f"Returning result: {json.dumps(result)}")
        return result

    except Exception as e:
        logger.error(f"Error checking job status: {str(e)}", exc_info=True)
        raise


def _extract_training_metrics(
    response: Dict[str, Any]
) -> Optional[Dict[str, Union[Decimal, float]]]:
    """Extract training metrics from Bedrock response.

    Returns Decimal types for DynamoDB compatibility.
    """
    metrics: Dict[str, Union[Decimal, float]] = {}

    # Check for training metrics in the response
    training_metrics = response.get("trainingMetrics", {})
    if training_metrics:
        if "trainingLoss" in training_metrics:
            # Use Decimal for DynamoDB compatibility
            metrics["trainingLoss"] = Decimal(str(training_metrics["trainingLoss"]))

    # Check for validation metrics
    validation_metrics = response.get("validationMetrics", {})
    if validation_metrics:
        if "validationLoss" in validation_metrics:
            # Use Decimal for DynamoDB compatibility
            metrics["validationLoss"] = Decimal(str(validation_metrics["validationLoss"]))

    return metrics if metrics else None


def _update_job_completion(
    job_id: str, custom_model_arn: str, response: Dict[str, Any]
) -> None:
    """Update job with completion information."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    update_expression = "SET customModelArn = :arn, trainingCompletedAt = :ts"
    expression_values = {
        ":arn": custom_model_arn,
        ":ts": datetime.utcnow().isoformat() + "Z",
    }

    # Add training metrics if available
    training_metrics = _extract_training_metrics(response)
    if training_metrics:
        update_expression += ", trainingMetrics = :metrics"
        expression_values[":metrics"] = training_metrics

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_values,
    )

    logger.info(f"Updated job {job_id} with custom model ARN: {custom_model_arn}")


def _update_job_failure(job_id: str, error_message: str) -> None:
    """Update job with failure information."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression="SET #status = :status, errorMessage = :err, errorStep = :step",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "FAILED",
            ":err": error_message,
            ":step": "TRAINING",
        },
    )

    logger.info(f"Updated job {job_id} with failure: {error_message}")


def _update_training_metrics(
    job_id: str, metrics: Dict[str, Union[Decimal, float]]
) -> None:
    """Update job with training metrics."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression="SET trainingMetrics = :metrics",
        ExpressionAttributeValues={":metrics": metrics},
    )

    logger.info(f"Updated job {job_id} with training metrics: {metrics}")