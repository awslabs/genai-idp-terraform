# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import json
import boto3
import os
from typing import Any, Dict, Union

def convert_floats_to_strings(obj: Any) -> Any:
    """
    Convert numeric values (float and int) to strings to avoid decimal serialization issues
    downstream while maintaining DynamoDB compatibility
    """
    if isinstance(obj, (float, int)):
        return str(obj)
    elif isinstance(obj, dict):
        return {key: convert_floats_to_strings(value) for key, value in obj.items()}
    elif isinstance(obj, list):
        return [convert_floats_to_strings(item) for item in obj]
    else:
        return obj

def lambda_handler(event, context):
    """
    Single seeder function for both Default config and Schema.
    
    Expected event payload:
    {
        "Key": "Default|Schema",
        "Value": { ... pure JSON object ... }
    }
    
    Stores items with structure matching reference solution:
    - For Default: { 'Configuration': 'Default', **value } (spread as top-level)
    - For Schema: { 'Configuration': 'Schema', 'Schema': value } (nested under Schema key)
    """
    try:
        key = event['Key']  # 'Default' or 'Schema'
        value = event['Value']  # JSON object to store
        table_name = os.environ['TABLE_NAME']
        
        # Validate key
        if key not in ['Default', 'Schema']:
            raise ValueError(f"Invalid key: {key}. Must be 'Default' or 'Schema'")
        
        # Convert floats to strings to avoid downstream serialization issues
        converted_data = convert_floats_to_strings(value)
        
        # Create DynamoDB item with structure matching reference solution
        if key == 'Schema':
            # For Schema: store the schema definition under a 'Schema' attribute
            dynamodb_item = {
                'Configuration': key,
                'Schema': converted_data
            }
        else:
            # For Default: spread data as top-level attributes
            dynamodb_item = {
                'Configuration': key,
                **converted_data
            }
        
        # Put item to DynamoDB using resource interface (like existing solution)
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        response = table.put_item(Item=dynamodb_item)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully stored {key}',
                'key': key,
                'response': response
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': f'Failed to store {event.get("Key", "unknown")}'
            })
        }
