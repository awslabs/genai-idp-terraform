# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import logging
from typing import Dict, Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for publishStepFunctionExecutionUpdate mutation
    This function simply returns the data to trigger the subscription
    
    Args:
        event: AppSync event containing executionArn and data
        context: Lambda context
        
    Returns:
        Step Functions execution data to trigger subscription
    """
    try:
        execution_arn = event['arguments']['executionArn']
        data = json.loads(event['arguments']['data'])
        
        logger.info(f"Publishing Step Functions update for execution: {execution_arn}")
        
        # Return the data to trigger the subscription
        # AppSync will automatically publish this to subscribers
        return data
        
    except Exception as e:
        logger.error(f"Error publishing Step Functions update: {str(e)}")
        raise e
