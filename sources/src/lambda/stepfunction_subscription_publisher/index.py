# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import os
import boto3
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional
from botocore.exceptions import ClientError
import requests
from aws_requests_auth.aws_auth import AWSRequestsAuth

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Initialize clients
stepfunctions = boto3.client('stepfunctions')
session = boto3.Session()
credentials = session.get_credentials()

APPSYNC_API_URL = os.environ['APPSYNC_API_URL']


def handler(event: dict, context: Any) -> dict:
    """
    Lambda function to publish Step Functions execution updates to GraphQL subscription
    
    Args:
        event: EventBridge event from Step Functions
        context: Lambda context
        
    Returns:
        Success response
    """
    logger.info(f"Received Step Functions event: {json.dumps(event)}")
    
    try:
        # Extract execution ARN from the event
        detail = event.get('detail', {})
        execution_arn = detail.get('executionArn')
        
        if not execution_arn:
            logger.warning("No execution ARN found in event")
            return {"statusCode": 200, "body": "No execution ARN found"}
        
        # Get updated execution details
        execution_response = stepfunctions.describe_execution(executionArn=execution_arn)
        
        # Get execution history
        history_response = stepfunctions.get_execution_history(
            executionArn=execution_arn,
            maxResults=100,
            reverseOrder=False
        )
        
        # Parse execution details (reuse logic from get_stepfunction_execution_resolver)
        execution_details = {
            'executionArn': execution_response['executionArn'],
            'status': execution_response['status'],
            'startDate': execution_response['startDate'].isoformat() if execution_response.get('startDate') else None,
            'stopDate': execution_response.get('stopDate').isoformat() if execution_response.get('stopDate') else None,
            'input': execution_response.get('input'),
            'output': execution_response.get('output'),
            'steps': parse_execution_history(history_response['events'])
        }
        
        # Publish to GraphQL subscription using AppSync mutation
        publish_to_subscription(execution_arn, execution_details)
        
        logger.info(f"Step Functions execution update published for: {execution_arn}")
        
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Step Functions update processed successfully"})
        }
        
    except Exception as e:
        logger.error(f"Error processing Step Functions event: {str(e)}", exc_info=True)
        raise e


def publish_to_subscription(execution_arn: str, execution_details: Dict[str, Any]) -> None:
    """
    Publish Step Functions execution update to GraphQL subscription
    
    Args:
        execution_arn: The Step Functions execution ARN
        execution_details: The execution details to publish
    """
    try:
        # Create the GraphQL mutation to trigger the subscription
        mutation = """
        mutation PublishStepFunctionUpdate($executionArn: String!, $data: AWSJSON!) {
          publishStepFunctionExecutionUpdate(executionArn: $executionArn, data: $data) {
            executionArn
            status
            startDate
            stopDate
            steps {
              name
              type
              status
              startDate
              stopDate
              error
            }
          }
        }
        """
        
        variables = {
            'executionArn': execution_arn,
            'data': json.dumps(execution_details)
        }
        
        # Prepare the GraphQL request
        graphql_request = {
            'query': mutation,
            'variables': variables
        }
        
        # Set up AWS authentication
        region = session.region_name or 'us-west-2'
        auth = AWSRequestsAuth(
            aws_access_key=credentials.access_key,
            aws_secret_access_key=credentials.secret_key,
            aws_token=credentials.token,
            aws_host=APPSYNC_API_URL.replace('https://', '').replace('/graphql', ''),
            aws_region=region,
            aws_service='appsync'
        )
        
        # Make the GraphQL request
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        logger.info(f"Publishing Step Functions update to AppSync for execution: {execution_arn}")
        
        response = requests.post(
            APPSYNC_API_URL,
            json=graphql_request,
            headers=headers,
            auth=auth,
            timeout=30
        )
        
        if response.status_code == 200:
            logger.info(f"Successfully published Step Functions update for: {execution_arn}")
        else:
            logger.error(f"Failed to publish Step Functions update. Status: {response.status_code}, Response: {response.text}")
            
    except Exception as e:
        logger.error(f"Error publishing to subscription: {str(e)}", exc_info=True)
        raise


