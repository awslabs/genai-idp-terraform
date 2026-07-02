"""
Lambda function to create and check Custom Model Deployments.

This function:
1. Creates a Custom Model Deployment (on-demand endpoint) for a fine-tuned model
2. Checks the deployment status for Step Functions polling
3. Updates DynamoDB with deployment information
4. Adds the deployment ARN to the pricing configuration when deployment completes

Called by Step Functions as part of the fine-tuning workflow.
"""

import gzip
import json
import logging
import os
from datetime import datetime
from typing import Any, Dict, List, Optional

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
TRACKING_TABLE_NAME = os.environ.get("TRACKING_TABLE", "")
CONFIGURATION_TABLE_NAME = os.environ.get("CONFIGURATION_TABLE_NAME", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize clients
dynamodb = boto3.resource("dynamodb", region_name=REGION)
bedrock_client = boto3.client("bedrock", region_name=REGION)

# DynamoDB key prefixes
FINETUNING_JOB_PREFIX = "finetuning#"

# Deployment status mapping
DEPLOYMENT_STATUS_MAP = {
    "Creating": "DEPLOYING",
    "Active": "COMPLETED",
    "Failed": "FAILED",
    "Deleting": "DEPLOYING",
}


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for deployment operations."""
    logger.info(
        f"Processing deployment operation: jobId={event.get('jobId')}, "
        f"operation={event.get('operation', 'create')}"
    )

    operation = event.get("operation", "create")

    if operation == "create":
        return create_deployment(event)
    elif operation == "check":
        return check_deployment_status(event)
    else:
        raise ValueError(f"Unknown operation: {operation}")


def create_deployment(event: Dict[str, Any]) -> Dict[str, Any]:
    """Create a Custom Model Deployment for the fine-tuned model."""
    job_id = event.get("jobId")
    custom_model_arn = event.get("customModelArn")
    job_name = event.get("jobName", "")

    if not job_id:
        raise ValueError("jobId is required")
    if not custom_model_arn:
        raise ValueError("customModelArn is required")

    try:
        # Update job status to DEPLOYING
        _update_job_status(job_id, "DEPLOYING")

        # Create deployment name from job name
        deployment_name = f"{job_name}-deployment" if job_name else f"deployment-{job_id[:8]}"
        # Sanitize deployment name (alphanumeric and hyphens only)
        deployment_name = "".join(
            c if c.isalnum() or c == "-" else "-" for c in deployment_name
        )[:63]

        # Create the Custom Model Deployment
        logger.info(f"Creating deployment for model: {custom_model_arn}")
        response = bedrock_client.create_custom_model_deployment(
            modelArn=custom_model_arn,
            modelDeploymentName=deployment_name,
            description=f"Deployment for fine-tuning job {job_id}",
        )

        deployment_arn = response.get("customModelDeploymentArn", "")
        logger.info(f"Created deployment: {deployment_arn}")

        # Update DynamoDB with deployment ARN
        _update_job_deployment_arn(job_id, deployment_arn)

        return {
            "jobId": job_id,
            "customModelArn": custom_model_arn,
            "customModelDeploymentArn": deployment_arn,
            "deploymentName": deployment_name,
            "status": "Creating",
        }

    except Exception as e:
        logger.error(f"Error creating deployment: {str(e)}", exc_info=True)
        _update_job_failure(job_id, str(e), "DEPLOYING")
        raise


def check_deployment_status(event: Dict[str, Any]) -> Dict[str, Any]:
    """Check the status of a Custom Model Deployment."""
    job_id = event.get("jobId")
    deployment_arn = event.get("customModelDeploymentArn")

    if not job_id:
        raise ValueError("jobId is required")
    if not deployment_arn:
        raise ValueError("customModelDeploymentArn is required")

    try:
        # Get deployment status from Bedrock
        response = bedrock_client.get_custom_model_deployment(
            customModelDeploymentIdentifier=deployment_arn
        )

        deployment_status = response.get("status", "")
        logger.info(f"Deployment status: {deployment_status}")

        # Map deployment status to workflow status
        workflow_status = DEPLOYMENT_STATUS_MAP.get(deployment_status, "DEPLOYING")

        result = {
            "jobId": job_id,
            "customModelDeploymentArn": deployment_arn,
            "deploymentStatus": deployment_status,
            "workflowStatus": workflow_status,
            "isComplete": deployment_status == "Active",
            "isFailed": deployment_status == "Failed",
        }

        # If deployment is active, update job as completed and add to pricing
        if deployment_status == "Active":
            _update_job_completed(job_id)
            # Add deployment ARN to pricing configuration so it appears
            # in the "Amazon Bedrock Pricing" section of the pricing tab
            try:
                _add_deployment_arn_to_pricing(deployment_arn)
            except Exception as pricing_err:
                # Don't fail the deployment if pricing update fails
                logger.error(
                    f"Failed to add deployment ARN to pricing (non-fatal): {pricing_err}"
                )

        # If deployment failed, update job with error
        if deployment_status == "Failed":
            failure_message = response.get("failureMessage", "Deployment failed")
            result["errorMessage"] = failure_message
            _update_job_failure(job_id, failure_message, "DEPLOYING")

        logger.info(f"Returning result: {json.dumps(result)}")
        return result

    except Exception as e:
        logger.error(f"Error checking deployment status: {str(e)}", exc_info=True)
        raise


def _update_job_status(job_id: str, status: str) -> None:
    """Update fine-tuning job status in DynamoDB."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    update_expression = "SET #status = :status"
    expression_values = {":status": status}
    expression_names = {"#status": "status"}

    # Add deployment start timestamp
    if status == "DEPLOYING":
        update_expression += ", deploymentStartedAt = :ts"
        expression_values[":ts"] = datetime.utcnow().isoformat() + "Z"

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression=update_expression,
        ExpressionAttributeNames=expression_names,
        ExpressionAttributeValues=expression_values,
    )


