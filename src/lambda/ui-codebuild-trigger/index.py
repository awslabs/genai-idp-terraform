#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Lambda function to trigger CodeBuild for Web UI deployment.

This function replaces the null_resource approach with a proper AWS Lambda function
following AWS-IA patterns. It handles:
- CodeBuild project triggering for React app build and deployment
- Build status monitoring
- CloudFront cache invalidation
- Error handling and logging
- S3 deployment verification
"""

import json
import os
import time
import boto3
from typing import Dict, Any, List, Optional
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for triggering Web UI CodeBuild.
    
    Expected event structure:
    {
        "codebuild_project_name": "project-name",
        "settings_parameter": "/path/to/ssm/parameter",
        "code_location": "bucket-name/code/ui-source.zip",
        "webapp_bucket": "webapp-bucket-name",
        "cloudfront_distribution_id": "distribution-id-or-null",
        "settings_hash": "hash-of-ui-settings",
        "buildspec_hash": "hash-of-buildspec",
        "source_code_hash": "hash-of-source-code"
    }
    """
    try:
        logger.info(f"Received event: {json.dumps(event, indent=2)}")
        
        # Extract parameters from event
        project_name = event['codebuild_project_name']
        settings_parameter = event['settings_parameter']
        code_location = event['code_location']
        webapp_bucket = event['webapp_bucket']
        cloudfront_distribution_id = event.get('cloudfront_distribution_id')
        settings_hash = event.get('settings_hash', '')
        buildspec_hash = event.get('buildspec_hash', '')
        source_code_hash = event.get('source_code_hash', '')
        
        # Initialize AWS clients
        codebuild = boto3.client('codebuild')
        logs_client = boto3.client('logs')
        s3_client = boto3.client('s3')
        cloudfront_client = boto3.client('cloudfront')
        
        logger.info(f"Starting CodeBuild project: {project_name}")
        logger.info(f"Settings parameter: {settings_parameter}")
        logger.info(f"Code location: {code_location}")
        logger.info(f"WebApp bucket: {webapp_bucket}")
        logger.info(f"CloudFront distribution: {cloudfront_distribution_id}")
        
        # Prepare environment variables for CodeBuild
        environment_variables = [
            {
                'name': 'SETTINGS_PARAMETER',
                'value': settings_parameter,
                'type': 'PLAINTEXT'
            },
            {
                'name': 'CODE_LOCATION',
                'value': code_location,
                'type': 'PLAINTEXT'
            },
            {
                'name': 'WEBAPP_BUCKET',
                'value': webapp_bucket,
                'type': 'PLAINTEXT'
            },
            {
                'name': 'SETTINGS_HASH',
                'value': settings_hash,
                'type': 'PLAINTEXT'
            }
        ]
        
        # Add CloudFront distribution ID if provided
        if cloudfront_distribution_id:
            environment_variables.append({
                'name': 'CLOUDFRONT_DISTRIBUTION_ID',
                'value': cloudfront_distribution_id,
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
        
        # Verify deployment
        deployment_info = verify_deployment(s3_client, webapp_bucket, cloudfront_client, cloudfront_distribution_id)
        
        logger.info("Web UI build and deployment completed successfully")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Web UI build and deployment completed successfully',
                'build_id': build_id,
                'build_status': build_status,
                'deployment_info': deployment_info,
                'settings_hash': settings_hash,
                'webapp_bucket': webapp_bucket,
                'cloudfront_distribution_id': cloudfront_distribution_id
            })
        }
        
    except Exception as e:
        error_msg = f"Failed to trigger Web UI CodeBuild: {str(e)}"
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
    max_wait_time = 1800  # 30 minutes max wait (UI builds can take longer)
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
        time.sleep(30)  # UI builds take longer, check less frequently
        
        try:
            # Get build status
            response = codebuild.batch_get_builds(ids=[build_id])
            if response['builds']:
                build = response['builds'][0]
                status = build['buildStatus']
                
                # Log current phase if available
                if 'currentPhase' in build:
                    logger.info(f"Current phase: {build['currentPhase']}")
                
                # Log phase details for UI-specific phases
                if 'phases' in build:
                    for phase in build['phases']:
                        phase_type = phase.get('phaseType', '')
                        phase_status = phase.get('phaseStatus', '')
                        if phase_type in ['PRE_BUILD', 'BUILD', 'POST_BUILD'] and phase_status:
                            logger.info(f"Phase {phase_type}: {phase_status}")
                
                # If build failed, try to get logs
                if status in ['FAILED', 'FAULT', 'STOPPED', 'TIMED_OUT']:
                    logger.error(f"Build failed with status: {status}")
                    
                    # Try to retrieve build logs for debugging
                    try:
                        log_events = get_build_logs(logs_client, log_group_name, log_stream_name)
                        if log_events:
                            logger.error("Build logs (last 20 lines):")
                            for event in log_events[-20:]:
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
                    limit=100  # Get more logs for UI builds
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

