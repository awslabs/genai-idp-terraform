# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
import boto3
import json
import logging
import os
import urllib.request
import time

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

def send_cfn_response(event, context, response_status, response_data, physical_resource_id=None):
    """Send response to CloudFormation custom resource request"""
    response_url = event['ResponseURL']
    
    response_body = {
        'Status': response_status,
        'Reason': f'See the details in CloudWatch Log Stream: {context.log_stream_name}',
        'PhysicalResourceId': physical_resource_id or context.log_stream_name,
        'StackId': event['StackId'],
        'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'],
        'Data': response_data
    }
    
    json_response_body = json.dumps(response_body)
    headers = {
        'content-type': '',
        'content-length': str(len(json_response_body))
    }
    
    try:
        req = urllib.request.Request(
            response_url,
            data=json_response_body.encode('utf-8'),
            headers=headers,
            method='PUT'
        )
        response = urllib.request.urlopen(req)
        logger.info(f"Status code: {response.getcode()}")
        return True
    except Exception as e:
        logger.error(f"Error sending CloudFormation response: {str(e)}")
        return False

def handler(event, context):
    """
    Lambda function handler to retrieve the SageMaker Ground Truth workforce portal URL.
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Initialize response data
    response_data = {}
    
    try:
        # For Delete requests, just return success
        if event['RequestType'] == 'Delete':
            logger.info("Delete request - no action needed")
            send_cfn_response(event, context, 'SUCCESS', response_data)
            return
        
        # Get the workteam name from the event
        workteam_name = event['ResourceProperties']['WorkteamName']
        # Ignore the SourceCodeHash property as it's only used to force updates
        _ = event['ResourceProperties'].get('SourceCodeHash')
        logger.info(f"Getting portal URL for workteam: {workteam_name}")
        
        # Initialize SageMaker client
        sagemaker_client = boto3.client('sagemaker')
        
        # The workteam might not be fully created yet, so we'll retry a few times
        max_retries = 5
        retry_delay = 5  # seconds
        
        for attempt in range(max_retries):
            try:
                # Get the workteam details
                response = sagemaker_client.describe_workteam(
                    WorkteamName=workteam_name
                )
                
                # Extract the portal URL
                if 'Workteam' in response and 'SubDomain' in response['Workteam']:
                    portal_url = response['Workteam']['SubDomain']
                    response_data['PortalURL'] = f"https://{portal_url}"
                    logger.info(f"Retrieved portal URL: {response_data['PortalURL']}")
                    
                    # Also include the console URL for convenience
                    response_data['ConsoleURL'] = f"https://{os.environ.get('REGION', 'us-east-1')}.console.aws.amazon.com/sagemaker/groundtruth?region={os.environ.get('REGION', 'us-east-1')}#/labeling-workforces/private"
                    
                    # Send success response
                    send_cfn_response(event, context, 'SUCCESS', response_data)
                    return
                else:
                    logger.warning("No SubDomain found in workteam response")
                    if attempt < max_retries - 1:
                        logger.info(f"Retrying in {retry_delay} seconds... (Attempt {attempt + 1}/{max_retries})")
                        time.sleep(retry_delay)
                    else:
                        response_data['PortalURL'] = "Not available"
                        response_data['ConsoleURL'] = f"https://{os.environ.get('REGION', 'us-east-1')}.console.aws.amazon.com/sagemaker/groundtruth?region={os.environ.get('REGION', 'us-east-1')}#/labeling-workforces/private"
                        logger.warning("Maximum retries reached, returning not available")
            except sagemaker_client.exceptions.ResourceNotFound:
                if attempt < max_retries - 1:
                    logger.info(f"Workteam not found yet. Retrying in {retry_delay} seconds... (Attempt {attempt + 1}/{max_retries})")
                    time.sleep(retry_delay)
                else:
                    logger.error(f"Workteam {workteam_name} not found after {max_retries} attempts")
                    response_data['PortalURL'] = "Workteam not found"
                    response_data['ConsoleURL'] = f"https://{os.environ.get('REGION', 'us-east-1')}.console.aws.amazon.com/sagemaker/groundtruth?region={os.environ.get('REGION', 'us-east-1')}#/labeling-workforces/private"
            except Exception as e:
                logger.error(f"Error on attempt {attempt + 1}: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                else:
                    raise
        
        # If we get here, we've exhausted retries
        send_cfn_response(event, context, 'SUCCESS', response_data)
        
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        response_data['Error'] = str(e)
        send_cfn_response(event, context, 'FAILED', response_data)
