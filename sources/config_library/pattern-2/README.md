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

## Configuration Structure

Pattern 2 configurations leverage **system defaults** for standard settings. A minimal config only needs:

```yaml
notes: "Description of the configuration"

classes:
  - $schema: https://json-schema.org/draft/2020-12/schema
    $id: DocumentType
    type: object
    x-aws-idp-document-type: DocumentType
    description: "Document description"
    properties:
      field_name:
        type: string
        description: "Field description"
```

**Override only what differs from defaults.** For example, to change the classification method:
```yaml
classification:
  classificationMethod: textbasedHolisticClassification
```

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

## Adding Configurations

To add a new configuration for Pattern 2:

1. Create a new directory with a descriptive name
2. Include a `config.yaml` file with the appropriate settings
3. Add a README.md file using the template from `../TEMPLATE_README.md`
4. Include sample documents in a `samples/` directory

See the main [README.md](../README.md) for more detailed instructions on creating and contributing configurations.

## Available Configurations

| Configuration | Description | Special Features |
|---------------|-------------|------------------|
| [bank-statement-sample](./bank-statement-sample/) | Bank statement processing with transaction extraction | Text-based holistic classification, granular assessment |
| [criteria-validation](./criteria-validation/) | Healthcare/insurance prior authorization validation | Custom criteria validation rules and prompts |
| [lending-package-sample](./lending-package-sample/) | Lending package processing (payslips, IDs, bank checks, W2s) | 6 document classes |
| [lending-package-sample-govcloud](./lending-package-sample-govcloud/) | GovCloud-compatible lending package processing | |
| [ocr-benchmark](./ocr-benchmark/) | OCR benchmarking configuration | |
| [realkie-fcc-verified](./realkie-fcc-verified/) | Real estate FCC verification documents | |
| [rvl-cdip](./rvl-cdip/) | RVL-CDIP document classification benchmark | 16 document classes |
| [rvl-cdip-with-few-shot-examples](./rvl-cdip-with-few-shot-examples/) | RVL-CDIP with few-shot learning examples | Custom prompts with `{FEW_SHOT_EXAMPLES}` |