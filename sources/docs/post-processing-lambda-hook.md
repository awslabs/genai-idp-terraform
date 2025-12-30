Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Post-Processing Lambda Hook

The GenAIIDP solution supports an optional post-processing Lambda hook that enables custom downstream processing of document extraction results. This integration allows you to automatically trigger custom workflows, notifications, or data transformations immediately after a document is successfully processed.

## How It Works

1. **Document Processing Complete**
   - The IDP workflow completes successfully for a document
   - All extraction, assessment, and summarization steps finish
   - Document results are saved to the output S3 bucket

2. **EventBridge Integration**
   - The solution automatically publishes a custom event to EventBridge
   - Event contains complete document processing details and output locations
   - EventBridge rule matches the event pattern and triggers your Lambda function

3. **Custom Processing**
   - Your Lambda function receives the document processing event
   - Function can access extraction results, confidence scores, and metadata
   - Implement custom logic for notifications, data transformation, or system integration

4. **Error Handling**
   - Built-in retry logic for transient failures
   - Dead letter queue for failed invocations
   - CloudWatch monitoring and alerting

## Configuration

Configure the post-processing hook during stack deployment:

```yaml
PostProcessingLambdaHookFunctionArn:
  Type: String
  Default: ""
  Description: Optional Lambda ARN for custom post-processing. Leave empty to disable.
  
# Example values:
# arn:aws:lambda:us-east-1:123456789012:function:my-post-processor
# arn:aws:lambda:us-east-1:123456789012:function:enterprise-integration:PROD
```

When configured, the solution automatically:
- Creates an EventBridge rule to match document completion events
- Grants necessary permissions for EventBridge to invoke your Lambda function
- Sets up dead letter queue handling for failed invocations
- Configures CloudWatch monitoring for the integration

## Event Payload Structure

Your Lambda function receives a comprehensive event payload containing all document processing details:

```json
{
  "version": "0",
  "id": "12345678-1234-1234-1234-123456789012",
  "detail-type": "IDP Document Processing Complete",
  "source": "aws.idp.processing",
  "account": "123456789012",
  "time": "2024-01-15T14:30:00Z",
  "region": "us-east-1",
  "detail": {
    "documentId": "doc_12345",
    "inputBucket": "my-input-bucket",
    "inputKey": "documents/invoice-001.pdf",
    "outputBucket": "my-output-bucket",
    "outputKey": "results/invoice-001.pdf.json",
    "status": "COMPLETED",
    "processingTimeMs": 45230,
    "startTime": "2024-01-15T14:29:15Z",
    "endTime": "2024-01-15T14:30:00Z",
    "workflowExecutionArn": "arn:aws:states:us-east-1:123456789012:execution:IDP-Workflow:doc_12345",
    "pattern": "Pattern2",
    "documentClass": "Invoice",
    "numPages": 3,
    "sections": [
      {
        "sectionId": "section-1",
        "sectionType": "Invoice",
        "pageRange": "1-3",
        "extractionResultUri": "s3://my-output-bucket/extraction/section-1.json",
        "assessmentResultUri": "s3://my-output-bucket/assessment/section-1.json",
        "attributes": {
          "invoice_number": "INV-2024-001",
          "vendor_name": "ABC Corporation",
          "total_amount": "$1,250.00"
        }
      }
    ],
    "summaryReportUri": "s3://my-output-bucket/summary/invoice-001.pdf.md",
    "evaluationResultUri": "s3://my-output-bucket/evaluation/invoice-001.pdf.json",
    "metadata": {
      "fileSize": 2048576,
      "mimeType": "application/pdf",
      "uploadTimestamp": "2024-01-15T14:28:00Z"
    },
    "costs": {
      "totalTokens": 15420,
      "estimatedCostUSD": 0.23
    }
  }
}
```

## Lambda Function Implementation

### Basic Example

