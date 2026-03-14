Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Default Configuration (lending-package-sample) - GovCloud

This directory contains the default GovCloud configuration for the GenAI IDP Accelerator. This configuration serves as the baseline for all document processing tasks in AWS GovCloud regions and can be used as a starting point for creating custom configurations.

## Pattern Association

**Pattern**: Pattern-1 - Uses Amazon Bedrock Data Automation (BDA) both page classification/grouping and information extraction, and Amazon Bedrock LLM models for Summarization and Evaluation.

## GovCloud Deployment

This configuration uses model IDs that are available in AWS GovCloud regions:
- **Amazon Nova Pro**: `amazon.nova-pro-v1:0`
- **Anthropic Claude Sonnet 4.5**: `anthropic.claude-3-7-sonnet-20250219-v1:0`

## Validation Level

**Level**: 2 - Comprehensive Testing

- **Testing Evidence**: This configuration has been tested with a diverse set of business documents across all supported document classes. It has shown consistent performance in classifying and extracting information from standard business documents.
- **Known Limitations**: Performance may vary with highly specialized document types or documents with complex layouts not represented in the test set.

## Overview

The default configuration for GovCloud deployments.


## Key Components

### Document Classes and Extraction Settings

Defined by the BDA project referenced by the BDA Project Arn specified at deployment.

NOTE If BDA Project Arn was left blank at deployment, then a demo BDA project is created for you, that is
designed to work with the sample 'lending_package.pdf' document to identify:
- Payslip
- US Bank Checks
- W2
- US-drivers-licenses
- Bank-Statement
- Homeowners-Insurance-Application


### Summarization Settings

- **Model**: Anthropic Claude Sonnet 4.5 (`anthropic.claude-3-7-sonnet-20250219-v1:0`)
- **Temperature**: 0 (deterministic outputs)
- **Top-k**: 5

The summarization component creates concise summaries of documents with citations and hover functionality.

### Evaluation Settings

- **Model**: Anthropic Claude Sonnet 4.5 (`anthropic.claude-3-7-sonnet-20250219-v1:0`)
- **Temperature**: 0 (deterministic outputs)

### Discovery Settings

- **Model**: Amazon Nova Pro (`amazon.nova-pro-v1:0`)

### Agent Settings

- **Error Analyzer Model**: Anthropic Claude Sonnet 4.5 (`anthropic.claude-3-7-sonnet-20250219-v1:0`)
- **Chat Companion Model**: Anthropic Claude Sonnet 4.5 (`anthropic.claude-3-7-sonnet-20250219-v1:0`)

## Sample Documents

- [lending_package.pdf](./samples/lending_package.pdf)

## How to Use

To use this default GovCloud configuration:

1. **Direct Use**: Deploy the GenAI IDP Accelerator with this configuration without any modifications for general-purpose document processing in GovCloud regions.

2. **As a Template**: Copy this configuration to a new directory and modify it for your specific use case:
   ```bash
   cp -r config_library/pattern-1/lending-package-sample-govcloud config_library/pattern-1/your_use_case_name
   ```

3. **For Testing**: Use this configuration as a baseline for comparing the performance of customized configurations.

## Common Customization Scenarios

### Adding New Document Classes

Classes and attributes are defined by the BDA project blueprints - use the BDA console to configure your project. 

You can optionally add Classes and Attributes definitions in the IDP accelerator configuration for fine grain control of evaluation methods, to override the default evaluation method of 'LLM' for specific attributes. 

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

See BDA blueprints

### Changing Models

Model choice for Classification and Extraction is managed by BDA.
You can select your preferred model and prompts for Summarization and Evaluation.

## Security and Compliance Considerations

When processing documents in GovCloud:

- **FedRAMP Compliance**: GovCloud regions provide FedRAMP High authorization
- **Data Privacy**: Ensure compliance with applicable regulations
- **Encryption**: Use encrypted storage and transmission for all documents
- **Access Controls**: Implement proper authentication and authorization
- **Audit Logging**: Maintain comprehensive logs for regulatory compliance

## Contributors

- GenAI IDP Accelerator Team
