"""
Lambda function for saving document evaluation data to the reporting bucket in Parquet format.
"""

import json
import logging
import traceback
from typing import Dict, Any, List

from idp_common.models import Document
from idp_common.reporting import SaveReportingData

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda handler for saving document evaluation data to the reporting bucket.
    
    Args:
        event: Lambda event containing document data, reporting bucket name, and data_to_save
        context: Lambda context
        
    Returns:
        Dict with status and message
    """
    logger.info(f"Starting save_reporting_data process with event: {json.dumps(event, indent=2)}")
    
    try:
        # Extract parameters from the event
        document_dict = event.get('document')
        reporting_bucket = event.get('reporting_bucket')
        data_to_save = event.get('data_to_save', [])
        
        if not document_dict:
            error_msg = "No document data provided in the event"
            logger.error(error_msg)
            return {
                'statusCode': 400,
                'body': error_msg
            }
            
        if not reporting_bucket:
            error_msg = "No reporting bucket specified in the event"
            logger.error(error_msg)
            return {
                'statusCode': 400,
                'body': error_msg
            }
            
        if not data_to_save:
            warning_msg = "No data_to_save specified in the event, nothing to do"
            logger.warning(warning_msg)
            return {
                'statusCode': 200,
                'body': warning_msg
            }
            
        # Convert document dict to Document object
        document = Document.from_dict(document_dict)
        
        # Use the SaveReportingData class to save the data
        reporter = SaveReportingData(reporting_bucket)
        results = reporter.save(document, data_to_save)
        
        # If no data was processed, return a warning
        if not results:
            return {
                'statusCode': 200,
                'body': "No data was processed - check data_to_save parameter"
            }
        
        # Return success if all operations completed
        return {
            'statusCode': 200,
            'body': "Successfully saved data to reporting bucket"
        }
        
    except Exception as e:
        error_msg = f"Error saving data to reporting bucket: {str(e)}"
        logger.error(error_msg)
        # Log the full stack trace for better debugging
        logger.error(f"Stack trace: {traceback.format_exc()}")
        
        return {
            'statusCode': 500,
            'body': error_msg
        }
