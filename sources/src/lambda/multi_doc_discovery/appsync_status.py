# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Shared utility for updating discovery job status via AppSync.

Calls the updateDiscoveryJobStatus GraphQL mutation using IAM auth,
which triggers the onDiscoveryJobStatusChange subscription for real-time
UI updates. Uses only stdlib + botocore (no extra dependencies needed).
"""

import json
import logging
import os
from urllib.request import Request, urlopen
from urllib.error import URLError

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

logger = logging.getLogger(__name__)

APPSYNC_API_URL = os.environ.get("APPSYNC_API_URL", "")

# GraphQL mutation with all multi-doc discovery fields
_MUTATION = """
mutation UpdateDiscoveryJobStatus(
    $jobId: ID!,
    $status: String!,
    $errorMessage: String,
    $statusMessage: String,
    $jobType: String,
    $currentStep: String,
    $totalDocuments: Int,
    $clustersFound: Int,
    $discoveredClasses: String,
    $reflectionReport: String
) {
    updateDiscoveryJobStatus(
        jobId: $jobId,
        status: $status,
        errorMessage: $errorMessage,
        statusMessage: $statusMessage,
        jobType: $jobType,
        currentStep: $currentStep,
        totalDocuments: $totalDocuments,
        clustersFound: $clustersFound,
        discoveredClasses: $discoveredClasses,
        reflectionReport: $reflectionReport
    ) {
        jobId
        status
        errorMessage
        statusMessage
        jobType
        currentStep
        totalDocuments
        clustersFound
        discoveredClasses
        reflectionReport
    }
}
"""


def update_status(
    job_id: str,
    status: str,
    *,
    current_step: str | None = None,
    total_documents: int | None = None,
    clusters_found: int | None = None,
    discovered_classes: str | None = None,
    reflection_report: str | None = None,
    error_message: str | None = None,
    status_message: str | None = None,
) -> bool:
    """
    Update discovery job status via AppSync GraphQL mutation.

    This triggers the onDiscoveryJobStatusChange subscription so the UI
    receives real-time updates without polling.

    Args:
        job_id: The discovery job ID.
        status: New status (PREPARING, EMBEDDING, CLUSTERING, ANALYZING, COMPLETED, FAILED).
        current_step: Human-readable description of current step.
        total_documents: Total number of documents being processed.
        clusters_found: Number of clusters discovered.
        discovered_classes: JSON string of discovered classes.
        reflection_report: Markdown reflection report.
        error_message: Error message if status is FAILED.
        status_message: Additional status message.

    Returns:
        True if the update succeeded, False otherwise.
    """
    if not APPSYNC_API_URL:
        logger.warning("APPSYNC_API_URL not configured, skipping AppSync status update")
        return False

    variables: dict = {
        "jobId": job_id,
        "status": status,
        "jobType": "multi-document",
    }

    if current_step is not None:
        variables["currentStep"] = current_step
    if total_documents is not None:
        variables["totalDocuments"] = total_documents
    if clusters_found is not None:
        variables["clustersFound"] = clusters_found
    if discovered_classes is not None:
        variables["discoveredClasses"] = discovered_classes
    if reflection_report is not None:
        variables["reflectionReport"] = reflection_report
    if error_message is not None:
        variables["errorMessage"] = error_message
    if status_message is not None:
        variables["statusMessage"] = status_message

    payload = json.dumps({"query": _MUTATION, "variables": variables})

    try:
        # Create and sign the request with SigV4
        session = boto3.Session()
        credentials = session.get_credentials().get_frozen_credentials()
        region = session.region_name or os.environ.get("AWS_REGION", "us-east-1")

        request = AWSRequest(
            method="POST",
            url=APPSYNC_API_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        SigV4Auth(credentials, "appsync", region).add_auth(request)

        # Send the request using urllib (no extra dependencies)
        urllib_request = Request(
            APPSYNC_API_URL,
            data=payload.encode("utf-8"),
            headers=dict(request.headers),
            method="POST",
        )

        with urlopen(urllib_request, timeout=30) as response:  # noqa: S310
            response_body = json.loads(response.read().decode("utf-8"))

        if "errors" in response_body:
            logger.error(
                f"GraphQL errors updating job {job_id}: "
                f"{json.dumps(response_body['errors'])}"
            )
            return False

        logger.info(f"AppSync status update: job={job_id}, status={status}")
        return True

    except URLError as e:
        logger.error(f"Failed to call AppSync for job {job_id}: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error updating AppSync for job {job_id}: {e}")
        return False
