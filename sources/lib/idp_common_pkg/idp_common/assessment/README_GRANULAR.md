# Granular Assessment Service

## Overview

The Granular Assessment Service provides a more scalable and accurate approach to document extraction confidence assessment by breaking down the assessment process into smaller, focused inferences. This approach addresses the limitations of the original single-inference method, especially for documents with complex structures or large lists of attributes.

## Key Benefits

### 1. **Improved Accuracy**
- Smaller, focused prompts for each assessment task
- Reduced complexity leads to better LLM performance
- Individual attention to each attribute or list item

### 2. **Cost Optimization**
- Leverages prompt caching to reduce token usage
- Caches document content, images, and attribute definitions
- Only varies the specific attributes being assessed

### 3. **Reduced Latency**
- Parallel processing of independent assessment tasks
- Configurable thread pool for concurrent execution
- Maintains order for list items while processing in parallel

### 4. **Better Scalability**
- Handles documents with hundreds of transactions or attributes
- Adaptive batching based on attribute complexity
- Configurable batch sizes for optimal performance

## Architecture

### Assessment Task Types

1. **Simple Batch Tasks**: Groups of simple attributes assessed together
2. **Group Tasks**: Complex nested attributes assessed as a unit
3. **List Item Tasks**: Individual items in lists (e.g., transactions) assessed separately

### Prompt Structure

The granular service uses the same `task_prompt` template as the original service, but with dynamic placeholder behavior:

```
[Static cached content:]
- Document context and class information
- All attribute definitions (filtered per task)
- Document text and images
- OCR confidence data
<<CACHEPOINT>>
[Dynamic content:]
- Specific attributes to assess (task-focused)
- Relevant extraction results (task-scoped)
```

#### Dynamic Placeholder Behavior

- **`{ATTRIBUTE_NAMES_AND_DESCRIPTIONS}`**: Filtered to show only task-relevant attributes
- **`{EXTRACTION_RESULTS}`**: Contains only the data for the current task
- **`{GRANULAR_CONTEXT}`**: Provides task-specific context (e.g., "focusing on 3 simple attributes")
- **`{DOCUMENT_CLASS}`**, **`{DOCUMENT_TEXT}`**, **`{OCR_TEXT_CONFIDENCE}`**: Remain the same across all tasks

### Processing Flow

1. **Task Creation**: Break down attributes into appropriate assessment tasks
2. **Base Prompt Building**: Create cacheable portion with document context
3. **Parallel Processing**: Execute tasks concurrently using ThreadPoolExecutor
4. **Result Aggregation**: Combine individual results into final assessment structure
5. **Alert Generation**: Check confidence thresholds and generate alerts

## Configuration

### Basic Configuration

```yaml
assessment:
  # Standard assessment configuration
  default_confidence_threshold: '0.8'
  model: us.anthropic.claude-3-7-sonnet-20250219-v1:0
  system_prompt: "Your assessment system prompt..."
  task_prompt: "Your assessment task prompt with <<CACHEPOINT>>..."
  
  # Granular assessment configuration
  granular:
    # Enable granular assessment
    enabled: true
    
    # Parallel processing settings
    max_workers: '6'
    
    # Batching configuration
    simple_batch_size: '3'    # How many simple attributes per batch
    list_batch_size: '1'      # How many list items per batch (usually 1)
    
```

### Attribute-Level Configuration

```yaml
classes:
  - name: Bank Statement
    attributes:
      - name: Account Number
        attributeType: simple
        confidence_threshold: 0.95  # Higher threshold for critical data
        
      - name: Account Holder Address
        attributeType: group
        confidence_threshold: 0.9   # Group-level threshold
        groupAttributes:
          - name: Street Number
            confidence_threshold: 0.95
          - name: City
            confidence_threshold: 0.9
            
      - name: Transactions
        attributeType: list
        confidence_threshold: 0.8   # List-level threshold
        listItemTemplate:
          itemAttributes:
            - name: Date
              confidence_threshold: 0.9
            - name: Amount
              confidence_threshold: 0.95
```

## Usage

### Using the Factory Function

```python
from idp_common.assessment import create_assessment_service

# Load your configuration
config = load_config("config_granular_assessment.yaml")

# Create the appropriate service based on configuration
assessment_service = create_assessment_service(
    region="us-west-2",
    config=config
)

# Process document (same interface for both services)
document = assessment_service.assess_document(document)
```

