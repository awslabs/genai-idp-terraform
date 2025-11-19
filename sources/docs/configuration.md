Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Configuration and Customization

The GenAIIDP solution provides multiple configuration approaches to customize document processing behavior to suit your specific needs.

## Pattern Configuration via Web UI

The web interface allows real-time configuration updates without stack redeployment:

- **Document Classes**: Define and modify document categories and their descriptions
- **Extraction Attributes**: Configure fields to extract for each document class
- **Few Shot Examples**: Upload and configure example documents to improve accuracy (supported in Pattern 2)
- **Model Selection**: Choose between available Bedrock models for classification and extraction
- **Prompt Engineering**: Customize system and task prompts for optimal results
- **OCR Features**: Configure Textract features (TABLES, FORMS, SIGNATURES, LAYOUT) for enhanced data capture
- **Evaluation Methods**: Set evaluation methods and thresholds for each attribute
- **Summarization**: Configure model, prompts, and parameters for document summarization (when `IsSummarizationEnabled` is true)

### Configuration Management Features

- **Save as Default**: Save your current configuration as the new default baseline. This replaces the existing default configuration and automatically clears custom overrides. **Warning**: Default configurations may be overwritten during solution upgrades - export your configuration first for backup.
- **Export Configuration**: Download your current configuration to local files in JSON or YAML format with customizable filenames. Use this to backup configurations before upgrades or share configurations between environments.
- **Import Configuration**: Upload configuration files from your local machine in JSON or YAML format. The system automatically detects the file format and validates the configuration before applying changes.
- **Restore Default**: Reset all configuration settings back to the original default values, removing all customizations.

Configuration changes are validated and applied immediately, with rollback capability if issues arise. See [web-ui.md](web-ui.md) for details on using the administration interface.

## Stack Parameters

Key parameters that can be configured during CloudFormation deployment:

### General Parameters
- `AdminEmail`: Administrator email for web UI access
- `AllowedSignUpEmailDomain`: Optional domain(s) allowed for web UI user signup
- `MaxConcurrentWorkflows`: Control concurrent document processing (default: 100)
- `DataRetentionInDays`: Set retention period for documents and tracking records (default: 365 days)
- `ErrorThreshold`: Number of workflow errors that trigger alerts (default: 1)
- `ExecutionTimeThresholdMs`: Maximum acceptable execution time before alerting (default: 30000 ms)
- `LogLevel`: Set logging level (DEBUG, INFO, WARN, ERROR)
- `WAFAllowedIPv4Ranges`: IP restrictions for web UI access (default: allow all)
- `CloudFrontPriceClass`: Set CloudFront price class for UI distribution
- `CloudFrontAllowedGeos`: Optional geographic restrictions for UI access

### Pattern Selection
- `IDPPattern`: Select processing pattern:
  - Pattern1: Packet or Media processing with Bedrock Data Automation (BDA)
  - Pattern2: Packet processing with Textract and Bedrock
  - Pattern3: Packet processing with Textract, SageMaker(UDOP), and Bedrock

### Pattern-Specific Parameters
- **Pattern 1 (BDA)**
  - `Pattern1BDAProjectArn`: Optional existing Bedrock Data Automation project ARN
  - `Pattern1Configuration`: Configuration preset to use

- **Pattern 2 (Textract + Bedrock)**
  - `Pattern2Configuration`: Configuration preset (default, few_shot_example_with_multimodal_page_classification, medical_records_summarization)
  - `Pattern2CustomClassificationModelARN`: Optional custom fine-tuned classification model (Coming Soon)
  - `Pattern2CustomExtractionModelARN`: Optional custom fine-tuned extraction model (Coming Soon)

- **Pattern 3 (Textract + UDOP + Bedrock)**
  - `Pattern3UDOPModelArtifactPath`: S3 path for UDOP model artifact
  - `Pattern3Configuration`: Configuration preset to use

### Optional Features
- `IsSummarizationEnabled`: Enable/disable document summarization (default: true)
- `EvaluationBaselineBucketName`: Optional existing bucket for ground truth data
- `EvaluationAutoEnabled`: Enable automatic accuracy evaluation (default: true)
- `DocumentKnowledgeBase`: Enable document knowledge base functionality
- `KnowledgeBaseModelId`: Bedrock model for knowledge base queries
- `PostProcessingLambdaHookFunctionArn`: Optional Lambda ARN for custom post-processing
- `BedrockGuardrailId`: Optional Bedrock Guardrail ID to apply
- `BedrockGuardrailVersion`: Version of Bedrock Guardrail to use

