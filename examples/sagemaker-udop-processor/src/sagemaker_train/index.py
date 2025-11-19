from botocore.exceptions import ClientError
from sagemaker.debugger import TensorBoardOutputConfig
from sagemaker.pytorch import PyTorch
import os
import json
import sagemaker
import tempfile
import sys
import builtins
import logging
from datetime import datetime

# Set up logging
logger = logging.getLogger()
logger.setLevel('INFO')

# Monkey patch file operations to redirect to /tmp
original_open = builtins.open

def patched_open(file, *args, **kwargs):
    """Redirect all file opens to /tmp directory if they're not already there"""
    if isinstance(file, str) and not file.startswith('/tmp') and not file.startswith('/var') and not file.startswith('/opt'):
        # Extract just the filename from the path
        filename = os.path.basename(file)
        new_path = os.path.join('/tmp', filename)
        logger.info(f"Redirecting file open from {file} to {new_path}")
        return original_open(new_path, *args, **kwargs)
    return original_open(file, *args, **kwargs)

# Apply the monkey patch
builtins.open = patched_open

# Patch os.makedirs to ensure it only creates directories in /tmp
original_makedirs = os.makedirs

def patched_makedirs(name, *args, **kwargs):
    """Redirect directory creation to /tmp if not already there"""
    if isinstance(name, str) and not name.startswith('/tmp') and not name.startswith('/var') and not name.startswith('/opt'):
        new_path = os.path.join('/tmp', os.path.basename(name))
        logger.info(f"Redirecting makedirs from {name} to {new_path}")
        return original_makedirs(new_path, *args, **kwargs)
    return original_makedirs(name, *args, **kwargs)

# Apply the patch
os.makedirs = patched_makedirs

# Set environment variables for cache locations
os.environ['TMPDIR'] = '/tmp'
os.environ['TMP'] = '/tmp'
os.environ['TEMP'] = '/tmp'
os.environ['SAGEMAKER_SHARED_DIRECTORY'] = '/tmp'
os.environ['SAGEMAKER_PROGRAM'] = '/tmp/train.py'

# Import SageMaker SDK after setting environment variables
from sagemaker.debugger import TensorBoardOutputConfig
from sagemaker.pytorch import PyTorch
import sagemaker

