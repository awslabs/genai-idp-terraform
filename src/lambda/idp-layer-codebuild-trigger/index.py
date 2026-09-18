#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Lambda function to trigger CodeBuild for IDP common layer creation.

This function replaces the null_resource approach with a proper AWS Lambda function
following AWS-IA patterns. It handles:
- CodeBuild project triggering
- Build status monitoring
- Error handling and logging
- Multiple layer creation per CodeBuild project
"""

import json
import os
import time
import boto3
from botocore.exceptions import ClientError
from typing import Dict, Any, List
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# On a first apply the CodeBuild project, its service role, and this function's
# role are all seconds old, so StartBuild can fail on IAM that has not finished
# propagating. Retrying costs a few seconds; not retrying fails the whole layer
# and, because the invocation result is recorded in state, blocks every later
# apply until a trigger changes.
_RETRYABLE_START_BUILD_ERRORS = frozenset(
    {
        "AccessDeniedException",
        "InvalidInputException",
        "ThrottlingException",
        "TooManyRequestsException",
    }
)

def start_build_with_retry(
    codebuild: Any,
    project_name: str,
    idp_common_extras: List[str],
    requirements_hash: str,
    force_rebuild: bool,
    attempts: int = 6,
    delay_seconds: int = 10,
) -> Dict[str, Any]:
    """Start the build, retrying transient authorization/throttling failures."""
    overrides = [
        {
            'name': 'IDP_COMMON_EXTRAS',
            'value': ','.join(idp_common_extras),
            'type': 'PLAINTEXT'
        },
        {
            'name': 'REQUIREMENTS_HASH',
            'value': requirements_hash,
            'type': 'PLAINTEXT'
        },
        {
            'name': 'FORCE_REBUILD',
            'value': str(force_rebuild).lower(),
            'type': 'PLAINTEXT'
        }
    ]

    for attempt in range(1, attempts + 1):
        try:
            return codebuild.start_build(
                projectName=project_name,
                environmentVariablesOverride=overrides,
            )
        except ClientError as error:
            code = error.response.get('Error', {}).get('Code', '')
            if code not in _RETRYABLE_START_BUILD_ERRORS or attempt == attempts:
                raise
            logger.warning(
                "StartBuild attempt %s/%s for %s failed with %s; retrying in %ss",
                attempt,
                attempts,
                project_name,
                code,
                delay_seconds,
            )
            time.sleep(delay_seconds)

    raise RuntimeError(f"StartBuild for {project_name} exhausted {attempts} attempts")


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for triggering IDP layer CodeBuild.
    
    Expected event structure:
    {
        "codebuild_project_name": "project-name",
        "requirements_hash": "hash-of-requirements",
        "idp_common_extras": ["ocr", "docs_service"],
        "force_rebuild": false,
        "buildspec_hash": "hash-of-buildspec"
    }
    """
    try:
        logger.info(f"Received event: {json.dumps(event, indent=2)}")
        
        # Extract parameters from event
        project_name = event['codebuild_project_name']
        requirements_hash = event.get('requirements_hash', '')
        idp_common_extras = event.get('idp_common_extras', [])
        force_rebuild = event.get('force_rebuild', False)
        buildspec_hash = event.get('buildspec_hash', '')
        
        # Initialize AWS clients
        codebuild = boto3.client('codebuild')
        logs_client = boto3.client('logs')
        
        logger.info(f"Starting CodeBuild project: {project_name}")
        logger.info(f"Requirements hash: {requirements_hash}")
        logger.info(f"IDP common extras: {idp_common_extras}")
        logger.info(f"Force rebuild: {force_rebuild}")
        
        # Start the CodeBuild project
        response = start_build_with_retry(
            codebuild,
            project_name,
            idp_common_extras,
            requirements_hash,
            force_rebuild,
        )
        
        build_id = response['build']['id']
        logger.info(f"Started build with ID: {build_id}")
        
        # Monitor build progress
        build_status = monitor_build_progress(codebuild, logs_client, build_id, project_name)
        
        if build_status != 'SUCCEEDED':
            error_msg = f"Build failed with status: {build_status}"
            logger.error(error_msg)
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': error_msg,
                    'build_id': build_id,
                    'build_status': build_status
                })
            }
        
        logger.info("Build completed successfully")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'IDP layer build completed successfully',
                'build_id': build_id,
                'build_status': build_status,
                'requirements_hash': requirements_hash,
                'idp_common_extras': idp_common_extras
            })
        }
        
    except Exception as e:
        error_msg = f"Failed to trigger CodeBuild: {str(e)}"
        logger.error(error_msg, exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg,
                'build_id': event.get('build_id', 'unknown')
            })
        }