For details on specific patterns, see [pattern-1.md](pattern-1.md), [pattern-2.md](pattern-2.md), and [pattern-3.md](pattern-3.md).

## High Volume Processing

### Request Service Quota Limits

For high-volume document processing, consider requesting increases for these service quotas:

- **Lambda Concurrent Executions**: Default 1,000 per region
- **Step Functions Executions**: Default 25,000 per second (Standard workflow)
- **Bedrock Model Invocations**: Varies by model and region
  - Claude models: Typically 5-20 requests per minute by default
  - Titan models: 15-30 requests per minute by default
- **SQS Message Rate**: Default 300 per second for FIFO queues
- **TextractLimitPage API**: 15 transactions per second by default
- **DynamoDB Read/Write Capacity**: Uses on-demand capacity by default

Use the AWS Service Quotas console to request increases before deploying for production workloads. See [monitoring.md](monitoring.md) for details on monitoring your resource usage and quotas.

### Cost Estimation

The solution provides built-in cost estimation capabilities:

- Real-time cost tracking for Bedrock model usage
- Per-document processing cost breakdown
- Historical cost analysis and trends
- Budget alerts and threshold monitoring

See [COST_CALCULATOR.md](../COST_CALCULATOR.md) for detailed cost analysis across different processing volumes.

## Bedrock Guardrail Integration

The solution supports Amazon Bedrock Guardrails for content safety and compliance across all patterns:

### How Guardrails Work

Guardrails provide:
- **Content Filtering**: Block harmful, inappropriate, or sensitive content
- **Topic Restrictions**: Prevent processing of specific topic areas
- **Data Protection**: Redact or block personally identifiable information (PII)
- **Custom Filters**: Define organization-specific content policies

### Configuring Guardrails

Guardrails are configured with two CloudFormation parameters:
- `BedrockGuardrailId`: The ID (not name) of an existing Bedrock Guardrail
- `BedrockGuardrailVersion`: The version of the guardrail to use (e.g., "DRAFT" or "1")

This applies guardrails to all Bedrock model interactions, including:
- Document extraction (all patterns)
- Document summarization (all patterns) 
- Document classification (Pattern 2 only)
- Knowledge base queries (if enabled)

### Best Practices

1. **Test Thoroughly**: Validate guardrail behavior with representative documents
2. **Monitor Impact**: Track processing latency and accuracy changes
3. **Regular Updates**: Review and update guardrail policies as requirements evolve
4. **Compliance Alignment**: Ensure guardrails align with organizational compliance requirements

For more information on creating and managing Guardrails, see the [Amazon Bedrock documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html).

## Concurrency and Throttling Management

The solution implements sophisticated concurrency control and throttling management:

### Throttling and Retry (Bedrock, Textract, SageMaker)

- **Exponential Backoff**: Automatic retry with increasing delays
- **Jitter Addition**: Random delay variation to prevent thundering herd
- **Circuit Breaker**: Temporary halt on repeated failures
- **Rate Limiting**: Configurable request rate controls

The solution tracks metrics for throttling events and successful retries, viewable in the CloudWatch dashboard.

### Step Functions Retry Configuration

The Step Functions state machine includes comprehensive retry policies for API failures:

```json
{
  "Retry": [
    {
      "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
      "IntervalSeconds": 2,
      "MaxAttempts": 6,
      "BackoffRate": 2
    },
    {
      "ErrorEquals": ["States.TaskFailed"],
      "IntervalSeconds": 1,
      "MaxAttempts": 3,
      "BackoffRate": 2
    }
  ]
}
```

### Concurrency Control

- **Workflow Limits**: Maximum concurrent Step Function executions, controlled by `MaxConcurrentWorkflows` parameter
- **Lambda Concurrency**: Per-function concurrent execution limits
- **Queue Management**: SQS visibility timeout (30 seconds) and message batching
- **Dynamic Scaling**: Automatic adjustment based on queue depth and in-flight workflows

## Document Status Tracking

The solution provides multiple ways to track document processing status:

### Using the Web UI

The web UI dashboard provides a real-time view of document processing status, including:
- Document status (queued, processing, completed, failed)
- Processing time
- Classification results
- Extraction results
- Error details (if applicable)

