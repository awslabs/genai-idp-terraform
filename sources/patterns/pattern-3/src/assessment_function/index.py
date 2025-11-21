# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import os
import json
import time
import logging

from idp_common import get_config, assessment
from idp_common.models import Document, Status
from idp_common.docs_service import create_document_service

# Configuration will be loaded in handler function

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))
logging.getLogger('idp_common.bedrock.client').setLevel(os.environ.get("BEDROCK_LOG_LEVEL", "INFO"))

def handler(event, context):
    """
    Lambda handler for document assessment.
    This function assesses the confidence of extraction results for a document section
    using the Assessment service from the idp_common library.
    """
    logger.info(f"Starting assessment processing for event: {json.dumps(event, default=str)}")

    # Load configuration
    config = get_config()
    logger.info(f"Config: {json.dumps(config)}")
    
    # Extract input from event - handle both compressed and uncompressed
    document_data = event.get('document', {})
    section_id = event.get('section_id')
    
    # Validate inputs
    if not document_data:
        raise ValueError("No document provided in event")
        
    if not section_id:
        raise ValueError("No section_id provided in event")
        
    # Convert document data to Document object - handle compression
    working_bucket = os.environ.get('WORKING_BUCKET')
    document = Document.load_document(document_data, working_bucket, logger)
    document.status = Status.ASSESSING
    logger.info(f"Processing assessment for document {document.id}, section {section_id}")

    # Update document status to ASSESSING for UI only
    # Create new 'shell' document since our input document has only 1 section. 
    docStatus = Document(
        id=document.id,
        input_key=document.input_key,
        status=Status.ASSESSING,
    )
    document_service = create_document_service()
    logger.info(f"Updating document status to {docStatus.status}")
    document_service.update_document(docStatus)

    # Initialize assessment service
    assessment_service = assessment.AssessmentService(config=config)

    # Process the document section for assessment
    t0 = time.time()
    logger.info(f"Starting assessment for section {section_id}")
    updated_document = assessment_service.process_document_section(document, section_id)
    t1 = time.time()
    logger.info(f"Total extraction time: {t1-t0:.2f} seconds")

    # Check if document processing failed
    if updated_document.status == Status.FAILED:
        error_message = f"Assessment failed for document {updated_document.id}, section {section_id}"
        logger.error(error_message)
        raise Exception(error_message)
    
    # Prepare output with automatic compression if needed
    result = {
        'document': updated_document.serialize_document(working_bucket, f"assessment_{section_id}", logger),
        'section_id': section_id
    }
    
    logger.info("Assessment processing completed")
    return result