def create_sagemaker_training_job(
    sagemaker_role_arn, 
    bucket, 
    job_name, 
    max_epochs, 
    base_model,
    bucket_prefix="", 
    data_bucket="", 
    data_bucket_prefix=""
):
    """
    Creates and starts a SageMaker training job.
    
    Args:
        sagemaker_role_arn: IAM role ARN for SageMaker
        bucket: S3 bucket for model artifacts
        job_name: Unique name for the training job
        max_epochs: Number of training epochs
        base_model: Base model identifier
        bucket_prefix: Prefix for model artifacts
        data_bucket: S3 bucket containing training data
        data_bucket_prefix: Prefix for training data
    
    Returns:
        dict: Training job details
    """
    if not data_bucket:
        data_bucket = bucket
    if not data_bucket_prefix:
        data_bucket_prefix = bucket_prefix

    logger.info(f"Creating SageMaker training job: {job_name}")
    logger.info(f"Using SageMaker execution role: {sagemaker_role_arn}")

    def get_s3_path(bucket_name, prefix, path):
        """Helper to construct S3 paths."""
        if prefix:
            return f"s3://{bucket_name}/{prefix.rstrip('/')}/{path}"
        return f"s3://{bucket_name}/{path}"

    try:
        # Initialize SageMaker session
        sagemaker_session = sagemaker.Session(default_bucket=bucket)
        output_dir = '/opt/ml/output'

        # Configure TensorBoard output
        tensorboard_output_config = TensorBoardOutputConfig(
            s3_output_path=get_s3_path(bucket, bucket_prefix, "tensorboard"),
            container_local_output_path=f"{output_dir}/tensorboard"
        )

        # Create PyTorch estimator
        estimator = PyTorch(
            entry_point="train.py",
            source_dir="./code",
            role=sagemaker_role_arn,
            framework_version="2.4.0",
            py_version="py311",
            instance_type="ml.g5.12xlarge",
            instance_count=1,
            output_path=get_s3_path(bucket, bucket_prefix, "models/"),
            hyperparameters={
                "max_epochs": max_epochs,
                "base_model": base_model,
                "output_dir": output_dir
            },
            code_location=get_s3_path(bucket, bucket_prefix, "scripts/training/"),
            sagemaker_session=sagemaker_session,
            tensorboard_output_config=tensorboard_output_config,
            environment={
                "FI_EFA_FORK_SAFE": "1"
            }
        )

        # Start training job
        training_data_path = get_s3_path(data_bucket, data_bucket_prefix, "training")
        validation_data_path = get_s3_path(data_bucket, data_bucket_prefix, "validation")
        
        logger.info(f"Training data path: {training_data_path}")
        logger.info(f"Validation data path: {validation_data_path}")
        
        estimator.fit({
            "training": training_data_path,
            "validation": validation_data_path
        }, job_name=job_name, wait=False)

        model_path = get_s3_path(bucket, bucket_prefix, f"models/{job_name}/output/model.tar.gz")
        logger.info(f"Model will be saved to: {model_path}")

        return {
            'job_name': job_name,
            'model_path': f"{bucket_prefix}/models/{job_name}/output/model.tar.gz".replace('//', '/'),
            'training_data_path': training_data_path,
            'validation_data_path': validation_data_path,
            'output_path': model_path,
            'status': 'InProgress'
        }

    except Exception as e:
        logger.error(f"Error creating training job: {str(e)}")
        raise

def lambda_handler(event, context):
    """
    Simplified Lambda handler for Terraform usage.
    
    Expected event structure:
    {
        "SagemakerRoleArn": "arn:aws:iam::account:role/role-name",
        "Bucket": "bucket-name",
        "BucketPrefix": "prefix",
        "JobNamePrefix": "job-prefix",
        "MaxEpochs": 3,
        "BaseModel": "microsoft/udop-large",
        "DataBucket": "data-bucket-name",
        "DataBucketPrefix": "data-prefix"
    }
    """
    logger.info(f"Starting SageMaker training job with event: {json.dumps(event)}")
    
    try:
        # Extract parameters from event
        sagemaker_role_arn = event['SagemakerRoleArn']
        bucket = event['Bucket']
        bucket_prefix = event.get('BucketPrefix', '')
        job_name_prefix = event['JobNamePrefix']
        max_epochs = int(event.get('MaxEpochs', 3))
        base_model = event.get('BaseModel', 'microsoft/udop-large')
        data_bucket = event.get('DataBucket', bucket)
        data_bucket_prefix = event.get('DataBucketPrefix', bucket_prefix)
        
        # Generate unique job name with timestamp
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        job_name = f"{job_name_prefix}-{timestamp}"
        
        # Validate required parameters
        if not sagemaker_role_arn:
            raise ValueError("SagemakerRoleArn is required")
        if not bucket:
            raise ValueError("Bucket is required")
        if not job_name_prefix:
            raise ValueError("JobNamePrefix is required")

        # Create training job
        result = create_sagemaker_training_job(
            sagemaker_role_arn=sagemaker_role_arn,
            bucket=bucket,
            job_name=job_name,
            max_epochs=max_epochs,
            base_model=base_model,
            bucket_prefix=bucket_prefix,
            data_bucket=data_bucket,
            data_bucket_prefix=data_bucket_prefix
        )
        
        logger.info(f"Training job created successfully: {result}")
        return result
        
    except Exception as e:
        error_msg = f"Error creating SageMaker training job: {str(e)}"
        logger.error(error_msg)
        raise Exception(error_msg)
