Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Pattern 1 Configurations

This directory contains configurations for Pattern 1 of the GenAI IDP Accelerator, which uses Amazon Bedrock Data Automation (BDA) for document processing tasks.

## Pattern 1 Overview

Pattern 1 implements an intelligent document processing workflow using Amazon Bedrock Data Automation (BDA) for orchestrating ML-powered document processing tasks. It leverages BDA's ability to extract insights from documents using pre-configured templates and workflows.

Key components of Pattern 1:
- BDA Invoke Lambda that starts BDA jobs asynchronously with a task token
- BDA Completion Lambda that processes job completion events from EventBridge
- Process Results Lambda that copies output files to designated location

## Configuration Structure

Pattern 1 configurations are minimal because:
1. **Document schemas are defined in BDA Blueprints** - not in the config file
2. **System defaults** provide all standard settings (OCR, assessment, evaluation, etc.)

A typical Pattern 1 config only needs:
```yaml
notes: "Description of the configuration"
classes: []  # Empty - schemas defined in BDA Blueprints
```

## Adding Configurations

To add a new configuration for Pattern 1:

1. Create a new directory with a descriptive name
2. Include a `config.yaml` file with the appropriate settings
3. Add a README.md file using the template from `../TEMPLATE_README.md`
4. Include sample documents in a `samples/` directory

See the main [README.md](../README.md) for more detailed instructions on creating and contributing configurations.

## Available Configurations

| Configuration | Description |
|---------------|-------------|
| [lending-package-sample](./lending-package-sample/) | Default lending package processing for Pattern 1 |
| [lending-package-sample-govcloud](./lending-package-sample-govcloud/) | GovCloud-compatible lending package processing |
| [ocr-benchmark](./ocr-benchmark/) | OCR benchmarking configuration |
| [realkie-fcc-verified](./realkie-fcc-verified/) | Real estate FCC verification documents |
| [rvl-cdip](./rvl-cdip/) | RVL-CDIP document classification benchmark |