Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Pattern 3 Configurations

This directory contains configurations for Pattern 3 of the GenAI IDP Accelerator, which uses UDOP (Unified Document Processing) for page classification and grouping, followed by Claude for information extraction.

## Pattern 3 Overview

Pattern 3 implements an intelligent document processing workflow that uses UDOP (Unified Document Processing) for page classification and grouping, followed by Claude for information extraction.

Key components of Pattern 3:
- OCR processing using Amazon Textract
- Page classification and grouping using a UDOP model deployed on SageMaker
- Field extraction using Claude via Amazon Bedrock

## Adding Configurations

To add a new configuration for Pattern 3:

1. Create a new directory with a descriptive name
2. Include a config.json file with the appropriate settings
3. Add a README.md file using the template from `../TEMPLATE_README.md`
4. Include sample documents in a samples/ directory

See the main [README.md](../README.md) for more detailed instructions on creating and contributing configurations.

## Available Configurations

Currently, there are no configurations available for Pattern 3. Contributions are welcome!
