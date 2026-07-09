Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Image Module

The Image module provides utilities for image processing, resizing, and format conversion used across the IDP pipeline.

## Overview

This module handles image preparation for multimodal LLM prompts and OCR processing. It supports loading images from S3 URIs or raw bytes, resizing while preserving aspect ratios, and formatting images for the Amazon Bedrock API.

## Public Functions

| Function | Description |
|----------|-------------|
| `resize_image(image_data, target_width, target_height, allow_upscale)` | Resize image bytes while preserving aspect ratio |
| `prepare_image(image_source, target_width, target_height, allow_upscale)` | Load image from S3 URI or bytes, then resize |
| `apply_adaptive_binarization(image_data)` | Apply adaptive binarization for OCR preprocessing |
| `prepare_bedrock_image_attachment(image_data)` | Format image bytes as a Bedrock API content block |

## Usage

### Resize an Image

```python
from idp_common.image import resize_image

# Resize image bytes to target dimensions (preserves aspect ratio)
resized_bytes = resize_image(
    image_data=original_bytes,
    target_width=1200,
    target_height=1600,
    allow_upscale=False  # Only downscale
)
```

### Load and Prepare from S3

```python
from idp_common.image import prepare_image

# Load from S3 URI and resize
image_bytes = prepare_image(
    image_source="s3://bucket/pages/1/image.jpg",
    target_width=1200,
    target_height=1600
)
```

### Prepare for Bedrock API

```python
from idp_common.image import prepare_bedrock_image_attachment

# Format image for Bedrock multimodal prompt
attachment = prepare_bedrock_image_attachment(image_bytes)
# Returns: {"image": {"format": "jpeg", "source": {"bytes": ...}}}
```

### Adaptive Binarization for OCR

```python
from idp_common.image import apply_adaptive_binarization

# Improve OCR accuracy with binarization
enhanced_bytes = apply_adaptive_binarization(image_bytes)
```

## Configuration

Image dimensions are configurable per service (OCR, classification, extraction, assessment). Empty strings preserve original resolution:

```yaml
classification:
  image:
    target_width: ""     # Preserve original (recommended for accuracy)
    target_height: ""

extraction:
  image:
    target_width: "1200"  # Resize for performance
    target_height: "1600"
```

## Related Documentation

- [OCR Image Sizing Guide](../../../../docs/ocr-image-sizing-guide.md) — Detailed image sizing guidance
