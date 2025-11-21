# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3
import json
import os
import logging
import datetime
import re
from collections import defaultdict
from decimal import Decimal
from botocore.exceptions import ClientError
from idp_common.s3 import get_s3_client, write_content

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
stepfunctions = boto3.client('stepfunctions')
s3_client = boto3.client('s3')

def unflatten(data: dict) -> dict:
    """
    Convert flattened dictionary keys with array notation (e.g., 'a.b[0].c')
    into nested dictionaries/lists.
    """
    result = defaultdict(lambda: defaultdict(dict))
    array_pattern = re.compile(r"^(.*?)\[(\d+)\]$")

    for key, value in data.items():
        current = result
        parts = key.split('.')
        for i, part in enumerate(parts):
            arr_match = array_pattern.match(part)
            if arr_match:
                base_name = arr_match.group(1)
                idx = int(arr_match.group(2))
                if base_name not in current:
                    current[base_name] = []
                while len(current[base_name]) <= idx:
                    current[base_name].append(defaultdict(dict))
                if i == len(parts) - 1:
                    current[base_name][idx] = value
                else:
                    current = current[base_name][idx]
            else:
                if i == len(parts) - 1:
                    current[part] = value
                else:
                    if part not in current:
                        current[part] = defaultdict(dict)
                    current = current[part]

    def convert(obj):
        if isinstance(obj, defaultdict):
            return {k: convert(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert(item) for item in obj]
        return obj

    return convert(result)

def deep_merge(target, source):
    """
    Recursively merge two nested dictionaries/lists.
    """
    if isinstance(target, dict) and isinstance(source, dict):
        for key, value in source.items():
            if key in target:
                target[key] = deep_merge(target[key], value)
            else:
                target[key] = value
        return target
    elif isinstance(target, list) and isinstance(source, list):
        merged = []
        max_len = max(len(target), len(source))
        for i in range(max_len):
            t = target[i] if i < len(target) else {}
            s = source[i] if i < len(source) else {}
            merged.append(deep_merge(t, s))
        return merged
    else:
        return source

def convert_type(value, data_type):
    """
    Convert value to the specified data_type for explainability_info.
    """
    if value == 'None':
        return None if data_type != 'string' else ''
    if data_type == 'boolean':
        return str(value).lower() in ('true', '1', 'yes')
    if data_type == 'number':
        try:
            return Decimal(str(value)) if '.' in str(value) else int(value)
        except Exception:
            return value
    return value

def sync_explainability(inference_data, explainability_info):
    """
    Update explainability_info with values from inference_data, preserving types.
    """
    if isinstance(explainability_info, list):
        if isinstance(inference_data, list):
            return [
                sync_explainability(inference_data[i], explainability_info[i])
                if i < len(inference_data) else explainability_info[i]
                for i in range(len(explainability_info))
            ]
        else:
            return [sync_explainability(inference_data, item) for item in explainability_info]

    if isinstance(explainability_info, dict):
        updated = {}
        for key, meta in explainability_info.items():
            if isinstance(meta, dict) and 'value' in meta:
                if key in inference_data:
                    updated[key] = {
                        **meta,
                        'value': convert_type(inference_data[key], meta.get('type'))
                    }
                else:
                    updated[key] = meta
            elif isinstance(meta, (dict, list)) and key in inference_data:
                updated[key] = sync_explainability(inference_data[key], meta)
            else:
                updated[key] = meta
        return updated
    return explainability_info

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def update_token_status(token_id, status, tracking_table):
    """Update the status of a token in the tracking table"""
    try:
        tracking_table.update_item(
            Key={
                'PK': token_id,
                'SK': 'none'
            },
            UpdateExpression="SET #status = :status, UpdatedAt = :updated_at",
            ExpressionAttributeNames={
                '#status': 'Status'
            },
            ExpressionAttributeValues={
                ':status': status,
                ':updated_at': datetime.datetime.now().isoformat()
            }
        )
        logger.info(f"Updated token {token_id} status to {status}")
    except Exception as e:
        logger.error(f"Error updating token status: {str(e)}")

def check_all_sections_complete(document_id, tracking_table):
    """Check if all sections for this document are complete"""
    try:
        # Query for all section tokens for this document
        response = tracking_table.scan(
            FilterExpression="begins_with(PK, :prefix) AND TokenType = :type",
            ExpressionAttributeValues={
                ':prefix': f"HITL#{document_id}#section#",
                ':type': 'HITL_SECTION'
            }
        )
        
        sections = response.get('Items', [])
        logger.info(f"check_all_sections_complete_sections: {sections}")
        
        if not sections:
            return False
        
        # Check if all sections have status COMPLETED
        for section in sections:
            if section.get('Status') != 'COMPLETED':
                return False
        
        return True
    except Exception as e:
        logger.error(f"Error checking section completion status: {str(e)}")
        return False



def get_section_blueprint_changes(document_id, section_id, metadata_table, execution_id):
    """Check if any blueprint changes occurred in this section."""
    try:
        response = metadata_table.get_item(
            Key={
                'execution_id': execution_id,
                'record_number': int(section_id)
            }
        )
        
        if 'Item' in response:
            item = response['Item']
            if item.get('hitl_bp_change') is not None:
                return True, item.get('hitl_bp_change')
        
        return False, None
    except Exception as e:
        logger.error(f"Error checking blueprint changes: {str(e)}")
        return False, None

def update_token_status(token_id, status, tracking_table):
    """Update the status of a token in the tracking table"""
    try:
        tracking_table.update_item(
            Key={
                'PK': token_id,
                'SK': 'none'
            },
            UpdateExpression="SET #status = :status, UpdatedAt = :updated_at",
            ExpressionAttributeNames={
                '#status': 'Status'
            },
            ExpressionAttributeValues={
                ':status': status,
                ':updated_at': datetime.datetime.now().isoformat()
            }
        )
        logger.info(f"Updated token {token_id} status to {status}")
    except Exception as e:
        logger.error(f"Error updating token status: {str(e)}")

def check_all_pages_complete(document_id, section_id, tracking_table):
    """Check if all pages in a section are complete"""
    try:
        # Query for all page tokens for this document and section
        response = tracking_table.scan(
            FilterExpression="begins_with(PK, :prefix) AND TokenType = :type",
            ExpressionAttributeValues={
                ':prefix': f"HITL#{document_id}#section#{section_id}#page#",
                ':type': 'HITL_PAGE'
            }
        )
        logger.info(f"check_all_pages_complete: {response}")
        
        items = response.get('Items', [])
        
        logger.info(f"check_all_pages_complete_items: {items}")
        
        if not items:
            return False
        
        # Check if all items have status COMPLETED
        for item in items:
            if item.get('Status') != 'COMPLETED':
                return False
        
        return True
    except Exception as e:
        logger.error(f"Error checking page completion status: {str(e)}")
        return False

        
def find_doc_task_token(document_id, tracking_table):
    """Find any record with a task token for this document"""
    try:
        response = tracking_table.scan(
            FilterExpression="begins_with(PK, :prefix) AND TokenType = :type AND attribute_exists(TaskToken)",
            ExpressionAttributeValues={
                ':prefix': f"HITL#TaskToken#{document_id}", 
                ':type': 'HITL_DOC'
            }
        )
        
        items = response.get('Items', [])
        logger.info(f"Task token items: {items}")
        
        if items:
            return items[0].get('TaskToken')
    
        return None
    except Exception as e:
        logger.error(f"Error finding section task token: {str(e)}")
        return None


def lambda_handler(event, context):
    """
    AWS Lambda entry point.
    - Loads HITL output from S3.
    - Merges human corrections with existing inference results.
    - Updates explainability info.
    - Saves the updated record to DynamoDB.
    - If blueprint selection changes, sends a message to SQS.
    - Updates page task token status.
    - Checks if all pages in a section are complete and updates section status.
    """
    logger.info(f"Processing event: {json.dumps(event)}")
    
    dynamodb = boto3.resource('dynamodb')
    # sqs_client = boto3.client('sqs')  # Initialize SQS client
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
    tracking_table = dynamodb.Table(os.environ['TRACKING_TABLE'])
    # sqs_queue_url = os.environ['SQS_QUEUE_URL']  # Get SQS queue URL from env

    try:
        detail = event.get('detail', {})
        if detail.get('humanLoopStatus') != 'Completed':
            return {"statusCode": 200, "body": "Human loop not completed"}

        # Parse A2I output from S3
        output_s3_uri = detail['humanLoopOutput']['outputS3Uri']
        bucket, key = output_s3_uri.replace("s3://", "").split("/", 1)
        response = s3_client.get_object(Bucket=bucket, Key=key)
        output_data = json.loads(response['Body'].read())

        logger.info(f"output_data: {output_data}")
        # Extract required fields
        input_content = output_data['inputContent']
        human_answers = output_data['humanAnswers'][0]['answerContent']
        execution_id = input_content['execution_id']
        record_id = input_content['record_id']
        page_id = input_content.get('page_number') - 1
        

        # Get blueprint info
        answer_bp = human_answers.get('blueprintSelection')
        input_bp = input_content.get('blueprintName')

        # Fetch existing record from DynamoDB
        db_response = table.get_item(
            Key={'execution_id': execution_id, 'record_number': record_id}
        )
        db_item = db_response['Item']
        document_id = db_item.get('object_key', {})

        # If blueprint matches, update inference result in DynamoDB
        if (answer_bp is not None and input_bp is not None and answer_bp == input_bp) or (answer_bp is None):
            existing_result = db_item.get('hitl_corrected_result', {})
            output_bucket = db_item.get('output_bucket', {})
            object_key = db_item.get('object_key', {})
            s3_record_id = record_id - 1
            output_object_key = f"{object_key}/sections/{s3_record_id}/"

            # Process and merge human answers
            nested_update = unflatten(human_answers)
            merged_inference = deep_merge(
                existing_result.get('inference_result', {}),
                nested_update
            )

            # Update explainability info
            explainability = existing_result.get('explainability_info', [])
            updated_explainability = sync_explainability(merged_inference, explainability)

            # Prepare and write update to DynamoDB
            final_update = {
                **existing_result,
                'inference_result': merged_inference,
                'explainability_info': updated_explainability
            }

            table.update_item(
                Key={'execution_id': execution_id, 'record_number': record_id},
                UpdateExpression='SET hitl_corrected_result = :val',
                ExpressionAttributeValues={':val': final_update},
                ReturnValues='UPDATED_NEW'
            )
            
            result_json_key = output_object_key + 'result.json'
            try:
                s3_response = s3_client.get_object(Bucket=output_bucket, Key=result_json_key)
                existing_json = json.loads(s3_response['Body'].read(), parse_float=Decimal)
            except s3_client.exceptions.NoSuchKey:
                existing_json = {}
            except Exception as e:
                logger.error(f"Error reading existing result.json: {e}")
                existing_json = {}

            merged_json = deep_merge(existing_json, final_update)
            json_string = json.dumps(merged_json, default=decimal_default)

            write_content(
                json_string,
                output_bucket,
                result_json_key,
                content_type='application/json'
            )

            logger.info(f"Successfully updated record {execution_id}/{record_id}")

        # If blueprint selection is changed, send message to SQS and update DynamoDB
        elif answer_bp is not None:
            # message_body = json.dumps({
            #     'execution_id': execution_id,
            #     'record_id': record_id,
            #     'bp_change_name': answer_bp
            # })

            # sqs_response = sqs_client.send_message(
            #     QueueUrl=sqs_queue_url,
            #     MessageBody=message_body
            # )

            table.update_item(
                Key={'execution_id': execution_id, 'record_number': record_id},
                UpdateExpression='SET hitl_bp_change = :bp, hitl_corrected_result = :result',
                ExpressionAttributeValues={
                    ':bp': answer_bp,
                    ':result': None  # or {} if you want an empty dict instead of None
                },
                ReturnValues='UPDATED_NEW'
            )

            logger.info(f"Successfully updated record {execution_id}/{record_id} for Blueprint change")
            # logger.info(f"Message body: {message_body}")
            # logger.info(f"Message sent to SQS: {sqs_response}")

        # If blueprint value is missing, raise error
        else:
            raise ValueError("Blueprint Value is null and need to review error manual")

        logger.info(f"DocumentID: {document_id}")
        logger.info(f"page_id: {page_id}")
        # Update page task token status
        if document_id is not None and page_id is not None:
            page_token_id = f"HITL#{document_id}#section#{record_id}#page#{page_id}"
            update_token_status(page_token_id, "COMPLETED", tracking_table)
            
            # Check if all pages in this section are complete
            all_pages_complete = check_all_pages_complete(document_id, record_id, tracking_table)
            logger.info(f"all_pages_complete status: {all_pages_complete}")
            
            if all_pages_complete:
                # Update section token status to COMPLETED
                section_token_id = f"HITL#{document_id}#section#{record_id}"
                update_token_status(section_token_id, "COMPLETED", tracking_table)
                
                # Check if all sections for this document are complete
                all_sections_complete = check_all_sections_complete(document_id, tracking_table)
                
                if all_sections_complete:
                    # Find any section with a task token
                    section_task_token = find_doc_task_token(document_id, tracking_table)
                    blueprint_changes = []
                    
                    if section_task_token:
                        # Check if any blueprint changes were made in BDA metadata table
                        response = table.query(
                            KeyConditionExpression="execution_id = :eid",
                            ExpressionAttributeValues={
                                ":eid": execution_id
                            }
                        )
                        
                        for item in response.get('Items', []):
                            if item.get('hitl_bp_change') is not None:
                                blueprint_changes.append({
                                    'record_id': item.get('record_number'),
                                    'original_blueprint': item.get('blueprint_name', ''),
                                    'new_blueprint': item.get('hitl_bp_change')
                                })
                        
                        # Send task success to resume the Step Function
                        try:
                            stepfunctions.send_task_success(
                                taskToken=section_task_token,
                                output=json.dumps({
                                    "status": "completed",
                                    "executionId": execution_id,
                                    "message": "All human reviews completed",
                                    "blueprintChanged": len(blueprint_changes) > 0
                                })
                            )
                            logger.info(f"Sent task success for execution {execution_id}")
                            
                            # Update document tracking record to clear HITL review URL
                            tracking_table.update_item(
                                Key={
                                    'PK': f"document#{document_id}",
                                    'SK': 'metadata'
                                },
                                UpdateExpression="SET HITLStatus = :status, HITLCompletionTime = :time, HITLReviewURL = :url",
                                ExpressionAttributeValues={
                                    ':status': "COMPLETED",
                                    ':time': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                                    ':url': None  # Clear the URL when HITL is complete
                                }
                            )
                            
                            # Update main document status back to COMPLETED
                            # Also update the HITL metadata fields in the main record
                            tracking_table.update_item(
                                Key={
                                    'PK': f"doc#{document_id}",
                                    'SK': 'none'
                                },
                                UpdateExpression="SET ObjectStatus = :status, HITLStatus = :hitlStatus, HITLReviewURL = :url",
                                ExpressionAttributeValues={
                                    ':status': "COMPLETED",
                                    ':hitlStatus': "COMPLETED",
                                    ':url': None  # Clear the URL when HITL is complete
                                }
                            )
                        except Exception as e:
                            logger.error(f"Error sending task success: {str(e)}")

        return {"statusCode": 200, "body": "Processing completed successfully"}
    except ClientError as e:
        logger.error(f"DynamoDB: {e.response['Error']['Message']}")
        return {"statusCode": 500, "body": "Database"}
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {"statusCode": 500, "body": "Processing failed"}
