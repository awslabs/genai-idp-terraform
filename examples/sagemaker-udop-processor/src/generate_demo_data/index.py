# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import os
import boto3
import concurrent.futures
import io
import json
import logging
import tempfile
import sys
import builtins
import pathlib

# Monkey patch file operations to redirect to /tmp
original_open = builtins.open

# def patched_open(file, *args, **kwargs):
#     """Redirect all file opens to /tmp directory if they're not already there"""
#     if isinstance(file, str) and not file.startswith('/tmp') and not file.startswith('/var') and not file.startswith('/opt'):
#         # Extract just the filename from the path
#         filename = os.path.basename(file)
#         new_path = os.path.join('/tmp', filename)
#         return original_open(new_path, *args, **kwargs)
#     return original_open(file, *args, **kwargs)

# # Apply the monkey patch
# builtins.open = patched_open

# Patch os.makedirs to ensure it only creates directories in /tmp
original_makedirs = os.makedirs

def patched_makedirs(name, *args, **kwargs):
    """Redirect directory creation to /tmp if not already there"""
    if isinstance(name, str) and not name.startswith('/tmp') and not name.startswith('/var') and not name.startswith('/opt'):
        new_path = os.path.join('/tmp', os.path.basename(name))
        return original_makedirs(new_path, *args, **kwargs)
    return original_makedirs(name, *args, **kwargs)

# Apply the patch
os.makedirs = patched_makedirs

# Set all environment variables that might control cache locations
os.environ['TMPDIR'] = '/tmp'
os.environ['TMP'] = '/tmp'
os.environ['TEMP'] = '/tmp'
os.environ['HF_HOME'] = '/tmp/huggingface'
os.environ['TRANSFORMERS_CACHE'] = '/tmp/transformers'
os.environ['HF_DATASETS_CACHE'] = '/tmp/datasets'
os.environ['TORCH_HOME'] = '/tmp/torch'
os.environ['XDG_CACHE_HOME'] = '/tmp/cache'
os.environ['HUGGINGFACE_HUB_CACHE'] = '/tmp/hf_hub_cache'

# Create necessary directories
for dir_path in ['/tmp/huggingface', '/tmp/transformers', '/tmp/datasets', '/tmp/torch', '/tmp/cache', '/tmp/hf_hub_cache']:
    if not os.path.exists(dir_path):
        original_makedirs(dir_path, exist_ok=True)

from botocore.config import Config
from datasets import load_dataset
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

mapping = {
  0: "letter",
  1: "form",
  2: "email",
  3: "handwritten",
  4: "advertisement",
  5: "scientific report",
  6: "scientific publication",
  7: "specification",
  8: "file folder",
  9: "news article",
  10: "budget",
  11: "invoice",
  12: "presentation",
  13: "questionnaire",
  14: "resume",
  15: "memo"
}

mapping_split = {
    "train": "training",
    "test": "validation"
}

def save_json_2s3(client, data, bucket_name, keystr):
    """Saves JSON data to S3."""
    client.put_object(
        Bucket=bucket_name, Key=keystr,
        Body=json.dumps(data), ContentType="application/json"
    )


def save_image_2s3(client, image_bytes, bucket_name, keystr):
    """Saves image data to S3."""
    client.put_object(
        Bucket=bucket_name, Key=keystr,
        Body=image_bytes, ContentType="image/png"
    )


def textract_fn(image_bytes, client):
    """Calls AWS Textract to extract text from an image."""
    return client.detect_document_text(Document={'Bytes': image_bytes})


def process_each(data, textract_client):
    """Processes each data item, extracts text using Textract, and returns structured data."""
    buffer = io.BytesIO()
    buffer.truncate(0)
    buffer.seek(0)
    data['image'].save(buffer, format="png")
    image_bytes = buffer.getvalue()
    label = {"label": mapping[int(data['label'])]}
    textract_json = textract_fn(image_bytes, textract_client)
    
    return {
        "image": image_bytes,
        "label": label,
        "textract": textract_json
    }


def save_each2s3(data, bucket_name, prefix, file_name, split, s3_client):
    """Saves processed data to S3."""
    save_json_2s3(
        s3_client, data["label"], bucket_name,
        f"{prefix.rstrip('/')}/{mapping_split[split]}/labels/{file_name}.json",
    )
    save_image_2s3(
        s3_client, data["image"], bucket_name,
        f"{prefix.rstrip('/')}/{mapping_split[split]}/images/{file_name}.png",
    )
    save_json_2s3(
        s3_client, data["textract"], bucket_name,
        f"{prefix.rstrip('/')}/{mapping_split[split]}/textract/{file_name}.json",
    )


