#!/usr/bin/env python3
"""
Pure Terraform training status checker.
This script polls the Lambda function to check training job completion.
"""

import json
import sys
import boto3
import time

def main():
    # Read input from stdin
    input_data = json.loads(sys.stdin.read())
    
    job_name = input_data.get('job_name')
    max_attempts = int(input_data.get('max_attempts', 60))
    
    # Configuration from template
    function_name = "${function_name}"
    region = "${region}"
    
    if not job_name:
        result = {
            'status': 'error',
            'error': 'job_name is required',
            'attempts': '0',
            'message': 'No job name provided for status checking'
        }
        print(json.dumps(result))
        return
    
    # Initialize Lambda client
    lambda_client = boto3.client('lambda', region_name=region)
    
    # Poll for completion
    attempt = 0
    
    while attempt < max_attempts:
        try:
            # Invoke the is_complete function with simplified payload
            response = lambda_client.invoke(
                FunctionName=function_name,
                Payload=json.dumps({
                    'JobName': job_name
                })
            )
            
            # Parse response
            payload = json.loads(response['Payload'].read())
            
            if payload.get('IsComplete', False):
                # Training is complete
                status = payload.get('Status', 'Unknown')
                result = {
                    'status': 'complete',
                    'attempts': str(attempt + 1),
                    'message': f'Training job completed with status: {status}',
                    'job_status': status
                }
                
                # Add failure reason if job failed
                if 'FailureReason' in payload:
                    result['failure_reason'] = payload['FailureReason']
                    result['message'] = f'Training job failed: {payload["FailureReason"]}'
                
                # Add model artifacts if available
                if 'ModelArtifactsS3Uri' in payload:
                    result['model_artifacts'] = payload['ModelArtifactsS3Uri']
                
                print(json.dumps(result))
                return
            
            # Wait before next attempt (30 seconds)
            if attempt < max_attempts - 1:  # Don't sleep on last attempt
                time.sleep(30)
            attempt += 1
            
        except Exception as e:
            # Return error status
            result = {
                'status': 'error',
                'error': str(e),
                'attempts': str(attempt + 1),
                'message': f'Error checking training status: {str(e)}'
            }
            print(json.dumps(result))
            return
    
    # Timeout reached
    result = {
        'status': 'timeout',
        'attempts': str(attempt),
        'message': f'Training job did not complete within {max_attempts * 30 / 60} minutes'
    }
    print(json.dumps(result))

if __name__ == '__main__':
    main()