```python
import json
import boto3
import logging
from typing import Dict, Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Post-processing Lambda hook for IDP document completion events
    """
    try:
        # Extract document details from EventBridge event
        detail = event['detail']
        document_id = detail['documentId']
        document_class = detail['documentClass']
        output_bucket = detail['outputBucket']
        output_key = detail['outputKey']
        
        logger.info(f"Processing completed document: {document_id} (class: {document_class})")
        
        # Download and parse the extraction results
        extraction_results = download_json_from_s3(output_bucket, output_key)
        
        # Implement your custom processing logic here
        process_document_results(detail, extraction_results)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed document {document_id}',
                'documentClass': document_class
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing document: {str(e)}")
        # Re-raise to trigger retry logic
        raise e

def download_json_from_s3(bucket: str, key: str) -> Dict[str, Any]:
    """Download and parse JSON from S3"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        return json.loads(content)
    except Exception as e:
        logger.error(f"Failed to download {bucket}/{key}: {str(e)}")
        raise e

def process_document_results(detail: Dict[str, Any], results: Dict[str, Any]):
    """
    Implement your custom processing logic here
    Examples:
    - Send notifications
    - Update external systems
    - Transform data for downstream systems
    - Trigger additional workflows
    """
    document_class = detail['documentClass']
    
    if document_class == "Invoice":
        process_invoice(detail, results)
    elif document_class == "Bank Statement":
        process_bank_statement(detail, results)
    else:
        logger.info(f"No specific processing for document class: {document_class}")

def process_invoice(detail: Dict[str, Any], results: Dict[str, Any]):
    """Process invoice-specific logic"""
    # Example: Extract key invoice fields
    sections = detail.get('sections', [])
    for section in sections:
        attributes = section.get('attributes', {})
        invoice_number = attributes.get('invoice_number')
        vendor_name = attributes.get('vendor_name')
        total_amount = attributes.get('total_amount')
        
        logger.info(f"Invoice processed: {invoice_number} from {vendor_name} for {total_amount}")
        
        # Example integrations:
        # - Update ERP system
        # - Send approval notifications
        # - Trigger payment workflows
        # - Update vendor management system
        
def process_bank_statement(detail: Dict[str, Any], results: Dict[str, Any]):
    """Process bank statement-specific logic"""
    # Example: Process transaction data
    sections = detail.get('sections', [])
    for section in sections:
        attributes = section.get('attributes', {})
        account_number = attributes.get('account_number')
        transactions = attributes.get('transactions', [])
        
        logger.info(f"Bank statement processed: Account {account_number} with {len(transactions)} transactions")
        
        # Example integrations:
        # - Update accounting system
        # - Reconcile transactions
        # - Generate financial reports
        # - Trigger fraud detection
```


## Use Cases and Implementation Patterns

### Enterprise System Integration

```python
def integrate_with_erp_system(document_data: Dict[str, Any]):
    """Integrate processed documents with ERP systems"""
    
    # Example: SAP integration
    if document_data['documentClass'] == 'Invoice':
        attributes = extract_invoice_attributes(document_data)
        
        # Create vendor invoice in SAP
        sap_payload = {
            'vendor_id': map_vendor_name_to_id(attributes['vendor_name']),
            'invoice_number': attributes['invoice_number'],
            'amount': parse_currency(attributes['total_amount']),
            'due_date': parse_date(attributes['due_date']),
            'gl_account': determine_gl_account(attributes)
        }
        
        # Post to SAP via API
        post_to_sap_api(sap_payload)
        
        # Update document status in tracking system
        update_document_status(document_data['documentId'], 'ERP_INTEGRATED')
```

### Automated Workflow Triggers

```python
def trigger_approval_workflow(document_data: Dict[str, Any]):
    """Trigger approval workflows based on document content"""
    
    if document_data['documentClass'] == 'Contract':
        attributes = extract_contract_attributes(document_data)
        contract_value = parse_currency(attributes.get('contract_value', '0'))
        
        # Route based on contract value
        if contract_value > 100000:
            trigger_executive_approval(document_data)
        elif contract_value > 10000:
            trigger_manager_approval(document_data)
        else:
            auto_approve_contract(document_data)

def trigger_executive_approval(document_data: Dict[str, Any]):
    """Trigger executive approval workflow"""
    # Send to approval system
    approval_payload = {
        'document_id': document_data['documentId'],
        'approval_level': 'EXECUTIVE',
        'urgency': 'HIGH',
        'summary': get_document_summary(document_data),
        'key_terms': extract_key_contract_terms(document_data)
    }
    
    send_to_approval_system(approval_payload)
```

### Real-time Notifications