def verify_deployment(s3_client: Any, webapp_bucket: str, cloudfront_client: Any, cloudfront_distribution_id: Optional[str]) -> Dict[str, Any]:
    """
    Verify that the Web UI deployment was successful.
    
    Args:
        s3_client: S3 client
        webapp_bucket: Web app S3 bucket name
        cloudfront_client: CloudFront client
        cloudfront_distribution_id: CloudFront distribution ID (optional)
        
    Returns:
        Dictionary with deployment verification results
    """
    deployment_info = {
        's3_deployment': False,
        'cloudfront_invalidation': None,
        'files_deployed': 0
    }
    
    try:
        # Check if key files exist in S3
        key_files = ['index.html', 'static/js/', 'static/css/']
        deployed_files = []
        
        # List objects in the bucket to verify deployment
        response = s3_client.list_objects_v2(Bucket=webapp_bucket, MaxKeys=100)
        if 'Contents' in response:
            deployment_info['files_deployed'] = len(response['Contents'])
            
            # Check for key files
            object_keys = [obj['Key'] for obj in response['Contents']]
            
            # Verify index.html exists
            if 'index.html' in object_keys:
                deployed_files.append('index.html')
            
            # Verify static assets exist
            static_js_files = [key for key in object_keys if key.startswith('static/js/')]
            static_css_files = [key for key in object_keys if key.startswith('static/css/')]
            
            if static_js_files:
                deployed_files.append(f'static/js/ ({len(static_js_files)} files)')
            if static_css_files:
                deployed_files.append(f'static/css/ ({len(static_css_files)} files)')
            
            deployment_info['s3_deployment'] = len(deployed_files) >= 2  # At least index.html and some static files
            deployment_info['deployed_files'] = deployed_files
            
            logger.info(f"S3 deployment verification: {deployment_info['files_deployed']} files deployed")
            logger.info(f"Key files found: {deployed_files}")
        
        # Check CloudFront invalidation if distribution ID provided
        if cloudfront_distribution_id:
            try:
                # List recent invalidations to verify our invalidation was created
                invalidations_response = cloudfront_client.list_invalidations(
                    DistributionId=cloudfront_distribution_id,
                    MaxItems='5'
                )
                
                if 'InvalidationList' in invalidations_response and 'Items' in invalidations_response['InvalidationList']:
                    recent_invalidations = invalidations_response['InvalidationList']['Items']
                    if recent_invalidations:
                        latest_invalidation = recent_invalidations[0]
                        deployment_info['cloudfront_invalidation'] = {
                            'id': latest_invalidation['Id'],
                            'status': latest_invalidation['Status'],
                            'create_time': latest_invalidation['CreateTime'].isoformat()
                        }
                        logger.info(f"CloudFront invalidation found: {latest_invalidation['Id']} ({latest_invalidation['Status']})")
                
            except Exception as cf_error:
                logger.warning(f"Could not verify CloudFront invalidation: {cf_error}")
                deployment_info['cloudfront_invalidation'] = {'error': str(cf_error)}
        
    except Exception as e:
        logger.error(f"Error verifying deployment: {e}")
        deployment_info['verification_error'] = str(e)
    
    return deployment_info