def monitor_build_progress(codebuild: Any, logs_client: Any, build_id: str, project_name: str) -> str:
    """
    Monitor CodeBuild progress and return final status.
    
    Args:
        codebuild: CodeBuild client
        logs_client: CloudWatch Logs client  
        build_id: Build ID to monitor
        project_name: CodeBuild project name
        
    Returns:
        Final build status string
    """
    status = "IN_PROGRESS"
    max_wait_time = 1800  # 30 minutes max wait
    start_time = time.time()
    
    # Extract log stream name from build ID (after the colon)
    log_stream_name = build_id.split(':')[-1] if ':' in build_id else build_id
    log_group_name = f"/aws/codebuild/{project_name}"
    
    while status == "IN_PROGRESS":
        # Check if we've exceeded max wait time
        if time.time() - start_time > max_wait_time:
            logger.error(f"Build timeout after {max_wait_time} seconds")
            return "TIMEOUT"
        
        logger.info("Waiting for CodeBuild to complete...")
        time.sleep(10)
        
        try:
            # Get build status
            response = codebuild.batch_get_builds(ids=[build_id])
            if response['builds']:
                build = response['builds'][0]
                status = build['buildStatus']
                
                # Log current phase if available
                if 'currentPhase' in build:
                    logger.info(f"Current phase: {build['currentPhase']}")
                
                # If build failed, try to get logs
                if status in ['FAILED', 'FAULT', 'STOPPED', 'TIMED_OUT']:
                    logger.error(f"Build failed with status: {status}")
                    
                    # Try to retrieve build logs for debugging
                    try:
                        log_events = get_build_logs(logs_client, log_group_name, log_stream_name)
                        if log_events:
                            logger.error("Build logs (last 10 lines):")
                            for event in log_events[-10:]:
                                logger.error(event.get('message', ''))
                        else:
                            logger.warning("Could not retrieve build logs")
                    except Exception as log_error:
                        logger.warning(f"Failed to retrieve logs: {log_error}")
                    
                    break
                    
        except Exception as e:
            logger.error(f"Error checking build status: {e}")
            return "ERROR"
    
    logger.info(f"Build completed with status: {status}")
    return status

def get_build_logs(logs_client: Any, log_group_name: str, log_stream_name: str) -> List[Dict[str, Any]]:
    """
    Retrieve build logs from CloudWatch Logs.
    
    Args:
        logs_client: CloudWatch Logs client
        log_group_name: Log group name
        log_stream_name: Log stream name
        
    Returns:
        List of log events
    """
    try:
        # Try multiple log stream name patterns
        log_stream_patterns = [
            log_stream_name,
            f"{log_stream_name}",
            log_stream_name.replace(':', '-')
        ]
        
        for pattern in log_stream_patterns:
            try:
                response = logs_client.get_log_events(
                    logGroupName=log_group_name,
                    logStreamName=pattern,
                    limit=50
                )
                if response.get('events'):
                    return response['events']
            except logs_client.exceptions.ResourceNotFoundException:
                continue
        
        # If no specific stream found, try to list available streams
        logger.info("Listing available log streams...")
        streams_response = logs_client.describe_log_streams(
            logGroupName=log_group_name,
            orderBy='LastEventTime',
            descending=True,
            limit=5
        )
        
        available_streams = [stream['logStreamName'] for stream in streams_response.get('logStreams', [])]
        logger.info(f"Available log streams: {available_streams}")
        
        return []
        
    except Exception as e:
        logger.warning(f"Failed to retrieve logs: {e}")
        return []