def process_and_save(data, idx, bucket_name, prefix, split, textract_client, s3_client, logger):
    """Processes a data item and saves it to S3."""
    try:
        processed = process_each(data, textract_client)
        save_each2s3(processed, bucket_name, prefix, str(idx), split, s3_client)
    except Exception as e:
        logger.error(f"Error processing item {idx}: {e}")


def load_data_from_huggingface(split):
    """Loads dataset from Hugging Face."""
    try:
        # Force the dataset to download to /tmp
        cache_dir = '/tmp/datasets'
        logger.info(f"Loading dataset with cache_dir={cache_dir}")
        
        # Try with explicit cache directory
        return load_dataset(
            "jordyvl/rvl_cdip_100_examples_per_class", 
            split=split, 
            cache_dir=cache_dir,
            download_mode='force_redownload',
            keep_in_memory=True
        )
    except Exception as e:
        logger.error(f"Error loading dataset: {e}")
        raise


def metadata(client, data, bucket_name, prefix, split):
    """Creates and saves metadata for the dataset."""
    meta_data = {
        'labels': mapping,
        'size': len(data),
        'name': 'RVLCDIP'
    }
    save_json_2s3(
        client, meta_data, bucket_name,
        f"{prefix.rstrip('/')}/{mapping_split[split]}/metadata.json",
    )


def generate(split, bucket_name, prefix, max_workers, region):
    """Generates the dataset and processes it in parallel."""
    adaptive_config = Config(
        retries={'max_attempts': 100, 'mode': 'adaptive'},
        max_pool_connections=max_workers * 3
    )

    s3_client = boto3.client('s3', region_name=region, config=adaptive_config)
    textract_client = boto3.client('textract', region_name=region, config=adaptive_config)

    # Use a temporary directory for any file operations
    with tempfile.TemporaryDirectory(dir='/tmp') as temp_dir:
        logger.info(f"Using temporary directory: {temp_dir}")
        
        # Set the current working directory to the temp directory
        original_dir = os.getcwd()
        try:
            os.chdir(temp_dir)
            logger.info(f"Changed working directory to {temp_dir}")
            
            data = load_data_from_huggingface(split)
            logger.info(f"Successfully loaded dataset with {len(data)} examples")
            
            with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
                futures = {
                    executor.submit(
                        process_and_save, dt, idx, bucket_name, prefix, split, 
                        textract_client, s3_client, logger
                    ): idx
                    for idx, dt in enumerate(data)
                }
                
                for future in concurrent.futures.as_completed(futures):
                    try:
                        future.result()  # Handle exceptions if needed
                    except Exception as e:
                        logger.error(f"Error processing item {futures[future]}: {e}")

            metadata(s3_client, data, bucket_name, prefix, split)
            logger.info(f"Data is saved under 's3://{bucket_name}/{prefix}/{mapping_split[split]}'")
        except Exception as e:
            logger.error(f"Error in generate function: {e}")
            raise
        finally:
            # Change back to the original directory
            try:
                os.chdir(original_dir)
                logger.info(f"Changed working directory back to {original_dir}")
            except Exception as e:
                logger.error(f"Error changing back to original directory: {e}")


def lambda_handler(event, context):
    """
    Lambda function handler that processes and uploads dataset to S3 with AWS Textract.
    
    Environment Variables:
    - DATA_BUCKET: Name of the S3 bucket for storing data
    - DATA_BUCKET_PREFIX: Prefix for S3 bucket paths (default: "")
    - MAX_WORKERS: Number of parallel workers (default: 10)
    - AWS_REGION: AWS region to use for services (default: us-west-2)
    """
    # Log system information
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Current working directory: {os.getcwd()}")
    logger.info(f"Temp directory: {tempfile.gettempdir()}")
    logger.info(f"Environment variables: TMPDIR={os.environ.get('TMPDIR')}, HF_HOME={os.environ.get('HF_HOME')}")
    
    # Get environment variables with defaults
    data_bucket = os.environ.get('DATA_BUCKET')
    data_bucket_prefix = os.environ.get('DATA_BUCKET_PREFIX', '')
    max_workers = int(os.environ.get('MAX_WORKERS', '10'))  # Lower default for Lambda
    region = os.environ.get('AWS_REGION', 'us-west-2')
    
    if not data_bucket:
        error_msg = "DATA_BUCKET environment variable must be set"
        logger.error(error_msg)
        return {
            'statusCode': 400,
            'body': json.dumps({'error': error_msg})
        }
    
    try:
        # Process both test and train datasets
        generate("test", data_bucket, data_bucket_prefix, max_workers, region)
        generate("train", data_bucket, data_bucket_prefix, max_workers, region)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully generated and uploaded demo data',
                'bucket': data_bucket,
                'prefix': data_bucket_prefix
            })
        }
    except Exception as e:
        error_msg = f"Error generating demo data: {str(e)}"
        logger.error(error_msg)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg})
        }
