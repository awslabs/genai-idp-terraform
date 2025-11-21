# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
import json
import boto3
import os
import urllib.request
import time

# Inline implementation of cfnresponse module
def send(event, context, response_status, response_data, physical_resource_id=None, no_echo=False):
    response_url = event.get('ResponseURL')
    if not response_url:
        print("No ResponseURL found in event")
        return
        
    response_body = {
        'Status': response_status,
        'Reason': f"See the details in CloudWatch Log Stream: {context.log_stream_name}",
        'PhysicalResourceId': physical_resource_id or context.log_stream_name,
        'StackId': event.get('StackId'),
        'RequestId': event.get('RequestId'),
        'LogicalResourceId': event.get('LogicalResourceId'),
        'NoEcho': no_echo,
        'Data': response_data
    }
    
    json_response_body = json.dumps(response_body)
    
    headers = {
        'Content-Type': '',
        'Content-Length': str(len(json_response_body))
    }
    
    req = urllib.request.Request(
        url=response_url,
        data=json_response_body.encode('utf-8'),
        headers=headers,
        method='PUT'
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Response status code: {response.getcode()}")
        print("Successfully sent response to CloudFormation")
    except Exception as e:
        print(f"Failed to send response to CloudFormation: {str(e)}")
        
SUCCESS = "SUCCESS"
FAILED = "FAILED"

def handler(event, context):
    user_pool_id = os.environ['USER_POOL_ID']
    client_id = os.environ['CLIENT_ID']
    workteam_name = os.environ['WORKTEAM_NAME']
    
    print(f"Event: {json.dumps(event)}")
    response_data = {}
    
    try:
        if event.get('RequestType') == 'Delete':
            print("Delete request - no action needed")
            send(event, context, SUCCESS, response_data)
            return
        
        # Ignore the SourceCodeHash property as it's only used to force updates
        _ = event['ResourceProperties'].get('SourceCodeHash')
        
        # Get workteam details to find the subdomain
        sagemaker = boto3.client('sagemaker')
        workteam_response = sagemaker.describe_workteam(
            WorkteamName=workteam_name
        )
        
        subdomain = workteam_response['Workteam'].get('SubDomain', '')
        if not subdomain:
            raise Exception(f"Could not find subdomain for workteam {workteam_name}")
        
        print(f"Found workteam subdomain: {subdomain}")
        workforceloginurl = f'https://{subdomain}/'
            
        # Get current client configuration
        cognito = boto3.client('cognito-idp')
        client_response = cognito.describe_user_pool_client(
            UserPoolId=user_pool_id,
            ClientId=client_id
        )
        
        current_client = client_response['UserPoolClient']
        
        # Update with new callback and logout URLs
        callback_url = f'https://{subdomain}/oauth2/idpresponse'
        logout_url = f'https://{subdomain}/logout'
        
        print(f"Setting callback URL: {callback_url}")
        print(f"Setting logout URL: {logout_url}")
        
        # Prepare all needed parameters for update
        update_params = {
            'UserPoolId': user_pool_id,
            'ClientId': client_id,
            'ClientName': current_client.get('ClientName', ''),
            'RefreshTokenValidity': current_client.get('RefreshTokenValidity', 30),
            'AllowedOAuthFlowsUserPoolClient': True,
            'AllowedOAuthFlows': ['code','implicit'],
            'AllowedOAuthScopes': ['email','openid','profile'],
            'CallbackURLs': [callback_url],
            'LogoutURLs': [logout_url],
            'SupportedIdentityProviders': ['COGNITO'],
        }
        
        # Add optional parameters if they exist in current config
        for param in ['ExplicitAuthFlows', 'AccessTokenValidity', 'IdTokenValidity', 'TokenValidityUnits', 'PreventUserExistenceErrors']:
            if param in current_client:
                update_params[param] = current_client[param]
        
        if 'GenerateSecret' in current_client and current_client['GenerateSecret']:
            update_params['GenerateSecret'] = True
        
        # Allow time for the private workteam to be fully created
        time.sleep(5)
        
        response = cognito.update_user_pool_client(**update_params)
        
        print(f"Successfully updated Cognito User Pool Client")
        response_data = {
            'ClientId': client_id,
            'CallbackURL': callback_url,
            'LogoutURL': logout_url,
            'WorkforceLogin': workforceloginurl
        }
        
        send(event, context, SUCCESS, response_data)
        
    except Exception as e:
        print(f"Error updating Cognito User Pool Client: {str(e)}")
        send(event, context, FAILED, {"Error": str(e)})
        raise
    
    return {
        'statusCode': 200,
        'body': json.dumps('Cognito User Pool Client updated successfully')
    }