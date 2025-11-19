Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# GenAI IDP Accelerator Cost Considerations

> **INFORMATION DOCUMENT**  
> This document provides conceptual guidance on the cost factors to consider when using the GenAI Intelligent Document Processing (GenAIIDP) Accelerator solution.

This document provides a framework for understanding the cost elements of running the GenAI IDP Accelerator solution. It outlines the primary contributors to cost and provides guidance on cost optimization across the different processing patterns.

## Key Cost Drivers

The primary cost drivers for the GenAI IDP Accelerator solution include:

### 1. Document Processing Services

#### Pattern 1: Bedrock Data Automation (BDA)
- **BDA Processing**: The main cost component for Pattern 1, charged per document processed.
- **Amazon Bedrock**: Used for summarization (if enabled).

#### Pattern 2: Textract and Bedrock
- **Amazon Textract**: Costs based on the number of pages processed.
- **Amazon Bedrock**: Costs based on the models used, input tokens processed, and output tokens generated.

#### Pattern 3: Textract, SageMaker (UDOP), and Bedrock
- **Amazon Textract**: Costs based on the number of pages processed.
- **Amazon SageMaker**: Costs based on the instance type used and running time.
- **Amazon Bedrock**: Costs for extraction and optional summarization.

### 2. Storage Costs

- **Amazon S3**: Costs based on the amount of data stored and storage duration.
- **Amazon DynamoDB**: Costs based on the stored document metadata.

### 3. Processing Infrastructure

- **AWS Lambda**: Costs based on request count, duration, and memory usage.
- **AWS Step Functions**: Costs based on state transitions for workflow orchestration.
- **Amazon SQS**: Costs based on message count for document queue management.

### 4. Additional Services

- **Amazon CloudWatch**: Costs for logs and metrics.
- **Amazon Cognito**: Costs based on monthly active users.
- **AWS AppSync**: Costs based on GraphQL API queries.
- **Bedrock Knowledge Base**: Costs for queries and storage if this optional feature is used.

## Cost Optimization Strategies

1. **Right-size your model selection**:
   - Use simpler models for routine document processing
   - Reserve more powerful models for complex documents requiring higher accuracy

2. **Configure OCR features appropriately**:
   - Only enable Textract features you need (e.g., TABLES, FORMS, SIGNATURES)
   - Select processing options based on document requirements

3. **Implement prompt caching**:
   - The solution supports prompt caching to significantly reduce costs when processing similar documents
   - Especially effective when using few-shot examples, as these can be cached across invocations

4. **Optimize document preprocessing**:
   - Compress images before processing to reduce Token costs

5. **Implement tiered storage**:
   - Move older processed documents to S3 Infrequent Access or Glacier
   - Implement lifecycle policies based on document age

6. **Monitor and alert on costs**:
   - Set up AWS Budgets to track spending
   - Create alerts for unusual processing volumes

7. **Optimize knowledge base usage** (if used):
   - Limit knowledge base queries to essential use cases
   - Implement caching for common queries

## Cost Monitoring and Estimation

### Built-in Web UI Cost Estimation

The GenAI IDP Accelerator solution includes a built-in cost estimation feature in the web UI that calculates and displays the actual processing costs for each document. This feature:

- Tracks and displays costs per service/API used during document processing
- Breaks down costs by input tokens, output tokens, and page processing
- Shows the total estimated cost for each document processed
- Enables per-page cost analysis for detailed cost monitoring
- Uses service pricing from the solution configuration, which can be modified to reflect any pricing variations or special agreements

This real-time cost tracking helps you monitor actual usage patterns and optimize costs based on real-world usage.

### AWS Cost Management Tools

In addition to the built-in cost tracking, consider using these AWS tools:

- **AWS Cost Explorer**: Analyze and visualize your costs and usage over time
- **AWS Budgets**: Set custom budgets and receive alerts when costs exceed thresholds
- **AWS Cost and Usage Reports**: Generate detailed reports on your AWS costs and usage

## Disclaimer

The GenAI IDP Accelerator solution is designed to provide cost transparency and efficiency. However, actual costs will depend on your specific implementation, document characteristics, and processing needs. Always refer to the official AWS pricing pages for the most current pricing information for all services used.

## References

- [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [Amazon S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [Amazon Textract Pricing](https://aws.amazon.com/textract/pricing/)
- [Amazon Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [Amazon Bedrock Data Processing Jobs Pricing](https://aws.amazon.com/bedrock/pricing/data-processing-jobs/)
- [AWS Step Functions Pricing](https://aws.amazon.com/step-functions/pricing/)
- [Amazon SageMaker Pricing](https://aws.amazon.com/sagemaker/pricing/)
- [Amazon DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [Amazon CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)