def _update_job_deployment_arn(job_id: str, deployment_arn: str) -> None:
    """Update job with deployment ARN."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression="SET customModelDeploymentArn = :arn",
        ExpressionAttributeValues={":arn": deployment_arn},
    )

    logger.info(f"Updated job {job_id} with deployment ARN: {deployment_arn}")


def _update_job_completed(job_id: str) -> None:
    """Update job as completed."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression="SET #status = :status, deploymentCompletedAt = :ts",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "COMPLETED",
            ":ts": datetime.utcnow().isoformat() + "Z",
        },
    )

    logger.info(f"Job {job_id} completed successfully")


def _update_job_failure(job_id: str, error_message: str, error_step: str) -> None:
    """Update job with failure information."""
    table = dynamodb.Table(TRACKING_TABLE_NAME)

    table.update_item(
        Key={"PK": f"{FINETUNING_JOB_PREFIX}{job_id}", "SK": "metadata"},
        UpdateExpression="SET #status = :status, errorMessage = :err, errorStep = :step",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "FAILED",
            ":err": error_message,
            ":step": error_step,
        },
    )

    logger.info(f"Updated job {job_id} with failure: {error_message}")


# ===== Pricing Configuration Helpers =====

# Compressed storage markers (must match ConfigurationManager conventions)
_COMPRESSED_STORAGE_MARKER = "_config_storage"
_COMPRESSED_STORAGE_VALUE = "compressed"
_COMPRESSED_DATA_FIELD = "_compressed_config"
_DYNAMODB_METADATA_FIELDS = {
    "Configuration",
    "CreatedAt",
    "UpdatedAt",
    "IsActive",
    "Description",
    "BdaProjectArn",
    "BdaSyncStatus",
    "BdaLastSyncedAt",
    "Managed",
}


def _decompress_config_item(item: Dict[str, Any]) -> Dict[str, Any]:
    """Decompress a DynamoDB config item if it uses compressed storage format."""
    if item.get(_COMPRESSED_STORAGE_MARKER) != _COMPRESSED_STORAGE_VALUE:
        return item

    compressed_data = item.get(_COMPRESSED_DATA_FIELD)
    if compressed_data is None:
        logger.error("Compressed storage marker present but no compressed data found")
        return item

    raw_bytes = bytes(compressed_data) if not isinstance(compressed_data, bytes) else compressed_data

    try:
        decompressed_json = gzip.decompress(raw_bytes).decode("utf-8")
        config_data = json.loads(decompressed_json)
    except Exception as e:
        logger.error(f"Failed to decompress config data: {e}")
        return item

    full_item: Dict[str, Any] = {}
    for key, value in item.items():
        if key in _DYNAMODB_METADATA_FIELDS:
            full_item[key] = value
    full_item.update(config_data)
    return full_item


