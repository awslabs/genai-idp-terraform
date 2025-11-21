Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# IDP Bedrock Data Automation (BDA) Module

This module provides functionality for interacting with Amazon Bedrock Data Automation (BDA) for document processing and information extraction.

## Overview

The BDA module enables seamless integration with Amazon Bedrock Data Automation services, allowing you to:

- Invoke BDA jobs asynchronously
- Monitor job status and retrieve results
- Process extracted data from BDA outputs
- Work with BDA projects and blueprints

## Components

- **BdaService**: Main service class for interacting with BDA
- **BdaInvocation**: Data class for handling BDA job results
- **CloudFormation Templates**: Templates for creating BDA projects and blueprints

## Usage

### Basic BDA Job Invocation

```python
from idp_common.bda.bda_service import BdaService

# Initialize the service with output location
bda_service = BdaService(
    output_s3_uri="s3://your-bucket/output-path"
)

# Invoke BDA and wait for completion
result = bda_service.invoke_data_automation(
    input_s3_uri="s3://your-bucket/input-path/document.pdf",
    blueprintArn="arn:aws:bedrock:region:account:blueprint/blueprint-id"
)

# Check the result
if result['status'] == 'success':
    output_location = result['output_location']
    print(f"Processing completed. Results at: {output_location}")
else:
    print(f"Processing failed: {result['error_message']}")
```

### Asynchronous Invocation

For more control over the process, you can use the async methods:

```python
# Start the job asynchronously
response = bda_service.invoke_data_automation_async(
    input_s3_uri="s3://your-bucket/input-path/document.pdf",
    blueprintArn="arn:aws:bedrock:region:account:blueprint/blueprint-id"
)

# Get the invocation ARN
invocation_arn = response['invocationArn']

# Later, check the status
bda_service.wait_data_automation_invocation(invocationArn=invocation_arn)
result = bda_service.get_data_automation_invocation(invocationArn=invocation_arn)
```

### Processing BDA Results

The `BdaInvocation` class simplifies working with BDA output:

```python
from idp_common.bda.bda_invocation import BdaInvocation

# Create from S3 output location
bda_invocation = BdaInvocation.from_s3(s3_url=result["output_location"])

# Get the custom output (extracted data)
custom_output = bda_invocation.get_custom_output()

# Access specific fields
if "PatientName" in custom_output:
    patient_name = custom_output["PatientName"]
    print(f"Patient Name: {patient_name}")
```

## Configuration

### BdaService Configuration

The BdaService can be configured with:

- `output_s3_uri`: S3 URI where BDA job results will be stored
- `dataAutomationProjectArn`: Optional ARN of a BDA project
- `dataAutomationProfileArn`: Optional ARN of a BDA profile (defaults to standard profile)

```python
bda_service = BdaService(
    output_s3_uri="s3://your-bucket/output-path",
    dataAutomationProjectArn="arn:aws:bedrock:region:account:data-automation-project/project-id"
)
```

## CloudFormation Templates

The module includes CloudFormation templates for creating BDA resources:

### Creating a BDA Project and Blueprint

Use the provided CloudFormation template in `notebooks/bda/cfn/bda-project.yml`:

```bash
# Deploy the CloudFormation stack
aws cloudformation deploy \
  --template-file bda-project.yml \
  --stack-name my-bda-project \
  --parameter-overrides \
    ProjectName=MyProject \
    ProjectDescription="My BDA Project" \
    BlueprintName=MyBlueprint
```

### Managing BDA Resources

The module includes a Makefile with helpful commands:

```bash
# List all BDA projects
make list-projects

# List all blueprints
make list-blueprints

# Get details of a specific project
make get-project BDA_PROJECT_ARN=arn:aws:bedrock:region:account:data-automation-project/project-id

# Get details of a specific blueprint
make get-blueprint BDA_BLUEPRINT_ARN=arn:aws:bedrock:region:account:blueprint/blueprint-id
```

## Error Handling

The BDA service includes comprehensive error handling:

1. If a BDA job fails, the error details are captured in the result
2. The service optionally automatically polls for job completion.
3. All errors are logged for debugging

## Performance Optimization

For optimal performance with BDA:

1. Use asynchronous invocation for large batches of documents
2. Monitor job status with appropriate polling intervals
3. Consider using BDA projects for consistent processing across multiple documents

## Thread Safety

The BDA service is designed to be thread-safe, supporting concurrent processing of multiple documents in parallel workloads.
