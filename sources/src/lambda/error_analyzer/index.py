# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Lambda function for AI-powered error analysis and troubleshooting.

This function uses Claude Sonnet 4 to analyze document processing failures,
correlate CloudWatch logs, and provide intelligent troubleshooting recommendations.
"""

import asyncio
import json
import logging
import os
import re
import uuid
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import boto3
import botocore.exceptions

from idp_common.agents.common.config import configure_logging
from idp_common.agents.factory import agent_factory

# Configure logging for both application and Strands framework
configure_logging()

# Get logger for this module
logger = logging.getLogger(__name__)

# Global client cache for warm Lambda containers
_client_cache = {}

def get_cached_boto3_session():
    """
    Get or create a cached boto3 session for warm Lambda containers.

    Returns:
        Cached boto3.Session instance
    """
    global _client_cache

    if 'session' not in _client_cache:
        _client_cache['session'] = boto3.Session()
        logger.info("Created new boto3 session (will be cached for warm starts)")
    else:
        logger.info("Reusing cached boto3 session from warm container")

    return _client_cache['session']

def get_cloudwatch_logs_client():
    """Get CloudWatch Logs client."""
    session = get_cached_boto3_session()
    return session.client('logs')

def get_xray_client():
    """Get X-Ray client."""
    session = get_cached_boto3_session()
    return session.client('xray')

def get_dynamodb_table():
    """Get DynamoDB table for trace storage."""
    session = get_cached_boto3_session()
    dynamodb = session.resource('dynamodb')
    table_name = os.environ.get('TRACE_TABLE_NAME')
    if not table_name:
        raise ValueError("TRACE_TABLE_NAME environment variable not set")
    return dynamodb.Table(table_name)

def search_cloudwatch_logs(request_id: str, error_keywords: List[str] = None, hours_back: int = 24) -> List[Dict[str, Any]]:
    """
    Search CloudWatch logs for entries related to a request ID.

    Args:
        request_id: The request ID to search for
        error_keywords: Additional error keywords to search for
        hours_back: How many hours back to search

    Returns:
        List of log entries with context
    """
    if not os.environ.get('ENABLE_LOG_ANALYSIS', 'true').lower() == 'true':
        logger.info("Log analysis is disabled")
        return []

    try:
        logs_client = get_cloudwatch_logs_client()

        # Calculate time range
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours_back)

        # Convert to milliseconds since epoch
        start_time_ms = int(start_time.timestamp() * 1000)
        end_time_ms = int(end_time.timestamp() * 1000)

        # Build filter pattern
        filter_patterns = [request_id]
        if error_keywords:
            filter_patterns.extend(error_keywords)

        # Search across common log groups
        log_groups = [
            '/aws/lambda/ProcessingEnvironment',
            '/aws/stepfunctions/StateMachine',
            '/aws/lambda/BdaProcessor',
            '/aws/lambda/BedrockLlmProcessor',
            '/aws/lambda/SageMakerUdopProcessor',
        ]

        log_entries = []

        for log_group in log_groups:
            try:
                # Check if log group exists
                logs_client.describe_log_groups(logGroupNamePrefix=log_group, limit=1)

                for pattern in filter_patterns:
                    response = logs_client.filter_log_events(
                        logGroupName=log_group,
                        startTime=start_time_ms,
                        endTime=end_time_ms,
                        filterPattern=pattern,
                        limit=100
                    )

                    for event in response.get('events', []):
                        log_entries.append({
                            'logGroup': log_group,
                            'logStream': event.get('logStreamName'),
                            'timestamp': event.get('timestamp'),
                            'message': event.get('message'),
                            'pattern': pattern
                        })

            except logs_client.exceptions.ResourceNotFoundException:
                logger.debug(f"Log group {log_group} not found, skipping")
                continue
            except Exception as e:
                logger.warning(f"Error searching log group {log_group}: {e}")
                continue

        # Sort by timestamp
        log_entries.sort(key=lambda x: x['timestamp'])

        logger.info(f"Found {len(log_entries)} log entries for request {request_id}")
        return log_entries

    except Exception as e:
        logger.error(f"Error searching CloudWatch logs: {e}")
        return []

def get_xray_traces(request_id: str, hours_back: int = 24) -> List[Dict[str, Any]]:
    """
    Get X-Ray traces for a request ID.

    Args:
        request_id: The request ID to search for
        hours_back: How many hours back to search

    Returns:
        List of trace data
    """
    if not os.environ.get('ENABLE_TRACE_ANALYSIS', 'true').lower() == 'true':
        logger.info("Trace analysis is disabled")
        return []

    try:
        xray_client = get_xray_client()

        # Calculate time range
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours_back)

        # Search for traces
        response = xray_client.get_trace_summaries(
            TimeRangeType='TimeRangeByStartTime',
            StartTime=start_time,
            EndTime=end_time,
            FilterExpression=f'annotation.RequestId = "{request_id}"'
        )

        traces = []
        for trace_summary in response.get('TraceSummaries', []):
            trace_id = trace_summary.get('Id')

            # Get detailed trace
            trace_response = xray_client.batch_get_traces(
                TraceIds=[trace_id]
            )

            for trace in trace_response.get('Traces', []):
                traces.append({
                    'traceId': trace_id,
                    'duration': trace_summary.get('Duration'),
                    'responseTime': trace_summary.get('ResponseTime'),
                    'hasError': trace_summary.get('HasError'),
                    'hasFault': trace_summary.get('HasFault'),
                    'hasThrottle': trace_summary.get('HasThrottle'),
                    'segments': trace.get('Segments', [])
                })

        logger.info(f"Found {len(traces)} X-Ray traces for request {request_id}")
        return traces

    except Exception as e:
        logger.error(f"Error getting X-Ray traces: {e}")
        return []

def store_trace_data(request_id: str, trace_data: Dict[str, Any]) -> None:
    """
    Store trace data in DynamoDB for correlation.

    Args:
        request_id: The request ID
        trace_data: The trace data to store
    """
    try:
        table = get_dynamodb_table()

        # Add TTL (30 days from now)
        ttl = int((datetime.utcnow() + timedelta(days=30)).timestamp())

        table.put_item(
            Item={
                'requestId': request_id,
                'timestamp': int(datetime.utcnow().timestamp() * 1000),
                'traceData': trace_data,
                'ttl': ttl
            }
        )

        logger.info(f"Stored trace data for request {request_id}")

    except Exception as e:
        logger.error(f"Error storing trace data: {e}")

async def analyze_error_with_ai(
    request_id: str,
    error_description: str,
    log_entries: List[Dict[str, Any]],
    trace_data: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """
    Use AI to analyze the error and provide recommendations.

    Args:
        request_id: The request ID
        error_description: Description of the error
        log_entries: CloudWatch log entries
        trace_data: X-Ray trace data

    Returns:
        AI analysis results
    """
    try:
        # Get configuration
        config = {
            'model_id': os.environ.get('MODEL_ID', 'anthropic.claude-3-5-sonnet-20241022-v2:0'),
            'system_prompt': os.environ.get('SYSTEM_PROMPT', ''),
        }

        # Create Error Analyzer agent
        session = get_cached_boto3_session()
        error_analyzer_agent = agent_factory.create_agent(
            agent_id="Error-Analyzer-Agent",
            config=config,
            session=session
        )

        # Prepare analysis context
        context = {
            'request_id': request_id,
            'error_description': error_description,
            'log_entries_count': len(log_entries),
            'trace_data_count': len(trace_data),
            'log_entries': log_entries[:10],  # Limit to first 10 entries
            'trace_data': trace_data[:5] if trace_data else []  # Limit to first 5 traces
        }

        # Create analysis prompt
        prompt = f"""
