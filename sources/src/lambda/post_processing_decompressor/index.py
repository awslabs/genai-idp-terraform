# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3
import json
import os
import logging
from idp_common.models import Document
from typing import Dict, Any

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

lambda_client = boto3.client('lambda')

CUSTOM_POST_PROCESSOR_ARN = os.environ['CUSTOM_POST_PROCESSOR_ARN']
WORKING_BUCKET = os.environ['WORKING_BUCKET']


def handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Decompresses documents from StepFunction input and output, then invokes custom post-processor lambda.
    
    This lambda acts as an intermediary between EventBridge and the custom post-processing lambda,
    handling document decompression so external lambdas don't need to import idp_common.
    
    Args:
        event: EventBridge event containing StepFunction execution details
        context: Lambda context
        
    Returns:
        Response from custom post-processor lambda invocation
    """
    logger.info(f"Processing event for custom post-processor invocation")
    
    try:
        input_decompressed = False
        output_decompressed = False
        
        # Decompress input document if present and compressed
        if event.get('detail', {}).get('input'):
            input_data = json.loads(event['detail']['input'])
            
            # Extract document from input
            input_doc_data = input_data.get('document')
            if input_doc_data and isinstance(input_doc_data, dict) and input_doc_data.get('compressed', False):
                logger.info(f"Input document is compressed, decompressing from S3 URI: {input_doc_data.get('s3_uri', 'N/A')}")
                
                # Decompress document using idp_common
                processed_doc = Document.load_document(input_doc_data, WORKING_BUCKET, logger)
                
                logger.info(f"Decompressed input document: {processed_doc.num_pages} pages")
                
                # Update input_data with decompressed document
                input_data['document'] = processed_doc.to_dict()
                event['detail']['input'] = json.dumps(input_data)
                input_decompressed = True
        
        # Decompress output document if present and compressed
        output_data = None
        if event.get('detail', {}).get('output'):
            output_data = json.loads(event['detail']['output'])
        
        if not output_data:
            logger.error("No output data found in event")
            raise ValueError("Missing output data in event")
        
        # Extract document data - handle both Pattern 1 and Pattern 2/3 structures
        document_data = None
        if 'document' in output_data:
            # Pattern 2/3 structure: at root level
            document_data = output_data['document']
            logger.info("Found document in output_data['document']")
        elif 'Result' in output_data and 'document' in output_data.get('Result', {}):
            # Pattern 1 structure: wrapped in Result
            document_data = output_data['Result']['document']
            logger.info("Found document in output_data['Result']['document']")
        else:
            logger.warning("Document not found in expected locations, using entire output")
            document_data = output_data
        
        # Check if document is compressed
        is_compressed = isinstance(document_data, dict) and document_data.get('compressed', False)
        
        if is_compressed:
            logger.info(f"Output document is compressed, decompressing from S3 URI: {document_data.get('s3_uri', 'N/A')}")
            
            # Decompress document using idp_common
            processed_doc = Document.load_document(document_data, WORKING_BUCKET, logger)
            
            logger.info(f"Decompressed output document: {processed_doc.num_pages} pages, "
                       f"{len(processed_doc.sections)} sections")
            
            # Reconstruct output_data with decompressed document
            if 'document' in output_data:
                output_data['document'] = processed_doc.to_dict()
            elif 'Result' in output_data and 'document' in output_data.get('Result', {}):
                output_data['Result']['document'] = processed_doc.to_dict()
            else:
                output_data = processed_doc.to_dict()
            
            # Update event with decompressed payload
            event['detail']['output'] = json.dumps(output_data)
            output_decompressed = True
            
            logger.info("Output document decompressed successfully")
        else:
            logger.info("Output document is not compressed, passing through as-is")
        
        # Invoke custom post-processor lambda with decompressed payload
        logger.info(f"Invoking custom post-processor: {CUSTOM_POST_PROCESSOR_ARN}")
        
        response = lambda_client.invoke(
            FunctionName=CUSTOM_POST_PROCESSOR_ARN,
            InvocationType='Event',  # Async invocation
            Payload=json.dumps(event)
        )
        
        logger.info(f"Custom post-processor invoked successfully. StatusCode: {response['StatusCode']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully invoked custom post-processor',
                'customProcessorArn': CUSTOM_POST_PROCESSOR_ARN,
                'inputDecompressed': input_decompressed,
                'outputDecompressed': output_decompressed
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}", exc_info=True)
        raise
