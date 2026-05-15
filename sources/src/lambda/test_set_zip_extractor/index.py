# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import logging
import os
import zipfile
import tempfile

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    """Process S3 events for uploaded ZIP files"""
    logger.info(f"Zip extractor invoked with {len(event['Records'])} S3 events")
    
    for record in event['Records']:
        try:
            # Parse S3 event
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Extract test set ID from key (key format: test_set_id/test_set_id.zip)
            if '/' in key and key.endswith('.zip'):
                test_set_id = key.split('/')[0]  # Get the folder name
                zip_key = key  # Full path to ZIP file
            else:
                # Fallback for old format
                test_set_id = key
                zip_key = key
            
            logger.info(f"Processing zip extraction for test set: {test_set_id}, key: {key}")
            
            # Extract the uploaded ZIP file
            file_count = _extract_uploaded_zip(bucket, test_set_id, zip_key)
            
            # Update test set status to COMPLETED with file count
            _update_test_set_status(test_set_id, 'COMPLETED', None, file_count)
            
            logger.info(f"Successfully processed zip extraction for test set {test_set_id}")
            
        except Exception as e:
            logger.error(f"Error processing S3 event: {str(e)}")
            # Update test set status to FAILED
            _update_test_set_status(test_set_id, 'FAILED', str(e))

    
    return {'statusCode': 200}

def _extract_uploaded_zip(bucket, test_set_id, zip_key):
    """Extract uploaded ZIP file and organize into input/ and baseline/ folders"""
    
    # Download ZIP file to temporary location
    with tempfile.NamedTemporaryFile() as temp_file:
        s3.download_fileobj(bucket, zip_key, temp_file)
        temp_file.seek(0)
        
        # Extract ZIP contents
        with zipfile.ZipFile(temp_file, 'r') as zip_ref:
            # Validate zip structure and extract files
            input_files = []
            baseline_files = []
            input_names = set()
            baseline_names = set()
            
            for file_info in zip_ref.infolist():
                if not file_info.is_dir():
                    file_path = file_info.filename
                    
                    # Check if file is in input/ or baseline/ folder
                    if '/input/' in file_path:
                        input_files.append(file_info)
                        # Extract filename for matching
                        filename = file_path.split('/')[-1]
                        input_names.add(filename)
                    elif '/baseline/' in file_path:
                        baseline_files.append(file_info)
                        # Extract folder name after /baseline/ for matching
                        parts = file_path.split('/baseline/', 1)
                        if len(parts) == 2 and '/' in parts[1]:
                            # Handle nested structure: baseline/category/filename.pdf/sections/...
                            path_parts = parts[1].split('/')
                            if len(path_parts) >= 2:
                                # Look for the .pdf file (second level folder)
                                for part in path_parts:
                                    if part.endswith('.pdf'):
                                        baseline_names.add(part)
                                        break
                    else:
                        logger.warning(f"Skipping file not in input/ or baseline/ folder: {file_path}")
            
            if not input_files:
                raise ValueError(f"No files found in input/ folder within zip file")
            
            if not baseline_files:
                raise ValueError(f"No files found in baseline/ folder within zip file")
            
            # Validate file count and names match
            # Check that each input file has a corresponding baseline file
            missing_baselines = input_names - baseline_names
            if missing_baselines:
                raise ValueError(f"Missing baseline files for: {', '.join(missing_baselines)}")
            
            extra_baselines = baseline_names - input_names
            if extra_baselines:
                raise ValueError(f"Extra baseline files without corresponding input: {', '.join(extra_baselines)}")
            
            logger.info(f"Validation passed: {len(input_names)} input documents match {len(baseline_names)} baseline documents")
            
            # Extract input files
            for file_info in input_files:
                file_content = zip_ref.read(file_info.filename)
                
                # Extract relative path after /input/
                parts = file_info.filename.split('/input/', 1)
                if len(parts) == 2:
                    relative_path = parts[1]
                    dest_key = f"{test_set_id}/input/{relative_path}"
                    
                    s3.put_object(
                        Bucket=bucket,
                        Key=dest_key,
                        Body=file_content
                    )
                    
                    logger.info(f"Extracted input file: {file_info.filename} -> {dest_key}")
            
            # Extract baseline files
            for file_info in baseline_files:
                file_content = zip_ref.read(file_info.filename)
                
                # Extract relative path after /baseline/
                parts = file_info.filename.split('/baseline/', 1)
                if len(parts) == 2:
                    relative_path = parts[1]
                    dest_key = f"{test_set_id}/baseline/{relative_path}"
                    
                    s3.put_object(
                        Bucket=bucket,
                        Key=dest_key,
                        Body=file_content
                    )
                    
                    logger.info(f"Extracted baseline file: {file_info.filename} -> {dest_key}")
    
    # Delete original ZIP file
    s3.delete_object(Bucket=bucket, Key=zip_key)
    logger.info(f"Deleted original ZIP file: {zip_key}")
    
    # Return file count for status update
    return len(input_files)

def _update_test_set_status(test_set_id, status, error=None, file_count=None):
    """Update test set status and optionally file count in tracking table"""
    table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore
    
    try:
        update_expression = 'SET #status = :status'
        expression_values = {':status': status}
        expression_names = {'#status': 'status'}
        
        if error:
            update_expression += ', #error = :error'
            expression_values[':error'] = error
            expression_names['#error'] = 'error'
        
        if file_count is not None:
            update_expression += ', fileCount = :count'
            expression_values[':count'] = file_count
        
        table.update_item(
            Key={'PK': f'testset#{test_set_id}', 'SK': 'metadata'},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expression_names,
            ExpressionAttributeValues=expression_values
        )
        
        logger.info(f"Updated test set {test_set_id} status to {status}" + 
                   (f" with {file_count} files" if file_count else ""))
        
    except Exception as e:
        logger.error(f"Failed to update test set status for {test_set_id}: {e}")