```python
def send_intelligent_notifications(document_data: Dict[str, Any]):
    """Send context-aware notifications based on document content"""
    
    document_class = document_data['documentClass']
    confidence_scores = extract_confidence_scores(document_data)
    
    # High-priority notifications for low confidence
    if any(score < 0.7 for score in confidence_scores.values()):
        send_quality_alert(document_data, confidence_scores)
    
    # Document-specific notifications
    if document_class == 'Invoice':
        send_invoice_notifications(document_data)
    elif document_class == 'Medical Record':
        send_medical_record_notifications(document_data)

def send_quality_alert(document_data: Dict[str, Any], confidence_scores: Dict[str, float]):
    """Send alerts for low-confidence extractions"""
    low_confidence_fields = {
        field: score for field, score in confidence_scores.items() 
        if score < 0.7
    }
    
    alert_message = {
        'type': 'QUALITY_ALERT',
        'document_id': document_data['documentId'],
        'low_confidence_fields': low_confidence_fields,
        'requires_review': True
    }
    
    send_slack_notification(alert_message)
    send_email_alert(alert_message)
```

### Data Pipeline Integration

```python
def feed_data_pipeline(document_data: Dict[str, Any]):
    """Feed extracted data into analytics and ML pipelines"""
    
    # Transform data for analytics
    analytics_record = {
        'document_id': document_data['documentId'],
        'processing_date': document_data['endTime'],
        'document_class': document_data['documentClass'],
        'processing_time_ms': document_data['processingTimeMs'],
        'extraction_confidence': calculate_average_confidence(document_data),
        'extracted_fields': flatten_extracted_attributes(document_data)
    }
    
    # Send to data lake
    send_to_kinesis_data_stream(analytics_record)
    
    # Update ML feature store
    update_feature_store(analytics_record)
    
    # Trigger batch analytics jobs if threshold reached
    check_and_trigger_batch_processing()
```

## Security Considerations

### IAM Permissions