Please analyze this document processing error and provide troubleshooting recommendations.

Request ID: {request_id}
Error Description: {error_description}

Context Data:
{json.dumps(context, indent=2, default=str)}

Please provide:
1. Root cause analysis
2. Specific troubleshooting steps
3. Prevention recommendations
4. Severity assessment (Low/Medium/High/Critical)
5. Estimated resolution time
"""

        # Get AI analysis
        response = await error_analyzer_agent.process_async(prompt)

        return {
            'analysis': response,
            'model_used': config['model_id'],
            'timestamp': datetime.utcnow().isoformat(),
            'context_summary': {
                'log_entries_analyzed': len(log_entries),
                'traces_analyzed': len(trace_data)
            }
        }

    except Exception as e:
        logger.error(f"Error in AI analysis: {e}")
        return {
            'error': f"AI analysis failed: {str(e)}",
            'timestamp': datetime.utcnow().isoformat()
        }

def handler(event, context):
    """
    Process error analysis requests.

    This handler:
    1. Extracts error information from the event
    2. Searches CloudWatch logs for related entries
    3. Retrieves X-Ray traces for correlation
    4. Uses AI to analyze the error and provide recommendations

    Args:
        event: The event dict containing:
            - requestId: The request ID to analyze
            - errorDescription: Description of the error
            - errorKeywords: Optional additional keywords to search for
        context: The Lambda context

    Returns:
        Analysis results with recommendations
    """
    logger.info(f"Received error analyzer event: {json.dumps(event)}")

    try:
        # Extract parameters from event
        request_id = event.get("requestId")
        error_description = event.get("errorDescription", "")
        error_keywords = event.get("errorKeywords", [])

        # Validate required parameters
        if not request_id:
            error_msg = "requestId is required"
            logger.error(error_msg)
            raise Exception(error_msg)

        # Search CloudWatch logs
        logger.info(f"Searching CloudWatch logs for request {request_id}")
        log_entries = search_cloudwatch_logs(request_id, error_keywords)

        # Get X-Ray traces
        logger.info(f"Getting X-Ray traces for request {request_id}")
        trace_data = get_xray_traces(request_id)

        # Store trace data for correlation
        if trace_data:
            store_trace_data(request_id, {
                'traces': trace_data,
                'logs_count': len(log_entries)
            })

        # Set up async event loop for AI analysis
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        try:
            # Perform AI analysis
            logger.info(f"Starting AI analysis for request {request_id}")
            analysis_result = loop.run_until_complete(
                analyze_error_with_ai(request_id, error_description, log_entries, trace_data)
            )

            logger.info(f"AI analysis completed for request {request_id}")
        finally:
            # Clean up async resources
            try:
                pending = asyncio.all_tasks(loop)
                if pending:
                    logger.info(f"Cancelling {len(pending)} pending async tasks")
                    for task in pending:
                        task.cancel()

                    try:
                        loop.run_until_complete(
                            asyncio.wait_for(
                                asyncio.gather(*pending, return_exceptions=True),
                                timeout=5.0
                            )
                        )
                    except asyncio.TimeoutError:
                        logger.warning("Some tasks did not cancel within timeout")
            except Exception as e:
                logger.warning(f"Error cancelling pending tasks: {e}")

            try:
                loop.run_until_complete(loop.shutdown_asyncgens())
            except Exception as e:
                logger.warning(f"Error shutting down async generators: {e}")

            loop.close()

        # Prepare response
        response = {
            'requestId': request_id,
            'analysis': analysis_result,
            'logEntriesFound': len(log_entries),
            'tracesFound': len(trace_data),
            'timestamp': datetime.utcnow().isoformat()
        }

        return {
            "statusCode": 200,
            "body": json.dumps(response, default=str)
        }

    except Exception as e:
        logger.error(f"Error in error analyzer: {str(e)}")

        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            })
        }