### Direct Usage

```python
from idp_common.assessment import GranularAssessmentService

# Create granular service directly
service = GranularAssessmentService(
    region="us-west-2",
    config=config
)

# Process a specific section
document = service.process_document_section(document, section_id)
```

## Performance Considerations

### Model Selection

The granular approach works best with models that support prompt caching:
- `us.anthropic.claude-3-5-haiku-20241022-v1:0`
- `us.anthropic.claude-3-7-sonnet-20250219-v1:0`
- `us.amazon.nova-lite-v1:0`
- `us.amazon.nova-pro-v1:0`

### Batch Size Tuning

- **Simple Batch Size**: 3-5 attributes work well together
- **List Batch Size**: Usually 1 for best accuracy, can be increased for speed
- **Max Workers**: 4-8 workers typically provide good parallelization

### Cost Optimization

With prompt caching enabled:
- First assessment task pays full token cost
- Subsequent tasks only pay for cache read + new content
- Significant savings for documents with many attributes

## Monitoring and Metrics

### Custom Metrics

The granular service publishes additional metrics:
- `InputDocumentsForGranularAssessment`
- `InputDocumentPagesForGranularAssessment`

### Metadata

Assessment results include additional metadata:
```json
{
  "metadata": {
    "granular_assessment_used": true,
    "assessment_tasks_total": 25,
    "assessment_tasks_successful": 24,
    "assessment_tasks_failed": 1,
    "assessment_time_seconds": 12.5
  }
}
```

## Error Handling

### Task-Level Failures

- Individual task failures don't stop the entire assessment
- Failed tasks are logged and reported in metadata
- Default confidence scores assigned for failed assessments

### Graceful Degradation

- Falls back to sequential processing if parallel execution fails
- Continues with remaining tasks if some fail
- Provides detailed error reporting

## Migration Guide

### From Original to Granular

1. **Update Configuration**: Add granular section to assessment config
2. **Enable Gradually**: Start with `enabled: false` and test
3. **Tune Parameters**: Adjust batch sizes and worker count
4. **Monitor Performance**: Compare accuracy and cost metrics

### Backward Compatibility

- Original `AssessmentService` remains unchanged
- Factory function automatically selects appropriate service
- Same interface for both services
- Existing code continues to work without changes

## Example Results

### Original Approach
```json
{
  "Account Number": {
    "confidence": 0.95,
    "confidence_reason": "Clear evidence found"
  },
  "Transactions": [
    {
      "Date": {"confidence": 0.9},
      "Amount": {"confidence": 0.85}
    }
  ]
}
```

### Granular Approach
```json
{
  "Account Number": {
    "confidence": 0.95,
    "confidence_reason": "Clear evidence found",
    "confidence_threshold": 0.95
  },
  "Transactions": [
    {
      "Date": {
        "confidence": 0.92,
        "confidence_reason": "Clear date format",
        "confidence_threshold": 0.9
      },
      "Amount": {
        "confidence": 0.98,
        "confidence_reason": "Unambiguous numeric value",
        "confidence_threshold": 0.95
      }
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **High Latency**: Reduce `max_workers` or increase `simple_batch_size`
2. **Cost Concerns**: Ensure caching is enabled and model supports it
3. **Accuracy Issues**: Reduce batch sizes for more focused assessments
4. **Memory Usage**: Lower `max_workers` for memory-constrained environments

### Debugging

Enable debug logging to see task creation and execution:
```python
import logging
logging.getLogger('idp_common.assessment.granular_service').setLevel(logging.DEBUG)
```

## Best Practices

1. **Start Conservative**: Begin with smaller batch sizes and fewer workers
2. **Monitor Costs**: Track cache hit rates and token usage
3. **Tune Thresholds**: Set appropriate confidence thresholds per attribute type
4. **Test Thoroughly**: Compare results with original approach during migration
5. **Scale Gradually**: Increase parallelization as you gain confidence

## Future Enhancements

- Adaptive batch sizing based on document complexity
- Smart task scheduling based on attribute dependencies
- Enhanced caching strategies for multi-document processing
- Integration with evaluation metrics for continuous improvement
