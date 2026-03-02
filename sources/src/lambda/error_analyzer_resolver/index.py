# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
GraphQL resolver function for error analysis operations.

This function handles GraphQL queries and mutations for error analysis,
coordinating with the Error Analyzer function to provide AI-powered troubleshooting.
"""

import json
import logging
import os
from datetime import datetime
from typing import Any, Dict, List, Optional

import boto3
import botocore.exceptions

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Initialize clients
lambda_client = boto3.client('lambda')
dynamodb = boto3.resource('dynamodb')

def get_trace_table():
    """Get DynamoDB table for trace storage."""
    table_name = os.environ.get('TRACE_TABLE_NAME')
    if not table_name:
        raise ValueError("TRACE_TABLE_NAME environment variable not set")
    return dynamodb.Table(table_name)

def invoke_analyzer_function(request_id: str, error_description: str, error_keywords: List[str] = None) -> Dict[str, Any]:
    """
    Invoke the Error Analyzer function to perform AI-powered analysis.

    Args:
        request_id: The request ID to analyze
        error_description: Description of the error
        error_keywords: Optional additional keywords to search for

    Returns:
        Analysis results from the Error Analyzer function
    """
    try:
        function_name = os.environ.get('ANALYZER_FUNCTION_NAME')
        if not function_name:
            raise ValueError("ANALYZER_FUNCTION_NAME environment variable not set")

        # Prepare payload
        payload = {
            'requestId': request_id,
            'errorDescription': error_description,
            'errorKeywords': error_keywords or []
        }

        # Invoke the analyzer function
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )

        # Parse response
        response_payload = json.loads(response['Payload'].read())

        if response_payload.get('statusCode') == 200:
            return json.loads(response_payload['body'])
        else:
            error_body = json.loads(response_payload.get('body', '{}'))
            raise Exception(f"Analyzer function failed: {error_body.get('error', 'Unknown error')}")

    except Exception as e:
        logger.error(f"Error invoking analyzer function: {e}")
        raise

def get_error_analysis(request_id: str) -> Optional[Dict[str, Any]]:
    """
    Get stored error analysis results for a request ID.

    Args:
        request_id: The request ID to get analysis for

    Returns:
        Stored analysis results or None if not found
    """
    try:
        table = get_trace_table()

        # Query for the most recent analysis for this request ID
        response = table.query(
            KeyConditionExpression='requestId = :rid',
            ExpressionAttributeValues={':rid': request_id},
            ScanIndexForward=False,  # Most recent first
            Limit=1
        )

        items = response.get('Items', [])
        if items:
            return items[0].get('traceData', {})

        return None

    except Exception as e:
        logger.error(f"Error getting error analysis: {e}")
        return None

def list_error_analyses(limit: int = 50, next_token: str = None) -> Dict[str, Any]:
    """
    List recent error analyses.

    Args:
        limit: Maximum number of results to return
        next_token: Pagination token for next page

    Returns:
        List of error analyses with pagination info
    """
    try:
        table = get_trace_table()

        scan_kwargs = {
            'Limit': limit,
            'ScanIndexForward': False  # Most recent first
        }

        if next_token:
            scan_kwargs['ExclusiveStartKey'] = json.loads(next_token)

        response = table.scan(**scan_kwargs)

        items = response.get('Items', [])

        # Prepare response
        result = {
            'analyses': [
                {
                    'requestId': item.get('requestId'),
                    'timestamp': item.get('timestamp'),
                    'traceData': item.get('traceData', {})
                }
                for item in items
            ]
        }

        # Add pagination info
        if 'LastEvaluatedKey' in response:
            result['nextToken'] = json.dumps(response['LastEvaluatedKey'])

        return result

    except Exception as e:
        logger.error(f"Error listing error analyses: {e}")
        return {'analyses': [], 'error': str(e)}

def handler(event, context):
    """
    GraphQL resolver handler for error analysis operations.

    Handles the following operations:
    - analyzeError: Trigger AI-powered error analysis
    - getErrorAnalysis: Retrieve stored analysis results
    - listErrorAnalyses: List recent error analyses

    Args:
        event: AppSync resolver event
        context: Lambda context

    Returns:
        GraphQL response data
    """
    logger.info(f"Received error analyzer resolver event: {json.dumps(event)}")

    try:
        # Extract GraphQL operation info
        field_name = event.get('info', {}).get('fieldName')
        arguments = event.get('arguments', {})

        if field_name == 'analyzeError':
            # Trigger error analysis
            request_id = arguments.get('requestId')
            error_description = arguments.get('errorDescription', '')
            error_keywords = arguments.get('errorKeywords', [])

            if not request_id:
                raise ValueError("requestId is required for analyzeError")

            # Invoke analyzer function
            analysis_result = invoke_analyzer_function(request_id, error_description, error_keywords)

            return {
                'requestId': request_id,
                'status': 'COMPLETED',
                'analysis': analysis_result.get('analysis', {}),
                'logEntriesFound': analysis_result.get('logEntriesFound', 0),
                'tracesFound': analysis_result.get('tracesFound', 0),
                'timestamp': analysis_result.get('timestamp', datetime.utcnow().isoformat())
            }

        elif field_name == 'getErrorAnalysis':
            # Get stored analysis
            request_id = arguments.get('requestId')

            if not request_id:
                raise ValueError("requestId is required for getErrorAnalysis")

            analysis_data = get_error_analysis(request_id)

            if analysis_data:
                return {
                    'requestId': request_id,
                    'status': 'FOUND',
                    'analysis': analysis_data.get('traces', []),
                    'timestamp': datetime.utcnow().isoformat()
                }
            else:
                return {
                    'requestId': request_id,
                    'status': 'NOT_FOUND',
                    'analysis': {},
                    'timestamp': datetime.utcnow().isoformat()
                }

        elif field_name == 'listErrorAnalyses':
            # List recent analyses
            limit = arguments.get('limit', 50)
            next_token = arguments.get('nextToken')

            result = list_error_analyses(limit, next_token)

            return {
                'analyses': result.get('analyses', []),
                'nextToken': result.get('nextToken'),
                'timestamp': datetime.utcnow().isoformat()
            }

        else:
            raise ValueError(f"Unknown field name: {field_name}")

    except Exception as e:
        logger.error(f"Error in error analyzer resolver: {str(e)}")

        return {
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }
