Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Default Configuration

This directory contains the default configuration for the GenAI IDP Accelerator. This configuration serves as the baseline for all document processing tasks and can be used as a starting point for creating custom configurations.

## Pattern Association

**Pattern**: Pattern-2 - Uses Amazon Bedrock with Nova or Claude models for both page classification/grouping and information extraction

## Validation Level

**Level**: 2 - Comprehensive Testing

- **Testing Evidence**: This configuration has been tested with a diverse set of business documents across all supported document classes. It has shown consistent performance in classifying and extracting information from standard business documents.
- **Known Limitations**: Performance may vary with highly specialized document types or documents with complex layouts not represented in the test set.

## Overview

The default configuration is designed to handle a variety of common business document types, including:

- Letters
- Forms
- Invoices
- Resumes
- Scientific publications
- Memos
- Advertisements
- Emails
- Questionnaires
- Specifications
- Generic documents

It includes settings for document classification, information extraction, and document summarization using Amazon Bedrock models.

## Key Components

### Document Classes

The configuration defines 11 document classes, each with specific attributes to extract:

- **letter**: Extracts sender name and address
- **form**: Extracts form type and ID
- **invoice**: Extracts invoice number and date
- **resume**: Extracts full name and contact information
- **scientific_publication**: Extracts title and authors
- **memo**: Extracts memo date and sender
- **advertisement**: Extracts product name and brand
- **email**: Extracts from and to addresses
- **questionnaire**: Extracts form title and respondent information
- **specification**: Extracts product name and version
- **generic**: Extracts document type and date

### Classification Settings

- **Model**: Amazon Nova Pro
- **Method**: Text-based holistic classification
- **Temperature**: 0 (deterministic outputs)
- **Top-k**: 5

The classification component analyzes document content and structure to determine the document type and page boundaries within multi-page documents.

### Extraction Settings

- **Model**: Amazon Nova Pro
- **Temperature**: 0 (deterministic outputs)
- **Top-k**: 5

The extraction component identifies and extracts specific attributes from each document based on its classified type.

### Summarization Settings

- **Model**: Amazon Nova Pro
- **Temperature**: 0 (deterministic outputs)
- **Top-k**: 5

The summarization component creates concise summaries of documents with citations and hover functionality.

## Sample Documents

Sample documents for this configuration will be added in a future update. These will demonstrate the configuration's effectiveness across various document types.

## How to Use

To use this default configuration:

1. **Direct Use**: Deploy the GenAI IDP Accelerator with this configuration without any modifications for general-purpose document processing.

2. **As a Template**: Copy this configuration to a new directory and modify it for your specific use case:
   ```bash
   cp -r config_library/pattern-2/default config_library/pattern-2/your_use_case_name
   ```

3. **For Testing**: Use this configuration as a baseline for comparing the performance of customized configurations.

## Common Customization Scenarios

### Adding New Document Classes

To add a new document class:

1. Add a new entry to the `classes` array in the configuration:
   ```json
   {
     "name": "your_class_name",
     "description": "Description of your document class",
     "attributes": [
       {
         "name": "attribute_name",
         "description": "Description of what to extract and where to find it"
       },
       // Add more attributes as needed
     ]
   }
   ```

2. Test the configuration with sample documents of the new class.

### Modifying Prompts

To adjust the behavior of classification, extraction, or summarization:

1. Modify the `system_prompt` or `task_prompt` in the respective section.
2. Keep the placeholders (e.g., `{DOCUMENT_TEXT}`, `{CLASS_NAMES_AND_DESCRIPTIONS}`) intact.
3. Test the modified prompts with representative documents.

### Changing Models

To use a different model:

1. Update the `model` field in the classification, extraction, or summarization section.
2. Adjust temperature and other parameters as needed for the new model.
3. Test the configuration with the new model to ensure compatibility.

## Performance Considerations

The default configuration is optimized for:

- **Accuracy**: Using temperature 0 for deterministic outputs
- **Generality**: Handling a wide range of document types

For specialized use cases, consider adjusting the configuration to focus on the specific document types and attributes relevant to your needs.

## Contributors

- GenAI IDP Accelerator Team
