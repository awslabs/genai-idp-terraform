# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import logging
import os
import concurrent.futures

import boto3
from botocore.exceptions import ClientError

# Type: ignore for boto3 resource type inference
dynamodb = boto3.resource('dynamodb')  # type: ignore

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    """Process file copy jobs from SQS"""
    logger.info(f"File copier invoked with {len(event['Records'])} messages")

    for record in event['Records']:
        try:
            message = json.loads(record['body'])

            test_run_id = message['testRunId']
            test_set_id = message['testSetId']
            tracking_table = message['trackingTable']

            # Get environment variables
            test_set_bucket = os.environ['TEST_SET_BUCKET']
            input_bucket = os.environ['INPUT_BUCKET']
            baseline_bucket = os.environ['BASELINE_BUCKET']

            logger.info(f"Processing test run {test_run_id} for test set {test_set_id}")

            # List files from test set bucket
            input_files = _list_test_set_files(test_set_bucket, test_set_id, 'input')
            baseline_files = _list_test_set_files(test_set_bucket, test_set_id, 'baseline')

            if not input_files:
                raise ValueError(f"No input files found for test set: {test_set_id}")

            logger.info(f"Found {len(input_files)} input files and {len(baseline_files)} baseline files")

            # Update test run with file list and set status to IN_PROGRESS
            _update_tracking_in_progress(tracking_table, test_run_id, input_files)

            # Copy input files from test set bucket to input bucket with test_run_id prefix
            successful_input_files = _copy_files_to_bucket(
                test_set_bucket, f"{test_set_id}/input/",
                input_bucket, f"{test_run_id}/",
                input_files
            )

            # Copy baseline files from test set bucket to baseline bucket with test_run_id prefix
            successful_baseline_files = _copy_files_to_bucket(
                test_set_bucket, f"{test_set_id}/baseline/",
                baseline_bucket, f"{test_run_id}/",
                baseline_files
            )

            # Check if all files failed to copy
            if len(successful_input_files) == 0:
                raise ValueError("All input files failed to copy")

            # Check if all baseline files failed to copy
            if len(successful_baseline_files) == 0:
                raise ValueError("All baseline files failed to copy")

            # Update failed files count
            input_failed_count = len(input_files) - len(successful_input_files)

            if input_failed_count > 0:
                _update_test_run_status(tracking_table, test_run_id, None, failed_count=input_failed_count)

            logger.info(f"Completed file copying for test run {test_run_id}")

        except Exception as e:
            logger.error(f"Error processing test run {test_run_id}: {str(e)}")
            _update_test_run_status(tracking_table, test_run_id, 'FAILED', str(e))

    return {'statusCode': 200}

def _list_test_set_files(test_set_bucket, test_set_id, folder_type):
    """List files from test set bucket folder (input or baseline)"""
    try:
        prefix = f"{test_set_id}/{folder_type}/"
        response = s3.list_objects_v2(Bucket=test_set_bucket, Prefix=prefix)

        files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                # Skip folder itself, only get actual files
                if not obj['Key'].endswith('/'):
                    # Preserve full relative path after the folder_type prefix
                    relative_path = obj['Key'][len(prefix):]
                    files.append(relative_path)

        logger.info(f"Found {len(files)} {folder_type} files for test set {test_set_id}")
        return files

    except Exception as e:
        logger.error(f"Error listing {folder_type} files for test set {test_set_id}: {e}")
        return []

def _copy_files_to_bucket(source_bucket, source_prefix, dest_bucket, dest_prefix, files):
    """Copy files from source bucket to destination bucket - track failures"""
    successful_files = []

    for filename in files:
        try:
            source_key = f"{source_prefix}{filename}"
            dest_key = f"{dest_prefix}{filename}"

            # Copy file
            s3.copy_object(
                CopySource={'Bucket': source_bucket, 'Key': source_key},
                Bucket=dest_bucket,
                Key=dest_key
            )

            successful_files.append(filename)
            logger.info(f"Copied file: {source_key} -> {dest_bucket}/{dest_key}")

        except Exception as e:
            logger.error(f"Failed to copy file {filename}: {e}")

    return successful_files

def _update_tracking_in_progress(tracking_table, test_run_id, files):
    """Update test run with file list and set status to RUNNING"""
    table = dynamodb.Table(tracking_table)  # type: ignore
    try:
        table.update_item(
            Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'},
            UpdateExpression='SET Files = :files, #status = :status',
            ExpressionAttributeNames={'#status': 'Status'},
            ExpressionAttributeValues={
                ':files': files,
                ':status': 'RUNNING'
            }
        )
        logger.info(f"Updated test run {test_run_id} to RUNNING with {len(files)} files")
    except Exception as e:
        logger.error(f"Failed to update tracking for {test_run_id}: {e}")

def _update_test_run_status(tracking_table, test_run_id, status, error=None, failed_count=None):
    """Update test run status in tracking table"""
    try:
        table = dynamodb.Table(tracking_table)  # type: ignore
        update_expression_parts = []
        expression_attribute_names = {}
        expression_attribute_values = {}

        if status:
            update_expression_parts.append('#status = :status')
            expression_attribute_names['#status'] = 'Status'
            expression_attribute_values[':status'] = status

        if error:
            update_expression_parts.append('#error = :error')
            expression_attribute_names['#error'] = 'Error'
            expression_attribute_values[':error'] = error

        if failed_count is not None:
            update_expression_parts.append('BaselineFailedFiles = :failed_count')
            expression_attribute_values[':failed_count'] = failed_count

        if update_expression_parts:
            update_expression = 'SET ' + ', '.join(update_expression_parts)

            table.update_item(
                Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'},
                UpdateExpression=update_expression,
                ExpressionAttributeNames=expression_attribute_names if expression_attribute_names else None,
                ExpressionAttributeValues=expression_attribute_values
            )
            logger.info(f"Updated test run {test_run_id}")
    except Exception as e:
        logger.error(f"Failed to update test run status: {e}")
