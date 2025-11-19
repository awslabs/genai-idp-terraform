#!/usr/bin/env python3
"""
Generic Lambda function to trigger CodeBuild for Lambda layer creation.

This function provides a robust, monitored approach to triggering CodeBuild projects
for Lambda layer creation, replacing the null_resource approach with proper AWS Lambda
integration following AWS-IA patterns.

Features:
- CodeBuild project triggering with parameter passing
- Build status monitoring with timeout handling
- Comprehensive error handling and logging
- CloudWatch Logs integration for debugging
- Generic design for any layer build requirements
"""

import json
import os
import time
import boto3
from typing import Dict, Any, List
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for triggering generic layer CodeBuild.
    
    Expected event structure:
    {
        "codebuild_project_name": "project-name",
        "requirements_hash": "hash-of-requirements",
        "force_rebuild": false,
        "buildspec_hash": "hash-of-buildspec",
        "environment_variables": {
            "CUSTOM_VAR": "value"
        }
    }
    """
    try:
        logger.info(f"Received event: {json.dumps(event, indent=2)}")
        
        # Extract parameters from event
        project_name = event['codebuild_project_name']
        requirements_hash = event.get('requirements_hash', '')
        force_rebuild = event.get('force_rebuild', False)
        buildspec_hash = event.get('buildspec_hash', '')
        custom_env_vars = event.get('environment_variables', {})
        
        # Initialize AWS clients
        codebuild = boto3.client('codebuild')
        logs_client = boto3.client('logs')
        
        logger.info(f"Starting CodeBuild project: {project_name}")
        logger.info(f"Requirements hash: {requirements_hash}")
        logger.info(f"Force rebuild: {force_rebuild}")
        logger.info(f"Custom environment variables: {custom_env_vars}")
        
        # Prepare environment variables for CodeBuild
        environment_variables = [
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
        
        # Add custom environment variables
        for key, value in custom_env_vars.items():
            environment_variables.append({
                'name': key,
                'value': str(value),
                'type': 'PLAINTEXT'
            })
        
        # Start the CodeBuild project
        response = codebuild.start_build(
            projectName=project_name,
            environmentVariablesOverride=environment_variables
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
                'message': 'Layer build completed successfully',
                'build_id': build_id,
                'build_status': build_status,
                'requirements_hash': requirements_hash
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