Your Lambda function needs appropriate permissions to access IDP resources:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-output-bucket/*",
        "arn:aws:s3:::your-working-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:*:*:notification-topic"
    }
  ]
}
```


### Data Protection

Implement appropriate data protection measures:

```python
def sanitize_sensitive_data(document_data: Dict[str, Any]) -> Dict[str, Any]:
    """Remove or mask sensitive information"""
    
    # Define sensitive fields by document type
    sensitive_fields = {
        'Bank Statement': ['account_number', 'routing_number', 'ssn'],
        'Medical Record': ['patient_id', 'ssn', 'dob'],
        'Invoice': ['tax_id', 'bank_account']
    }
    
    document_class = document_data['documentClass']
    fields_to_mask = sensitive_fields.get(document_class, [])
    
    # Create sanitized copy
    sanitized_data = copy.deepcopy(document_data)
    
    for section in sanitized_data.get('sections', []):
        attributes = section.get('attributes', {})
        for field in fields_to_mask:
            if field in attributes:
                attributes[field] = mask_sensitive_value(attributes[field])
    
    return sanitized_data
```

## Monitoring and Alerting

### CloudWatch Metrics

The solution automatically creates CloudWatch metrics for the post-processing hook:

- `PostProcessing/Invocations` - Number of Lambda invocations
- `PostProcessing/Errors` - Number of processing errors
- `PostProcessing/Duration` - Processing duration
- `PostProcessing/Throttles` - Number of throttled invocations

### Custom Metrics

Add custom metrics to track your specific use cases:

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

def publish_custom_metrics(document_data: Dict[str, Any], processing_result: Dict[str, Any]):
    """Publish custom CloudWatch metrics"""
    
    document_class = document_data['documentClass']
    
    # Publish document class metrics
    cloudwatch.put_metric_data(
        Namespace='IDP/PostProcessing',
        MetricData=[
            {
                'MetricName': 'DocumentsProcessed',
                'Dimensions': [
                    {
                        'Name': 'DocumentClass',
                        'Value': document_class
                    }
                ],
                'Value': 1,
                'Unit': 'Count'
            },
            {
                'MetricName': 'ProcessingLatency',
                'Dimensions': [
                    {
                        'Name': 'DocumentClass',
                        'Value': document_class
                    }
                ],
                'Value': processing_result.get('processing_time_ms', 0),
                'Unit': 'Milliseconds'
            }
        ]
    )
```

### Alerting Configuration

Set up CloudWatch alarms for critical issues:

```yaml
PostProcessingErrorAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: !Sub "${AWS::StackName}-PostProcessing-Errors"
    AlarmDescription: "Post-processing Lambda errors"
    MetricName: Errors
    Namespace: AWS/Lambda
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 1
    Threshold: 1
    ComparisonOperator: GreaterThanOrEqualToThreshold
    Dimensions:
      - Name: FunctionName
        Value: !Ref PostProcessingFunction
    AlarmActions:
      - !Ref AlertTopic
```

## Best Practices

### Error Handling and Resilience

1. **Implement Retry Logic**: Handle transient failures with exponential backoff
2. **Use Dead Letter Queues**: Capture failed events for analysis and reprocessing
3. **Validate Input Data**: Check event structure and required fields before processing
4. **Graceful Degradation**: Continue processing even if optional integrations fail

### Performance Optimization

1. **Optimize Lambda Configuration**:
   - Set appropriate memory allocation (512MB-1024MB typically sufficient)
   - Configure timeout based on expected processing time (30-60 seconds)
   - Use provisioned concurrency for consistent performance

2. **Efficient Data Access**:
   - Cache frequently accessed configuration data
   - Use S3 Transfer Acceleration for large documents
   - Implement connection pooling for external APIs

3. **Batch Processing**:
   - Consider batching multiple documents for bulk operations
   - Use SQS FIFO queues for ordered processing when needed

### Testing and Validation

1. **Unit Testing**:
   - Test individual processing functions with mock data
   - Validate event parsing and data transformation logic
   - Test error handling scenarios

2. **Integration Testing**:
   - Test end-to-end flow with sample documents
   - Validate external system integrations
   - Test retry and error recovery mechanisms

3. **Load Testing**:
   - Test with expected document volumes
   - Validate performance under concurrent processing
   - Monitor memory usage and execution duration

## Troubleshooting

### Common Issues and Solutions

#### 1. Lambda Function Not Triggered

**Symptoms**: Documents process successfully but post-processing Lambda never executes

**Troubleshooting Steps**:
1. Verify the `PostProcessingLambdaHookFunctionArn` parameter is correctly configured
2. Check EventBridge rules in the AWS Console
3. Verify Lambda function permissions allow EventBridge invocation
4. Check CloudWatch Logs for EventBridge rule matching

**Solution**:
```bash
# Check EventBridge rules
aws events list-rules --name-prefix "idp-post-processing"

# Test EventBridge rule manually
aws events put-events --entries file://test-event.json
```

#### 2. S3 Access Denied Errors

**Symptoms**: Lambda function fails with S3 access denied errors

**Troubleshooting Steps**:
1. Verify Lambda execution role has S3 permissions
2. Check bucket policies for access restrictions
3. Verify S3 object keys are correct
4. Check for S3 encryption requirements

**Solution**:
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": [
    "arn:aws:s3:::output-bucket/*"
  ]
}
```

#### 3. Processing Timeout Issues

**Symptoms**: Lambda function times out during processing

**Troubleshooting Steps**:
1. Monitor CloudWatch metrics for execution duration
2. Identify bottlenecks in processing logic
3. Consider increasing Lambda timeout
4. Optimize data processing algorithms

**Solution**:
```python
# Implement processing with timeout checks
import signal

class TimeoutError(Exception):
    pass

def timeout_handler(signum, frame):
    raise TimeoutError("Processing timeout")

def process_with_timeout(document_data, timeout_seconds=50):
    # Set up timeout handler
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(timeout_seconds)
    
    try:
        result = process_document_data(document_data)
        signal.alarm(0)  # Cancel timeout
        return result
    except TimeoutError:
        logger.error("Processing timed out, implementing graceful shutdown")
        # Implement graceful shutdown logic
        raise
```

### Debugging Tools

1. **CloudWatch Logs Insights**: Query logs across multiple executions
2. **X-Ray Tracing**: Enable X-Ray for detailed execution tracing
3. **Lambda Test Events**: Create test events for debugging
4. **Local Testing**: Use SAM CLI for local Lambda testing

### Performance Monitoring

Monitor these key metrics:
- **Invocation Rate**: Number of documents processed per hour
- **Error Rate**: Percentage of failed post-processing attempts
- **Execution Duration**: Average and maximum processing time
- **Memory Utilization**: Peak memory usage during processing
- **External API Response Time**: Latency for downstream integrations

Set up CloudWatch dashboards to track these metrics and identify performance trends over time.
