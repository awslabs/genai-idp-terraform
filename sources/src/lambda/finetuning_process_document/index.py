"""
Lambda function to process a single document for fine-tuning.

This function:
1. Downloads a single document from S3
2. Converts PDF to images (if needed)
3. Creates a training example in Bedrock format
4. Writes the example to S3 as an individual JSONL file

Called by Step Functions Distributed Map for parallel processing.
"""

import io
import json
import logging
import os
import uuid
from typing import Any, Dict, List, Optional, Tuple

import boto3
from idp_common.model_finetuning.training_data_utils import (
    convert_pdf_to_images,
    format_baseline_for_training,
    get_extraction_fields,
)

# Try to import PIL for image resizing
try:
    from PIL import Image

    PIL_SUPPORT = True
except ImportError:
    PIL_SUPPORT = False
    Image = None

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
FINETUNING_BUCKET = os.environ.get("FINETUNING_DATA_BUCKET", "")
TEST_SET_BUCKET = os.environ.get("TEST_SET_BUCKET", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Bedrock fine-tuning limits
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10MB limit for Bedrock

# Initialize clients
s3_client = boto3.client("s3", region_name=REGION)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for processing a single document."""
    job_id = event.get("jobId")
    document = event.get("document", {})
    classes = event.get("classes", [])

    logger.info(
        f"Processing document for finetuning: jobId={job_id}, "
        f"filename={document.get('filename', 'unknown')}"
    )

    filename = document.get("filename")
    input_uri = document.get("inputUri")
    baseline_key = document.get("baselineKey")

    if not job_id:
        raise ValueError("jobId is required")
    if not filename or not input_uri:
        raise ValueError("document with filename and inputUri is required")

    try:
        # Load baseline data
        baseline = _load_baseline(baseline_key)
        if not baseline:
            logger.warning(f"No baseline found for {filename}, skipping")
            return {
                "success": False,
                "filename": filename,
                "reason": "No baseline found",
            }

        # Create training example
        example = _create_training_example(
            input_uri=input_uri,
            baseline=baseline,
            filename=filename,
            classes=classes,
            job_id=job_id,
        )

        if not example:
            logger.warning(f"Failed to create training example for {filename}")
            return {
                "success": False,
                "filename": filename,
                "reason": "Failed to create training example",
            }

        # Write individual JSONL file to S3
        example_id = str(uuid.uuid4())
        output_key = f"finetuning/{job_id}/examples/{example_id}.jsonl"

        s3_client.put_object(
            Bucket=FINETUNING_BUCKET,
            Key=output_key,
            Body=json.dumps(example).encode("utf-8"),
            ContentType="application/jsonl",
        )

        logger.info(f"Successfully processed {filename} -> {output_key}")

        return {
            "success": True,
            "filename": filename,
            "outputKey": output_key,
            "outputUri": f"s3://{FINETUNING_BUCKET}/{output_key}",
        }

    except Exception as e:
        logger.error(f"Error processing document {filename}: {str(e)}", exc_info=True)
        return {"success": False, "filename": filename, "reason": str(e)}


def _load_baseline(baseline_key: str) -> Optional[Dict[str, Any]]:
    """Load baseline JSON from S3."""
    if not baseline_key:
        return None

    try:
        response = s3_client.get_object(Bucket=TEST_SET_BUCKET, Key=baseline_key)
        return json.loads(response["Body"].read().decode("utf-8"))
    except Exception as e:
        logger.warning(f"Error loading baseline {baseline_key}: {e}")
        return None


def _create_training_example(
    input_uri: str,
    baseline: Dict[str, Any],
    filename: str,
    classes: List[str],
    job_id: str,
) -> Optional[Dict[str, Any]]:
    """Create a single training example from a document.

    For extraction fine-tuning, we create examples that teach the model
    to extract structured data from documents.

    Supports both image files and PDFs (PDFs are converted to images).

    IMPORTANT: Bedrock fine-tuning requires images to be stored in S3 and
    referenced via s3Location, not embedded as base64 bytes.
    """
    if not input_uri or not baseline:
        return None

    # Build the conversation format for Bedrock fine-tuning
    # Create user message with document image(s)
    user_content = []

    # Add instruction text based on what's in the baseline
    extraction_fields = get_extraction_fields(baseline)
    if extraction_fields:
        fields_str = ", ".join(extraction_fields[:20])  # Limit to 20 fields
        user_content.append(
            {
                "text": f"Extract the following information from this document: {fields_str}. Return the results as a JSON object."
            }
        )
    else:
        user_content.append(
            {
                "text": "Extract all relevant information from this document. Return the results as a JSON object."
            }
        )

    # Add document image(s) - supports PDFs by converting to images
    # Images are uploaded to S3 and referenced via s3Location (required for fine-tuning)
    try:
        image_s3_uris = _get_document_images_as_s3(input_uri, job_id, filename)
        if not image_s3_uris:
            logger.warning(f"No images extracted from document: {filename}")
            return None

        # Add each image/page to the user content with S3 location reference
        for s3_uri, image_format in image_s3_uris:
            user_content.append(
                {
                    "image": {
                        "format": image_format,
                        "source": {"s3Location": {"uri": s3_uri}},
                    }
                }
            )

        logger.info(f"Added {len(image_s3_uris)} image(s) from document: {filename}")

    except Exception as e:
        logger.warning(f"Failed to load document {input_uri}: {e}")
        return None

    if len(user_content) < 2:  # Need at least text + 1 image
        return None

    # Build expected response from baseline extraction results
    extraction_result = format_baseline_for_training(baseline)
    assistant_response = json.dumps(extraction_result, indent=2)

    # Create the training example in Bedrock conversation format
    example = {
        "schemaVersion": "bedrock-conversation-2024",
        "system": [
            {
                "text": "You are a document extraction expert. Analyze the provided document and extract the requested information accurately. Return your results as a well-structured JSON object."
            }
        ],
        "messages": [
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": [{"text": assistant_response}]},
        ],
    }

    return example


def _resize_image_to_limit(
    img_bytes: bytes, img_format: str, max_size: int = MAX_IMAGE_SIZE_BYTES
) -> Tuple[bytes, str]:
    """
    Resize an image if it exceeds the maximum size limit.

    Uses progressive quality reduction and resolution scaling to fit within limits.
    Converts to JPEG for better compression if needed.

    Args:
        img_bytes: Original image bytes
        img_format: Original format (png, jpeg, etc.)
        max_size: Maximum allowed size in bytes (default: 10MB)

    Returns:
        Tuple of (resized_bytes, format) - format may change to jpeg for better compression
    """
    if not PIL_SUPPORT:
        logger.warning("PIL not available, cannot resize images")
        return img_bytes, img_format

    # If already under limit, return as-is
    if len(img_bytes) <= max_size:
        return img_bytes, img_format

    logger.info(f"Image size {len(img_bytes)} exceeds limit {max_size}, resizing...")

    # Load image
    img = Image.open(io.BytesIO(img_bytes))

    # Convert to RGB if necessary (for JPEG compatibility)
    if img.mode in ("RGBA", "P", "LA"):
        # Create white background for transparency
        background = Image.new("RGB", img.size, (255, 255, 255))
        if img.mode == "P":
            img = img.convert("RGBA")
        if img.mode in ("RGBA", "LA"):
            background.paste(img, mask=img.split()[-1])  # Use alpha channel as mask
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # Try JPEG with decreasing quality first (most effective for size reduction)
    for quality in [85, 70, 55, 40, 30]:
        buffer = io.BytesIO()
        img.save(buffer, format="JPEG", quality=quality, optimize=True)
        result_bytes = buffer.getvalue()

        if len(result_bytes) <= max_size:
            logger.info(
                f"Resized image to {len(result_bytes)} bytes using JPEG quality={quality}"
            )
            return result_bytes, "jpeg"

    # If still too large, reduce resolution progressively
    original_size = img.size
    for scale in [0.75, 0.5, 0.35, 0.25]:
        new_size = (int(original_size[0] * scale), int(original_size[1] * scale))
        resized_img = img.resize(new_size, Image.Resampling.LANCZOS)

        for quality in [70, 50, 35]:
            buffer = io.BytesIO()
            resized_img.save(buffer, format="JPEG", quality=quality, optimize=True)
            result_bytes = buffer.getvalue()

            if len(result_bytes) <= max_size:
                logger.info(
                    f"Resized image to {len(result_bytes)} bytes using scale={scale}, quality={quality}"
                )
                return result_bytes, "jpeg"

    # Last resort: aggressive downscaling
    final_scale = 0.15
    new_size = (
        int(original_size[0] * final_scale),
        int(original_size[1] * final_scale),
    )
    resized_img = img.resize(new_size, Image.Resampling.LANCZOS)
    buffer = io.BytesIO()
    resized_img.save(buffer, format="JPEG", quality=30, optimize=True)
    result_bytes = buffer.getvalue()

    logger.warning(
        f"Aggressively resized image to {len(result_bytes)} bytes (scale={final_scale})"
    )
    return result_bytes, "jpeg"


def _get_document_images_as_s3(
    s3_uri: str, job_id: str, filename: str
) -> List[Tuple[str, str]]:
    """
    Download document from S3, convert to images if needed, upload images to S3,
    and return list of S3 URIs.

    For PDFs, converts each page to an image.
    For images, copies the image to the finetuning bucket.

    IMPORTANT: Bedrock fine-tuning requires images to be referenced via S3 URIs,
    not embedded as base64 bytes. Images are automatically resized if they exceed
    the 10MB limit.

    Args:
        s3_uri: S3 URI of the source document
        job_id: Fine-tuning job ID for organizing output
        filename: Original filename for naming the output images

    Returns:
        List of tuples (s3_uri, format) for each image/page
    """
    if not s3_uri.startswith("s3://"):
        raise ValueError(f"Invalid S3 URI: {s3_uri}")

    # Parse S3 URI
    path = s3_uri[5:]
    parts = path.split("/", 1)
    bucket = parts[0]
    key = parts[1] if len(parts) > 1 else ""

    # Download document
    response = s3_client.get_object(Bucket=bucket, Key=key)
    doc_bytes = response["Body"].read()

    lower_uri = s3_uri.lower()

    # Generate base name for output images (remove extension)
    base_name = os.path.splitext(os.path.basename(filename))[0]
    # Sanitize filename for S3 key
    base_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in base_name)

    result = []

    # Handle PDFs - convert to images and upload each page
    if lower_uri.endswith(".pdf"):
        images = convert_pdf_to_images(doc_bytes)
        if not images:
            logger.warning(f"PDF conversion returned no images for: {s3_uri}")
            return []

        for page_idx, (img_bytes, img_format) in enumerate(images):
            # Resize if needed to meet Bedrock's 10MB limit
            img_bytes, img_format = _resize_image_to_limit(img_bytes, img_format)

            # Upload each page as a separate image
            image_key = f"finetuning/{job_id}/images/{base_name}_page{page_idx + 1}.{img_format}"
            s3_client.put_object(
                Bucket=FINETUNING_BUCKET,
                Key=image_key,
                Body=img_bytes,
                ContentType=f"image/{img_format}",
            )
            image_s3_uri = f"s3://{FINETUNING_BUCKET}/{image_key}"
            result.append((image_s3_uri, img_format))
            logger.debug(f"Uploaded PDF page {page_idx + 1} to {image_s3_uri}")

        return result

    # Handle images - copy to finetuning bucket
    if lower_uri.endswith(".jpg") or lower_uri.endswith(".jpeg"):
        img_format = "jpeg"
    elif lower_uri.endswith(".png"):
        img_format = "png"
    elif lower_uri.endswith(".gif"):
        img_format = "gif"
    elif lower_uri.endswith(".webp"):
        img_format = "webp"
    else:
        # Default to PNG
        img_format = "png"

    # Resize if needed to meet Bedrock's 10MB limit
    doc_bytes, img_format = _resize_image_to_limit(doc_bytes, img_format)

    # Upload the image to the finetuning bucket
    image_key = f"finetuning/{job_id}/images/{base_name}.{img_format}"
    s3_client.put_object(
        Bucket=FINETUNING_BUCKET,
        Key=image_key,
        Body=doc_bytes,
        ContentType=f"image/{img_format}",
    )
    image_s3_uri = f"s3://{FINETUNING_BUCKET}/{image_key}"
    result.append((image_s3_uri, img_format))
    logger.debug(f"Uploaded image to {image_s3_uri}")

    return result
