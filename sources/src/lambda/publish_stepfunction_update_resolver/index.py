# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import logging
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler to publish Step Functions execution updates via GraphQL API.
    
    This resolver receives execution update data and returns it in the format
    expected by the StepFunctionExecutionResponse type.
    
    Args:
        event: AppSync event containing executionArn and data
        context: Lambda context
        
    Returns:
        Step Functions execution response with the provided data
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        arguments = event.get('arguments', {})
        execution_arn = arguments.get('executionArn')
        data = arguments.get('data')
        
        if not execution_arn:
            raise ValueError("executionArn is required")
        
        if not data:
            raise ValueError("data is required")
        
        # Parse the data if it's a string
        if isinstance(data, str):
            data = json.loads(data)
        
        # Build the response in StepFunctionExecutionResponse format
        response = {
            'executionArn': execution_arn,
            'status': data.get('status', 'UNKNOWN'),
            'startDate': data.get('startDate'),
            'stopDate': data.get('stopDate'),
            'input': data.get('input'),
            'output': data.get('output'),
            'error': data.get('error'),
            'steps': data.get('steps', [])
        }
        
        logger.info(f"Returning response for execution: {execution_arn}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing Step Function update: {str(e)}")
        return {
            'executionArn': event.get('arguments', {}).get('executionArn', 'Unknown'),
            'status': 'ERROR',
            'error': f"Failed to process update: {str(e)}",
            'steps': []
        }
