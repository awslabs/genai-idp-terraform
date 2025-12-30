Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Pattern 2 Configurations

This directory contains configurations for Pattern 2 of the GenAI IDP Accelerator, which uses Amazon Bedrock with Nova or Claude models for both page classification/grouping and information extraction.

## Pattern 2 Overview

Pattern 2 implements an intelligent document processing workflow that uses Amazon Bedrock with Nova or Claude models for both page classification/grouping and information extraction.

Key components of Pattern 2:
- **OCR processing** with multiple backend options (Textract, Bedrock LLM, or image-only)
- **Document classification** using Claude via Amazon Bedrock (with two available methods):
  - Page-level classification: Classifies individual pages and groups them
  - Holistic packet classification: Analyzes multi-document packets to identify document boundaries
- **Field extraction** using Claude via Amazon Bedrock
- **Assessment functionality** for confidence evaluation of extraction results

## OCR Backend Selection for Pattern 2

Pattern 2 supports multiple OCR backends, each with different implications for the assessment feature:

### Textract Backend (Default - Recommended)
- **Best for**: Production workflows, when assessment is enabled
- **Assessment Impact**: ✅ Full assessment capability with granular confidence scores
- **Text Confidence Data**: Rich confidence information for each text block
- **Cost**: Standard Textract pricing

### Bedrock Backend (LLM-based OCR)
- **Best for**: Challenging documents where traditional OCR fails
- **Assessment Impact**: ❌ Assessment disabled - no confidence data available
- **Text Confidence Data**: Empty (no confidence scores from LLM OCR)
- **Cost**: Bedrock LLM inference costs

### None Backend (Image-only)
- **Best for**: Custom OCR integration, image-only workflows
- **Assessment Impact**: ❌ Assessment disabled - no OCR text available
- **Text Confidence Data**: Empty
- **Cost**: No OCR costs

> ⚠️ **Assessment Recommendation**: Use Textract backend (default) when assessment functionality is required. Bedrock and None backends eliminate assessment capability due to lack of confidence data.

## Text Confidence Data and Assessment Integration

Pattern 2's assessment feature relies on text confidence data generated during the OCR phase to evaluate extraction quality and provide confidence scores for each extracted attribute.

### How Text Confidence Data Enables Assessment

1. **OCR Phase**: Textract generates confidence scores for each text block during document processing
2. **Condensed Format**: OCR service creates optimized `textConfidence.json` files with 80-90% token reduction
3. **Assessment Phase**: LLM analyzes extraction results against OCR confidence data to provide accurate confidence evaluation
4. **UI Integration**: Assessment results appear in the web interface with color-coded confidence indicators

### Assessment Workflow Impact by OCR Backend

**With Textract Backend:**
```
Document → Textract OCR → Rich Confidence Data → Assessment LLM → Confidence Scores
```
- Assessment LLM receives detailed confidence information for each text region
- Can accurately evaluate extraction confidence based on OCR quality
- Provides meaningful confidence scores and explanations

**With Bedrock/None Backend:**
```
Document → LLM/No OCR → Empty Confidence Data → Assessment Disabled
```
- No confidence data available for assessment
- Assessment feature cannot function without OCR confidence scores
- Results in assessment being skipped or disabled

## Adding Configurations

To add a new configuration for Pattern 2:

1. Create a new directory with a descriptive name
2. Include a config.json file with the appropriate settings
3. Add a README.md file using the template from `../TEMPLATE_README.md`
4. Include sample documents in a samples/ directory

See the main [README.md](../README.md) for more detailed instructions on creating and contributing configurations.

## Available Configurations

- [default](./default/): Default configuration for general document processing
- [medical_records_summarization](./medical_records_summarization/): Specialized configuration for processing and summarizing medical records
- [checkboxed_attributes_extraction](./checkboxed_attributes_extraction): Specialized configuration for processing documents that contain checkboxes where key information is extracted by selected boxes