def _compress_config_item(item: Dict[str, Any]) -> Dict[str, Any]:
    """Compress a DynamoDB config item for storage."""
    metadata: Dict[str, Any] = {}
    config_data: Dict[str, Any] = {}
    for key, value in item.items():
        if key in _DYNAMODB_METADATA_FIELDS:
            metadata[key] = value
        else:
            config_data[key] = value

    config_json = json.dumps(config_data, default=str, separators=(",", ":"))
    compressed_bytes = gzip.compress(config_json.encode("utf-8"))

    return {
        **metadata,
        _COMPRESSED_DATA_FIELD: compressed_bytes,
        _COMPRESSED_STORAGE_MARKER: _COMPRESSED_STORAGE_VALUE,
    }


def _read_pricing_config(config_table: Any, config_key: str) -> Optional[Dict[str, Any]]:
    """Read and decompress a pricing config from the ConfigurationTable."""
    response = config_table.get_item(Key={"Configuration": config_key})
    item = response.get("Item")
    if item is None:
        return None
    return _decompress_config_item(item)


def _write_pricing_config(config_table: Any, item: Dict[str, Any]) -> None:
    """Compress and write a pricing config to the ConfigurationTable."""
    compressed_item = _compress_config_item(item)
    config_table.put_item(Item=compressed_item)


def _add_deployment_arn_to_pricing(deployment_arn: str) -> None:
    """Add a custom model deployment ARN to the pricing configuration.

    Adds a new entry under the 'bedrock/' prefix in both DefaultPricing and
    CustomPricing (if it exists) so the deployment ARN appears in the
    'Amazon Bedrock Pricing' section of the View / Edit Pricing tab.

    The entry is added with placeholder token pricing (inputTokens/outputTokens)
    set to "0.0" since custom model deployment pricing varies.

    Args:
        deployment_arn: The ARN of the custom model deployment
            (e.g., arn:aws:bedrock:us-east-1:123456789012:custom-model-deployment/abc123)
    """
    if not CONFIGURATION_TABLE_NAME:
        logger.warning(
            "CONFIGURATION_TABLE_NAME not set, skipping pricing update for deployment ARN"
        )
        return

    config_table = dynamodb.Table(CONFIGURATION_TABLE_NAME)
    pricing_name = f"bedrock/{deployment_arn}"

    new_pricing_entry = {
        "name": pricing_name,
        "units": [
            {"name": "inputTokens", "price": "0.0"},
            {"name": "outputTokens", "price": "0.0"},
        ],
    }

    # Update DefaultPricing
    try:
        _add_entry_to_pricing_config(config_table, "DefaultPricing", new_pricing_entry)
    except Exception as e:
        logger.error(f"Failed to add deployment ARN to DefaultPricing: {e}")

    # Update CustomPricing (if it exists)
    try:
        _add_entry_to_pricing_config(config_table, "CustomPricing", new_pricing_entry)
    except Exception as e:
        # CustomPricing may not exist if user hasn't customized pricing
        logger.info(f"CustomPricing update skipped or failed: {e}")


def _add_entry_to_pricing_config(
    config_table: Any, config_key: str, new_entry: Dict[str, Any]
) -> None:
    """Add a pricing entry to a specific pricing config (DefaultPricing or CustomPricing).

    If the entry already exists (by name), it is not duplicated.

    Args:
        config_table: DynamoDB Table resource for the ConfigurationTable
        config_key: The Configuration key (e.g., 'DefaultPricing' or 'CustomPricing')
        new_entry: The pricing entry dict with 'name' and 'units'
    """
    item = _read_pricing_config(config_table, config_key)
    if item is None:
        logger.info(f"{config_key} not found in ConfigurationTable, skipping")
        return

    pricing_list: List[Dict[str, Any]] = item.get("pricing", [])

    # Check if entry already exists
    existing_names = {entry.get("name") for entry in pricing_list if isinstance(entry, dict)}
    if new_entry["name"] in existing_names:
        logger.info(
            f"Deployment ARN already exists in {config_key} pricing, skipping: {new_entry['name']}"
        )
        return

    # Add the new entry
    pricing_list.append(new_entry)
    item["pricing"] = pricing_list

    # Write back
    _write_pricing_config(config_table, item)
    logger.info(f"Added deployment ARN to {config_key} pricing: {new_entry['name']}")
