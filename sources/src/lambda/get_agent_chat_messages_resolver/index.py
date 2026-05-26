# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Lambda function to get agent chat messages for a specific session.
This function queries the ChatMessagesTable by sessionId and returns messages in chronological order.
"""

import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")

# Get environment variables
CHAT_MESSAGES_TABLE = os.environ.get("CHAT_MESSAGES_TABLE")


def handler(event, context):
    """
    Get agent chat messages for a specific session.
    
    Args:
        event: The event dict from AppSync containing:
            - sessionId: The session ID to retrieve messages for
        context: The Lambda context
        
    Returns:
        List of AgentChatMessage objects
    """
    logger.info(f"Received get agent chat messages event: {json.dumps(event)}")
    
    try:
        # Extract arguments from the event
        arguments = event.get("arguments", {})
        session_id = arguments.get("sessionId")
        
        if not session_id:
            raise ValueError("sessionId parameter is required")
        
        # Get user identity from context for security
        identity = event.get("identity", {})
        user_id = identity.get("username") or identity.get("sub") or "anonymous"
        
        logger.info(f"Getting agent chat messages for session {session_id} (user: {user_id})")
        
        # Query the ChatMessagesTable for this specific session
        table = dynamodb.Table(CHAT_MESSAGES_TABLE)
        
        # Query by PK (sessionId) to get all messages for this session
        response = table.query(
            KeyConditionExpression="PK = :session_id",
            ExpressionAttributeValues={
                ":session_id": session_id
            },
            ScanIndexForward=True  # Sort by SK (timestamp) in ascending order
        )
        
        items = response.get("Items", [])
        
        # Convert DynamoDB items to AgentChatMessage format
        messages = []
        for item in items:
            message = {
                "role": item.get("role", ""),
                "content": item.get("content", ""),
                "timestamp": item.get("timestamp", ""),
                "isProcessing": item.get("isProcessing", False),
                "sessionId": item.get("PK", "")  # PK is the sessionId
            }
            messages.append(message)
        
        logger.info(f"Returning {len(messages)} messages for session {session_id}")
        return messages
        
    except ClientError as e:
        error_msg = f"DynamoDB error: {str(e)}"
        logger.error(error_msg)
        raise Exception(error_msg)
    except ValueError as e:
        # Re-raise validation errors so they become GraphQL errors
        logger.error(f"Validation error: {str(e)}")
        raise e
    except Exception as e:
        error_msg = f"Error getting agent chat messages: {str(e)}"
        logger.error(error_msg)
        raise Exception(error_msg)
