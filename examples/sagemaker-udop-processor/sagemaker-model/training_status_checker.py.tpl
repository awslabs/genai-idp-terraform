#!/usr/bin/env python3
"""
Pure Terraform training status checker.
This script polls the Lambda function to check training job completion.
"""

import json
import sys
import time

try:
    import boto3
except ImportError:
    # Provide helpful error message with installation instructions
    result = {
        'status': 'error',
        'error': 'boto3 not installed',
        'attempts': '0',
        'message': 'boto3 is required but not installed. Please install it with: pip install boto3'
    }
    print(json.dumps(result))
    sys.exit(1)

def main():
    # Read input from environment variables (Terraform external data source)
    import os
    
    job_name = os.environ.get('job_name')
    max_attempts = int(os.environ.get('max_attempts', 60))
    
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
    
    try:
        # Initialize Lambda client with explicit error handling
        lambda_client = boto3.client('lambda', region_name=region)
        
        # Test AWS credentials first
        sts_client = boto3.client('sts', region_name=region)
        identity = sts_client.get_caller_identity()
        
    except Exception as e:
        result = {
            'status': 'error',
            'error': f'AWS credentials or client initialization failed: {str(e)}',
            'attempts': '0',
            'message': f'Failed to initialize AWS clients. Check credentials and permissions: {str(e)}'
        }
        print(json.dumps(result))
        return
    
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