def parse_execution_history(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Parse Step Functions execution history events into step details
    (Reused from get_stepfunction_execution_resolver)
    """
    steps = []
    step_map = {}
    event_id_to_step = {}  # Map event IDs to step names for correlation
    
    for event in events:
        event_type = event['type']
        event_id = event['id']
        timestamp = event['timestamp'].isoformat()
        
        # Handle state entered events
        if event_type in ['TaskStateEntered', 'ChoiceStateEntered', 'PassStateEntered', 'WaitStateEntered', 'ParallelStateEntered']:
            step_name = event['stateEnteredEventDetails']['name']
            step_type = event_type.replace('StateEntered', '').replace('Task', 'Task').replace('Choice', 'Choice').replace('Pass', 'Pass').replace('Wait', 'Wait').replace('Parallel', 'Parallel')
            
            step_map[step_name] = {
                'name': step_name,
                'type': step_type,
                'status': 'RUNNING',
                'startDate': timestamp,
                'stopDate': None,
                'input': event['stateEnteredEventDetails'].get('input'),
                'output': None,
                'error': None
            }
            event_id_to_step[event_id] = step_name
            
        # Handle state exited events (successful completion)
        elif event_type in ['TaskStateExited', 'ChoiceStateExited', 'PassStateExited', 'WaitStateExited', 'ParallelStateExited']:
            step_name = event['stateExitedEventDetails']['name']
            if step_name in step_map:
                step_map[step_name]['status'] = 'SUCCEEDED'
                step_map[step_name]['stopDate'] = timestamp
                step_map[step_name]['output'] = event['stateExitedEventDetails'].get('output')
                
        # Handle task failure events
        elif event_type == 'TaskFailed':
            # Find the corresponding step by looking at previous events
            step_name = find_step_name_for_failure_event(event, events, event_id_to_step)
            if step_name and step_name in step_map:
                step_map[step_name]['status'] = 'FAILED'
                step_map[step_name]['stopDate'] = timestamp
                
                # Extract error details
                task_failed_details = event.get('taskFailedEventDetails', {})
                error_message = task_failed_details.get('error', 'Unknown error')
                cause = task_failed_details.get('cause', '')
                
                # Combine error and cause for more detailed error message
                if cause:
                    try:
                        # Try to parse cause as JSON for better formatting
                        cause_json = json.loads(cause)
                        if isinstance(cause_json, dict):
                            error_type = cause_json.get('errorType', '')
                            error_msg = cause_json.get('errorMessage', '')
                            if error_type and error_msg:
                                error_message = f"{error_type}: {error_msg}"
                            elif error_msg:
                                error_message = error_msg
                    except (json.JSONDecodeError, TypeError):
                        # If cause is not JSON, append it as-is
                        error_message = f"{error_message}: {cause}"
                
                step_map[step_name]['error'] = error_message
                
        # Handle other failure events
        elif event_type in ['TaskTimedOut', 'TaskAborted']:
            step_name = find_step_name_for_failure_event(event, events, event_id_to_step)
            if step_name and step_name in step_map:
                step_map[step_name]['status'] = 'FAILED'
                step_map[step_name]['stopDate'] = timestamp
                
                if event_type == 'TaskTimedOut':
                    timeout_details = event.get('taskTimedOutEventDetails', {})
                    error_message = f"Task timed out: {timeout_details.get('error', 'Timeout occurred')}"
                    cause = timeout_details.get('cause', '')
                    if cause:
                        error_message = f"{error_message} - {cause}"
                elif event_type == 'TaskAborted':
                    error_message = "Task was aborted"
                    
                step_map[step_name]['error'] = error_message
                
        # Handle Lambda function failure events
        elif event_type == 'LambdaFunctionFailed':
            step_name = find_step_name_for_failure_event(event, events, event_id_to_step)
            if step_name and step_name in step_map:
                step_map[step_name]['status'] = 'FAILED'
                step_map[step_name]['stopDate'] = timestamp
                
                lambda_failed_details = event.get('lambdaFunctionFailedEventDetails', {})
                error_message = lambda_failed_details.get('error', 'Lambda function failed')
                cause = lambda_failed_details.get('cause', '')
                if cause:
                    error_message = f"{error_message}: {cause}"
                    
                step_map[step_name]['error'] = error_message
    
    # Convert to list and sort by start time
    steps = list(step_map.values())
    steps.sort(key=lambda x: x['startDate'] if x['startDate'] else '')
    
    return steps


def find_step_name_for_failure_event(failure_event: Dict[str, Any], all_events: List[Dict[str, Any]], event_id_to_step: Dict[int, str]) -> Optional[str]:
    """
    Find the step name associated with a failure event by correlating with previous events
    """
    try:
        # Try to get the step name from previousEventId correlation
        previous_event_id = failure_event.get('previousEventId')
        if previous_event_id and previous_event_id in event_id_to_step:
            return event_id_to_step[previous_event_id]
            
        # Alternative approach: look for the most recent TaskStateEntered event before this failure
        failure_event_id = failure_event['id']
        for event in reversed(all_events):
            if event['id'] >= failure_event_id:
                continue
            if event['type'] == 'TaskStateEntered':
                return event['stateEnteredEventDetails']['name']
                
        # Fallback: try to extract from task details if available
        if 'taskFailedEventDetails' in failure_event:
            resource = failure_event['taskFailedEventDetails'].get('resource', '')
            if resource:
                # Extract step name from resource ARN if possible
                parts = resource.split(':')
                if len(parts) > 1:
                    return parts[-1].split('/')[-1]
                    
    except Exception as e:
        logger.warning(f"Error finding step name for failure event: {str(e)}")
        
    return None