See [web-ui.md](web-ui.md) for details on using the dashboard.

### Using the Lookup Script

Use the included script to check document processing status via CLI:

```bash
bash scripts/lookup_file_status.sh <STACK_NAME> <DOCUMENT_KEY>
```

or directly using the Lambda function:

```bash
aws lambda invoke \
  --function-name <STACK_NAME>-LookupFunction \
  --payload '{"document_key":"<DOCUMENT_KEY>"}' \
  output.json && cat output.json | jq
```

### Response Format

Status lookup returns comprehensive information:

```json
{
  "document_key": "example.pdf",
  "status": "COMPLETED",
  "workflow_arn": "arn:aws:states:...",
  "start_time": "2024-01-01T12:00:00Z",
  "end_time": "2024-01-01T12:05:30Z",
  "processing_time_seconds": 330,
  "pages_processed": 15,
  "document_class": "BankStatement",
  "attributes_found": 12,
  "output_location": "s3://output-bucket/results/example.json",
  "error_details": null
}
```

## Cost Tracking and Optimization

The solution includes built-in cost tracking capabilities:

- **Per-document cost metrics**: Track token usage and API calls per document
- **Real-time dashboards**: Monitor costs in the CloudWatch dashboard
- **Cost estimation**: Configuration includes pricing estimates for each component

For detailed cost analysis and optimization strategies, see [cost-calculator.md](cost-calculator.md).

## Image Processing Configuration

The solution supports configurable image dimensions across all processing services (OCR, classification, extraction, and assessment) to optimize performance and accuracy for different document types.

### New Default Behavior (Preserves Original Resolution)

**Important Change**: As of the latest version, empty strings or unspecified image dimensions now preserve the original document resolution instead of resizing to default dimensions.

```yaml
# Preserves original image resolution (recommended for high-accuracy processing)
classification:
  image:
    target_width: ""     # Empty string = no resizing
    target_height: ""    # Empty string = no resizing

extraction:
  image:
    target_width: ""     # Preserves original resolution
    target_height: ""    # Preserves original resolution

assessment:
  image:
    target_width: ""     # No resizing applied
    target_height: ""    # No resizing applied
```

### Custom Image Dimensions

You can still specify exact dimensions when needed for performance optimization:

```yaml
# Custom dimensions for specific requirements
classification:
  image:
    target_width: "1200"   # Resize to 1200 pixels wide
    target_height: "1600"  # Resize to 1600 pixels tall

# Performance-optimized dimensions
extraction:
  image:
    target_width: "800"    # Smaller for faster processing
    target_height: "1000"  # Maintains good quality
```

### Image Resizing Features

- **Aspect Ratio Preservation**: Images are resized proportionally without distortion
- **Smart Scaling**: Only downsizes images when necessary (scale factor < 1.0)
- **High-Quality Resampling**: Better visual quality after resizing
- **Original Format Preservation**: Maintains PNG, JPEG, and other formats when possible

### Configuration Benefits

- **High-Resolution Processing**: Empty strings preserve full document resolution for maximum OCR accuracy
- **Service-Specific Tuning**: Each service can use optimal image dimensions
- **Runtime Configuration**: No code changes needed to adjust image processing
- **Backward Compatibility**: Existing numeric values continue to work as before
- **Memory Optimization**: Configurable dimensions allow resource optimization

### Best Practices

1. **Use Empty Strings for High Accuracy**: For critical documents requiring maximum OCR accuracy, use empty strings to preserve original resolution
2. **Specify Dimensions for Performance**: For high-volume processing, consider smaller dimensions to improve speed
3. **Test Different Settings**: Evaluate the trade-off between accuracy and performance for your specific document types
4. **Monitor Resource Usage**: Higher resolution images consume more memory and processing time

### Migration from Previous Versions

**Previous Behavior**: Empty strings defaulted to 951x1268 pixel resizing
**New Behavior**: Empty strings preserve original image resolution

If you were relying on the previous default resizing behavior, explicitly set dimensions:

```yaml
# To maintain previous default behavior
classification:
  image:
    target_width: "951"
    target_height: "1268"
```

## Additional Configuration Resources

The solution provides additional configuration options through:

- Configuration files in the `config_library` directory
- Pattern-specific settings in each pattern's subdirectory
- Environment variables for Lambda functions
- CloudWatch alarms and notification settings

See the [README.md](../README.md) for a high-level overview of the solution architecture and components.
