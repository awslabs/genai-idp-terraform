import boto3
import json
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Initialize SageMaker client
sagemaker_client = boto3.client('sagemaker')

def lambda_handler(event, context):
    """
    Simplified Lambda handler for checking SageMaker training job completion.
    
    Expected event structure:
    {
        "JobName": "training-job-name"
    }
    
    OR for compatibility with polling script:
    {
        "JobNamePrefix": "job-prefix",
        "RequestId": "request-id"  # Used to construct job name
    }
    
    Returns:
    {
        "IsComplete": true/false,
        "Status": "InProgress|Completed|Failed|Stopped",
        "JobName": "actual-job-name"
    }
    """
    logger.info(f"Checking training job status with event: {json.dumps(event)}")
    
    try:
        # Determine job name from event
        job_name = None
        
        if 'JobName' in event:
            job_name = event['JobName']
        elif 'JobNamePrefix' in event and 'RequestId' in event:
            # Construct job name for compatibility with polling
            job_name_prefix = event['JobNamePrefix']
            request_id = event['RequestId']
            # Extract timestamp from request_id or use a pattern
            if 'terraform-' in request_id:
                suffix = request_id.replace('terraform-', '')
                job_name = f"{job_name_prefix}-{suffix}"
            else:
                job_name = f"{job_name_prefix}-{request_id}"
        else:
            raise ValueError("Either 'JobName' or both 'JobNamePrefix' and 'RequestId' must be provided")
        
        logger.info(f"Checking status of training job: {job_name}")
        
        # Get training job status
        response = sagemaker_client.describe_training_job(
            TrainingJobName=job_name
        )
        
        training_job_status = response.get('TrainingJobStatus')
        logger.info(f"Training job status: {training_job_status}")
        
        # Determine if job is complete
        is_complete = training_job_status in ['Completed', 'Failed', 'Stopped']
        
        result = {
            'IsComplete': is_complete,
            'Status': training_job_status,
            'JobName': job_name
        }
        
        # Add additional info for failed jobs
        if training_job_status == 'Failed':
            failure_reason = response.get('FailureReason', 'Unknown failure')
            result['FailureReason'] = failure_reason
            logger.error(f"Training job failed: {failure_reason}")
        elif training_job_status == 'Completed':
            # Add model artifacts location
            model_artifacts = response.get('ModelArtifacts', {})
            if 'S3ModelArtifacts' in model_artifacts:
                result['ModelArtifactsS3Uri'] = model_artifacts['S3ModelArtifacts']
                logger.info(f"Training completed. Model artifacts: {model_artifacts['S3ModelArtifacts']}")
        
        logger.info(f"Training job check result: {result}")
        return result
        
    except sagemaker_client.exceptions.ResourceNotFound:
        error_msg = f"Training job '{job_name}' not found"
        logger.error(error_msg)
        return {
            'IsComplete': False,
            'Status': 'NotFound',
            'JobName': job_name,
            'Error': error_msg
        }
    except Exception as e:
        error_msg = f"Error checking training job status: {str(e)}"
        logger.error(error_msg)
        return {
            'IsComplete': False,
            'Status': 'Error',
            'JobName': job_name,
            'Error': error_msg
        }
