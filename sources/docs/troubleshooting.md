Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Troubleshooting Guide

This guide provides solutions for common issues and optimization techniques for the GenAIIDP solution.

## Common Issues and Resolutions

### Document Processing Failures

| Issue | Resolution |
|-------|------------|
| **Workflow execution fails** | Check CloudWatch logs for specific error messages. Look in the Step Functions execution history to identify which step failed. |
| **PDF document not processing** | Verify the PDF is not password protected or encrypted. Ensure it's not corrupted by opening it in another application. |
| **OCR fails on document** | Check if the document is scanned at sufficient quality. Verify the document doesn't exceed size limits (typically 5MB for Textract). |
| **Classification returns "other"** | Review document class definitions. Consider adding more detailed class descriptions or adding few-shot examples. |
| **Extraction missing fields** | Review attribute descriptions and prompt engineering. Check if fields are present but in an unusual format or location. |

### Web UI Access Issues

| Issue | Resolution |
|-------|------------|
| **Cannot login to Web UI** | Verify Cognito user status and permissions in AWS Console. Check email for temporary credentials if first-time login. |
| **Web UI loads but shows errors** | Check browser console for specific error messages. Verify API endpoints are accessible. |
| **Cannot see document history** | Verify AWS AppSync API permissions. Check CloudWatch Logs for API errors. |
| **Configuration changes not saving** | Check browser console for validation errors. Verify that the configuration Lambda function has correct permissions. |

### Model and Service Issues

| Issue | Resolution |
|-------|------------|
| **Bedrock model throttling** | Check CloudWatch metrics for throttling events. Consider increasing MaxConcurrentWorkflows parameter or requesting service quota increases. |
| **SageMaker endpoint errors** | Verify endpoint status in SageMaker console. Check endpoint logs for specific error messages. |
| **Slow document processing** | Monitor CloudWatch metrics to identify bottlenecks. Consider optimizing model selection or increasing concurrency limits. |

### Infrastructure Issues

| Issue | Resolution |
|-------|------------|
| **Lambda function timeouts** | Increase function timeout or memory allocation. Consider breaking processing into smaller chunks. |
| **DynamoDB capacity exceeded** | Check CloudWatch metrics for throttling. Consider increasing provisioned capacity or switching to on-demand capacity. |
| **S3 permission errors** | Verify bucket policies and IAM role permissions. Check for cross-account access issues. |

## Performance Considerations

### Resource Sizing

Optimize performance through proper resource sizing:

- **Lambda Memory**: Scale based on document complexity
  - OCR Function: 1024-2048 MB recommended
  - Classification/Extraction: 512-1024 MB for text-only, 1024-2048 MB for image-based processing
  
- **Timeouts**: Configure appropriate timeouts
  - Step Functions: 5-15 minutes for standard documents
  - Lambda functions: 1-3 minutes for individual processing steps
  - SQS visibility timeout: 5-6x Lambda function timeout

- **Concurrency Settings**
  - Set `MaxConcurrentWorkflows` parameter based on expected volume
  - Consider Lambda reserved concurrency for critical functions
  - Monitor and adjust based on actual usage patterns

### Performance Optimization Tips

1. **Document Size and Quality**
   - Optimize input document size (600-1200 DPI recommended for scans)
   - Reduce file size when possible without losing quality
   - Consider preprocessing large documents to split them

2. **Model Selection**
   - Balance accuracy vs. speed based on use case requirements
   - Test different models with representative documents
   - Consider smaller models for simple documents, larger models for complex extraction

3. **Batch Processing**
   - For high volumes, stagger document uploads
   - Use the load simulation scripts to test capacity
   - Monitor queue depth and processing latency

## Queue Management

### Dead Letter Queue (DLQ) Processing

If messages end up in a Dead Letter Queue:

1. Review the messages in the DLQ using the AWS Console
2. Check CloudWatch Logs for corresponding errors
3. Fix the underlying issue (permission, configuration, etc.)
4. Use the AWS SDK or Console to move messages back to the main queue:

```python
import boto3

sqs = boto3.client('sqs')

# Get messages from DLQ
response = sqs.receive_message(
    QueueUrl='dlq-url',
    MaxNumberOfMessages=10,
    VisibilityTimeout=30
)

# Move to main queue
for message in response.get('Messages', []):
    sqs.send_message(
        QueueUrl='main-queue-url',
        MessageBody=message['Body']
    )
    
    # Delete from DLQ
    sqs.delete_message(
        QueueUrl='dlq-url',
        ReceiptHandle=message['ReceiptHandle']
    )
```

### Stopping Runaway Workflows

If too many workflows are running and need to be stopped:

1. Use the provided script to stop workflows:

```bash
./scripts/stop_workflows.sh <stack-name> <pattern-name>
```

2. Purge the SQS queue if needed:
   - Navigate to SQS in the AWS Console
   - Select the queue
   - Choose "Purge" from the Actions menu

## Security Issues

### WAF Blocking Access

If the WAF is blocking legitimate access:

1. Check the `WAFAllowedIPv4Ranges` parameter value
2. Update with correct CIDR blocks for allowed IP ranges
3. Remember Lambda functions have automatic access regardless of WAF settings

### Authentication Issues

For Cognito authentication problems:

1. Verify user exists in Cognito User Pool
2. Check user attributes (email verified, status)
3. Reset user password if needed
4. Review identity pool configuration
5. Check browser console for specific authentication errors

## Model-Specific Troubleshooting

### Bedrock

- **Throttling**: Request quota increases or reduce concurrency
- **Content Filtering**: Review guardrail configuration if content is being filtered unexpectedly
- **Prompt Issues**: Test prompts directly in Bedrock console or notebook
- **Region Availability**: Verify model availability in your region

### SageMaker

- **Endpoint Cold Start**: Consider using provisioned concurrency
- **GPU Utilization**: Monitor utilization and adjust instance type if needed
- **Memory Errors**: Check inference logs for out-of-memory errors
- **Model Loading Errors**: Verify model artifacts are correct

## Advanced Troubleshooting

### End-to-End Tracing

Use X-Ray tracing for advanced diagnostics:

1. Enable X-Ray tracing in the CloudFormation template
2. View service map in X-Ray console
3. Analyze trace details for latency and error hotspots

### Log Correlation

Trace document processing across systems:

1. Extract correlation ID from log entries
2. Search across log groups using CloudWatch Insights:

```
fields @timestamp, @message
| filter @message like "correlation-id-here"
| sort @timestamp asc
```

### Performance Testing

Test system capacity and identify bottlenecks:

1. Use load testing scripts in `./scripts/` directory
2. Start with low document rates and increase gradually
3. Monitor CloudWatch metrics for saturation points
4. Identify bottlenecks and optimize configuration
