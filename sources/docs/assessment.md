# Assessment Feature

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

## Overview

The Assessment feature provides automated confidence evaluation of document extraction results using Large Language Models (LLMs). This feature analyzes extraction outputs against source documents to provide confidence scores and explanations for each extracted attribute, helping users understand the reliability of automated extractions.

## Key Features

- **Multimodal Analysis**: Combines text analysis with document images for comprehensive confidence assessment
- **Per-Attribute Scoring**: Provides individual confidence scores and explanations for each extracted attribute
- **Token-Optimized Processing**: Uses condensed text confidence data for 80-90% token reduction compared to full OCR results
- **UI Integration**: Seamlessly displays assessment results in the web interface with explainability information
- **Confidence Threshold Support**: Configurable global and per-attribute confidence thresholds with color-coded visual indicators
- **Enhanced Visual Feedback**: Real-time confidence assessment with green/red/black color coding in all data viewing interfaces
- **Optional Deployment**: Controlled by `IsAssessmentEnabled` parameter (defaults to false for cost optimization)
- **Flexible Image Usage**: Images only processed when explicitly requested via `{DOCUMENT_IMAGE}` placeholder
- **Granular Assessment**: Advanced scalable approach for complex documents with many attributes or list items
- **Parallel Processing**: Multi-threaded assessment execution for improved performance
- **Prompt Caching**: Leverages LLM caching capabilities to reduce costs for repeated assessments

## Architecture

### Assessment Workflow

1. **Post-Extraction Processing**: Assessment runs after successful extraction within the same state machine
2. **Document Analysis**: LLM analyzes extraction results against source document text and optionally images
3. **Confidence Scoring**: Generates confidence scores (0.0-1.0) with explanatory reasoning for each attribute
4. **Result Integration**: Appends assessment data to existing extraction results in `explainability_info` format
5. **UI Display**: Assessment results automatically appear in the web interface visual editor

### State Machine Integration

The assessment step is conditionally integrated into Pattern-2's ProcessSections map state:

```json
{
  "AssessSection": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Parameters": {
      "FunctionName": "${AssessmentFunction}",
      "Payload": {
        "document.$": "$.document",
        "section_id.$": "$.section_id"
      }
    },
    "End": true
  }
}
```

## Configuration

### Deployment Parameter

Enable assessment during stack deployment:

```yaml
Parameters:
  IsAssessmentEnabled:
    Type: String
    Default: "false"
    AllowedValues: ["true", "false"]
    Description: Enable assessment functionality for extraction confidence evaluation
```

### Assessment Configuration Section

Add the assessment section to your configuration YAML:

```yaml
assessment:
  model: "anthropic.claude-3-5-sonnet-20241022-v2:0"
  temperature: 0
  top_k: 5
  top_p: 0.1
  max_tokens: 4096
  system_prompt: |
    You are an expert document analyst specializing in assessing the confidence and accuracy of document extraction results.
  task_prompt: |
    Assess the confidence of the following extraction results by analyzing them against the source document.
    
    Document Class: {DOCUMENT_CLASS}
    
    Extraction Results to Assess:
    {EXTRACTION_RESULTS}
    
    Attribute Definitions:
    {ATTRIBUTE_NAMES_AND_DESCRIPTIONS}
    
    Source Document Text:
    {DOCUMENT_TEXT}
    
    OCR Confidence Data:
    {OCR_TEXT_CONFIDENCE}
    
    {DOCUMENT_IMAGE}
    
    Provide a confidence assessment for each extracted attribute. You can respond in either JSON or YAML format:
    
    JSON format:
    {
      "attribute_name": {
        "confidence": 0.85,
        "confidence_reason": "Clear text match found in document with high OCR confidence"
      }
    }
    
    YAML format (more token-efficient):
    attribute_name:
      confidence: 0.85
      confidence_reason: Clear text match found in document with high OCR confidence
```

### Prompt Placeholders

The assessment prompts support the following placeholders:

| Placeholder | Description |
|-------------|-------------|
| `{DOCUMENT_CLASS}` | The classified document type |
| `{EXTRACTION_RESULTS}` | JSON string of extraction results to assess |
| `{ATTRIBUTE_NAMES_AND_DESCRIPTIONS}` | Formatted list of attribute names and descriptions |
| `{DOCUMENT_TEXT}` | Full document text (markdown) from OCR |
| `{OCR_TEXT_CONFIDENCE}` | Condensed OCR confidence data (80-90% token reduction) |
| `{DOCUMENT_IMAGE}` | **Optional** - Inserts document images at specified position |

### Image Processing with DOCUMENT_IMAGE

The `{DOCUMENT_IMAGE}` placeholder enables precise control over image inclusion:

#### Text-Only Assessment (Default)
```yaml
task_prompt: |
  Assess extraction results based on document text and OCR confidence data:
  
  Document Text: {DOCUMENT_TEXT}
  OCR Confidence: {OCR_TEXT_CONFIDENCE}
  Extraction Results: {EXTRACTION_RESULTS}
```

#### Multimodal Assessment
```yaml
task_prompt: |
  Assess extraction results by analyzing both text and visual document content:
  
  Document Text: {DOCUMENT_TEXT}
  
  {DOCUMENT_IMAGE}
  
  Based on the above document image and text, assess these extraction results:
  {EXTRACTION_RESULTS}
```

**Important**: Images are only processed when the `{DOCUMENT_IMAGE}` placeholder is explicitly present in the prompt template.

## Output Format

Assessment results are appended to extraction results in the `explainability_info` format expected by the UI. The format varies based on the attribute type defined in your document class configuration.

### Attribute Types and Assessment Formats

The assessment service supports three types of attributes, each with a specific assessment response format:

#### 1. Simple Attributes

For basic single-value extractions like dates, amounts, or names:

**Configuration:**
```yaml
attributes:
  - name: "StatementDate"
    attributeType: "simple"
    description: "The date of the bank statement"
```

**Assessment Response:**
```json
{
  "StatementDate": {
    "confidence": 0.85,
    "confidence_reason": "Date clearly visible in statement header"
  }
}
```

#### 2. Group Attributes

For nested object structures with multiple related fields:

**Configuration:**
```yaml
attributes:
  - name: "AccountDetails"
    attributeType: "group"
    description: "Bank account information"
    groupAttributes:
      - name: "AccountNumber"
        description: "The account number"
      - name: "RoutingNumber"
        description: "The bank routing number"
```

**Assessment Response:**
```json
{
  "AccountDetails": {
    "AccountNumber": {
      "confidence": 0.90,
      "confidence_reason": "Account number clearly printed in standard location"
    },
    "RoutingNumber": {
      "confidence": 0.75,
      "confidence_reason": "Routing number visible but slightly blurred"
    }
  }
}
```

#### 3. List Attributes

For arrays of items, such as transactions in a bank statement:

**Configuration:**
```yaml
attributes:
  - name: "Transactions"
    attributeType: "list"
    description: "List of all transactions on the statement"
    listItemTemplate:
      itemDescription: "Individual transaction entry"
      itemAttributes:
        - name: "Date"
          description: "Transaction date"
        - name: "Description"
          description: "Transaction description"
        - name: "Amount"
          description: "Transaction amount"
```

**Assessment Response:**
```json
{
  "Transactions": [
    {
      "Date": {
        "confidence": 0.95,
        "confidence_reason": "Date clearly printed in standard format"
      },
      "Description": {
        "confidence": 0.88,
        "confidence_reason": "Description text is clear and readable"
      },
      "Amount": {
        "confidence": 0.92,
        "confidence_reason": "Amount aligned in currency column with clear digits"
      }
    },
    {
      "Date": {
        "confidence": 0.90,
        "confidence_reason": "Date visible but slightly smudged"
      },
      "Description": {
        "confidence": 0.85,
        "confidence_reason": "Description partially cut off but main text readable"
      },
      "Amount": {
        "confidence": 0.94,
        "confidence_reason": "Amount clearly printed with proper decimal alignment"
      }
    }
  ]
}
```

### Complete Example

Here's a complete example showing all three attribute types in a single assessment response:

```json
{
  "inference_result": {
    "StatementDate": "2024-01-31",
    "AccountDetails": {
      "AccountNumber": "1234567890",
      "RoutingNumber": "021000021"
    },
    "Transactions": [
      {
        "Date": "2024-01-15",
        "Description": "Direct Deposit - Salary",
        "Amount": "3500.00"
      },
      {
        "Date": "2024-01-20", 
        "Description": "ATM Withdrawal",
        "Amount": "-200.00"
      }
    ]
  },
  "explainability_info": [
    {
      "StatementDate": {
        "confidence": 0.95,
        "confidence_reason": "Statement date clearly printed in header",
        "confidence_threshold": 0.85
      },
      "AccountDetails": {
        "AccountNumber": {
          "confidence": 0.90,
          "confidence_reason": "Account number clearly visible in account section",
          "confidence_threshold": 0.90
        },
        "RoutingNumber": {
          "confidence": 0.85,
          "confidence_reason": "Routing number printed clearly below account number",
          "confidence_threshold": 0.90
        }
      },
      "Transactions": [
        {
          "Date": {
            "confidence": 0.95,
            "confidence_reason": "Transaction date clearly printed",
            "confidence_threshold": 0.80
          },
          "Description": {
            "confidence": 0.88,
            "confidence_reason": "Description text is clear and complete",
            "confidence_threshold": 0.75
          },
          "Amount": {
            "confidence": 0.92,
            "confidence_reason": "Amount properly aligned in currency format",
            "confidence_threshold": 0.85
          }
        },
        {
          "Date": {
            "confidence": 0.90,
            "confidence_reason": "Date readable with minor print quality issues",
            "confidence_threshold": 0.80
          },
          "Description": {
            "confidence": 0.85,
            "confidence_reason": "Description clear, standard ATM format",
            "confidence_threshold": 0.75
          },
          "Amount": {
            "confidence": 0.94,
            "confidence_reason": "Negative amount clearly indicated with proper formatting",
            "confidence_threshold": 0.85
          }
        }
      ]
    }
  ],
  "metadata": {
    "assessment_time_seconds": 4.12,
    "assessment_parsing_succeeded": true
  }
}
```

### Assessment Response Requirements

**Important Guidelines:**

1. **Match Extraction Structure**: The assessment response must exactly match the structure of the `inference_result`
2. **List Item Assessment**: For list attributes, assess **each individual item** separately, not as an aggregate
3. **Nested Confidence**: Group attributes should have confidence assessments for each sub-attribute
4. **Consistent Format**: Each confidence assessment should include `confidence` (0.0-1.0) and optionally `confidence_reason`
5. **Threshold Integration**: The system automatically adds `confidence_threshold` values based on configuration

## Confidence Thresholds

### Overview

The assessment feature supports flexible confidence threshold configuration to help users identify extraction results that may require review. Thresholds can be set globally or per-attribute, with the UI providing immediate visual feedback through color-coded displays.

### Configuration Options

#### Global Thresholds
Set system-wide confidence requirements for all attributes:

```json
{
  "inference_result": {
    "YTDNetPay": "75000",
    "PayPeriodStartDate": "2024-01-01"
  },
  "explainability_info": [
    {
      "global_confidence_threshold": 0.85,
      "YTDNetPay": {
        "confidence": 0.92,
        "confidence_reason": "Clear match found in document"
      },
      "PayPeriodStartDate": {
        "confidence": 0.75,
        "confidence_reason": "Moderate OCR confidence"
      }
    }
  ]
}
```

#### Per-Attribute Thresholds
Override global settings for specific fields requiring different confidence levels:

```json
{
  "explainability_info": [
    {
      "YTDNetPay": {
        "confidence": 0.92,
        "confidence_threshold": 0.95,
        "confidence_reason": "Financial data requires high confidence"
      },
      "PayPeriodStartDate": {
        "confidence": 0.75,
        "confidence_threshold": 0.70,
        "confidence_reason": "Date fields can accept moderate confidence"
      }
    }
  ]
}
```

#### Mixed Configuration
Combine global defaults with attribute-specific overrides:

```json
{
  "explainability_info": [
    {
      "global_confidence_threshold": 0.80,
      "CriticalField": {
        "confidence": 0.85,
        "confidence_threshold": 0.95,
        "confidence_reason": "Override: higher threshold for critical data"
      },
      "StandardField": {
        "confidence": 0.82,
        "confidence_reason": "Uses global threshold of 0.80"
      }
    }
  ]
}
```

### Assessment Prompt Integration

Include threshold guidance in your assessment prompts to ensure consistent confidence evaluation:

```yaml
assessment:
  task_prompt: |
    Assess extraction confidence using these thresholds as guidance:
    - Financial data (amounts, taxes): 0.90+ confidence required
    - Personal information (names, addresses): 0.85+ confidence required  
    - Dates and standard fields: 0.75+ confidence acceptable
    
    Provide confidence scores between 0.0 and 1.0 with explanatory reasoning:
    {
      "attribute_name": {
        "confidence": 0.85,
        "confidence_threshold": 0.90,
        "confidence_reason": "Explanation of confidence assessment"
      }
    }
```

## UI Integration

Assessment results automatically appear in the web interface with enhanced visual indicators:

### Visual Feedback System

The UI provides immediate confidence feedback through color-coded displays:

#### Color Coding
- 🟢 **Green**: Confidence meets or exceeds threshold (high confidence)
- 🔴 **Red**: Confidence falls below threshold (requires review)
- ⚫ **Black**: Confidence available but no threshold for comparison

#### Display Modes

**1. With Threshold (Color-Coded)**
```
YTDNetPay: 75000
Confidence: 92.0% / Threshold: 95.0% [RED - Below Threshold]

PayPeriodStartDate: 2024-01-01  
Confidence: 85.0% / Threshold: 70.0% [GREEN - Above Threshold]
```

**2. Confidence Only (Black Text)**
```
EmployeeName: John Smith
Confidence: 88.5% [BLACK - No Threshold Set]
```

**3. No Display**
When neither confidence nor threshold data is available, no confidence indicator is shown.

### Interface Coverage

**1. Form View (JSONViewer)**
- Color-coded confidence display in the editable form interface
- Supports nested data structures (arrays, objects)
- Real-time visual feedback during data editing

**2. Visual Editor Modal**
- Same confidence indicators in the document image overlay editor
- Visual connection between form fields and document bounding boxes
- Confidence display for deeply nested extraction results

**3. Nested Data Support**
Confidence indicators work with complex document structures:
```
FederalTaxes[0]:
  ├── YTD: 2111.2 [Confidence: 67.6% / Threshold: 85.0% - RED]
  └── Period: 40.6 [Confidence: 75.8% - BLACK]

StateTaxes[0]:
  ├── YTD: 438.36 [Confidence: 84.4% / Threshold: 80.0% - GREEN]
  └── Period: 8.43 [Confidence: 83.2% / Threshold: 80.0% - GREEN]
```

## Image Processing Configuration

The assessment service supports configurable image dimensions for optimal confidence evaluation:

### New Default Behavior (Preserves Original Resolution)

**Important Change**: Empty strings or unspecified image dimensions now preserve the original document resolution for maximum assessment accuracy:

```yaml
assessment:
  model: "us.amazon.nova-lite-v1:0"
  # Image processing settings - preserves original resolution
  image:
    target_width: ""     # Empty string = no resizing (recommended)
    target_height: ""    # Empty string = no resizing (recommended)
```

### Custom Image Dimensions

Configure specific dimensions when performance optimization is needed:

```yaml
# For detailed visual assessment with controlled dimensions
assessment:
  image:
    target_width: "1200"   # Resize to 1200 pixels wide
    target_height: "1600"  # Resize to 1600 pixels tall

# For standard confidence evaluation
assessment:
  image:
    target_width: "800"    # Smaller for faster processing
    target_height: "1000"  # Maintains good quality
```

### Image Resizing Features for Assessment

- **Original Resolution Preservation**: Empty strings preserve full document resolution for maximum assessment accuracy
- **Aspect Ratio Preservation**: Images maintain proportions for accurate visual analysis when dimensions are specified
- **Smart Scaling**: Only downsizes when necessary to preserve visual detail
- **High-Quality Resampling**: Better image quality for confidence assessment
- **Performance Optimization**: Configurable dimensions allow balancing accuracy vs. speed

### Configuration Benefits for Assessment

- **Maximum Assessment Accuracy**: Empty strings preserve full document resolution for best confidence evaluation
- **Enhanced Visual Analysis**: Original resolution improves confidence evaluation accuracy
- **Better OCR Verification**: Higher quality images help verify extraction results against visual content
- **Improved Confidence Scoring**: Better image quality leads to more accurate confidence assessments
- **Service-Specific Tuning**: Optimize image dimensions for different assessment complexity levels
- **Resource Optimization**: Choose between accuracy (original resolution) and performance (smaller dimensions)

### Migration from Previous Versions

**Previous Behavior**: Empty strings defaulted to 951x1268 pixel resizing
**New Behavior**: Empty strings preserve original image resolution

If you were relying on the previous default resizing behavior, explicitly set dimensions:

```yaml
# To maintain previous default behavior
assessment:
  image:
    target_width: "951"
    target_height: "1268"
```

### Best Practices for Assessment

1. **Use Empty Strings for High Accuracy**: For critical confidence assessment, use empty strings to preserve original resolution
2. **Consider Assessment Complexity**: Complex documents with fine details benefit from higher resolution
3. **Test Assessment Quality**: Evaluate confidence assessment accuracy with your specific document types
4. **Monitor Resource Usage**: Higher resolution images consume more memory and processing time
5. **Balance Accuracy vs Performance**: Choose appropriate settings based on your assessment requirements and processing volume

## Granular Assessment

### Overview

For complex documents with many attributes or large lists (such as bank statements with hundreds of transactions), the standard assessment approach can become inefficient and less accurate. The **Granular Assessment** feature addresses these challenges by breaking down the assessment process into smaller, focused tasks that can be processed in parallel.

### When to Use Granular Assessment

Consider granular assessment for:
- **Documents with many attributes** (10+ simple attributes)
- **Large list structures** (bank transactions, line items, etc.)
- **Complex nested data** (multiple group attributes)
- **Performance-critical scenarios** where parallel processing provides benefits
- **Cost optimization** when prompt caching is available

### Key Benefits

1. **Improved Accuracy**: Smaller, focused prompts lead to better LLM performance
2. **Cost Optimization**: Leverages prompt caching to reduce token usage significantly
3. **Reduced Latency**: Parallel processing of independent assessment tasks
4. **Better Scalability**: Handles documents with hundreds of attributes or list items

### Configuration

Enable granular assessment by adding the `granular` section to your assessment configuration:

```yaml
assessment:
  # Standard assessment configuration
  model: "us.anthropic.claude-3-7-sonnet-20250219-v1:0"
  temperature: 0
  system_prompt: "You are an expert document analyst..."
  task_prompt: |
    Assess the confidence of extraction results for this {DOCUMENT_CLASS} document.
    
    Attributes to assess:
    {ATTRIBUTE_NAMES_AND_DESCRIPTIONS}
    
    Extraction results:
    {EXTRACTION_RESULTS}
    
    Document context:
    {DOCUMENT_TEXT}
    {OCR_TEXT_CONFIDENCE}
    {DOCUMENT_IMAGE}
    
    Provide confidence assessments in JSON format.
  
  # Granular assessment configuration
  granular:
    max_workers: 6              # Number of parallel threads
    simple_batch_size: 3        # Attributes per simple batch
    list_batch_size: 1          # List items per batch (usually 1)
```

### How It Works

The granular assessment service automatically:

1. **Analyzes attribute structure** to determine optimal task breakdown
2. **Creates focused tasks**:
   - **Simple batches**: Groups of 3-5 simple attributes
   - **Group tasks**: Individual group attributes with their sub-attributes
   - **List item tasks**: Individual items from list attributes
3. **Builds cached base content** with document context and images
4. **Processes tasks in parallel** using configurable thread pool
5. **Aggregates results** into the same format as standard assessment

### Task Types

#### Simple Batch Tasks
Groups simple attributes together for efficient processing:
```yaml
# Configuration with 10 simple attributes
attributes:
  - name: "StatementDate"
  - name: "AccountNumber"
  - name: "RoutingNumber"
  # ... 7 more attributes

# Results in 4 tasks: [3, 3, 3, 1] attributes each
```

#### Group Tasks
Processes complex nested structures as single units:
```yaml
# Each group becomes one focused task
attributes:
  - name: "AccountDetails"
    attributeType: "group"
    groupAttributes:
      - name: "AccountNumber"
      - name: "RoutingNumber"
      - name: "AccountType"
```

#### List Item Tasks
Assesses each list item individually for maximum accuracy:
```yaml
# 100 transactions = 100 individual assessment tasks
attributes:
  - name: "Transactions"
    attributeType: "list"
    listItemTemplate:
      itemAttributes:
        - name: "Date"
        - name: "Description"
        - name: "Amount"
```

### Performance Tuning

#### Batch Size Configuration
```yaml
granular:
  simple_batch_size: 3    # Smaller = more accurate, larger = faster
  list_batch_size: 1      # Usually keep at 1 for best accuracy
  max_workers: 6          # Balance between speed and resource usage
```

#### Model Selection
Granular assessment works best with models supporting prompt caching:
- `us.anthropic.claude-3-7-sonnet-20250219-v1:0` (recommended)
- `us.anthropic.claude-3-5-haiku-20241022-v1:0` (cost-effective)
- `us.amazon.nova-lite-v1:0` or `us.amazon.nova-pro-v1:0`

### Cost Optimization with Caching

The granular approach leverages prompt caching for significant cost savings:

```
First Task:  [Full document context] + [3 attributes] = Full cost
Second Task: [Cached context] + [3 different attributes] = Cache read + new content only
Third Task:  [Cached context] + [3 different attributes] = Cache read + new content only
...
```

**Typical savings**: 60-80% reduction in token costs for documents with many attributes.

### Usage Example

```python
from idp_common.assessment import create_assessment_service

# Load configuration with granular settings
config = {
    "assessment": {
        "model": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        "granular": {
            "max_workers": 6,
            "simple_batch_size": 3,
            "list_batch_size": 1
        }
        # ... other assessment config
    }
}

# Factory function automatically selects granular service
assessment_service = create_assessment_service(
    region="us-west-2",
    config=config
)

# Same interface as standard assessment
document = assessment_service.assess_document(document)
```

### Monitoring Granular Assessment

Granular assessment provides additional metadata:

```json
{
  "metadata": {
    "granular_assessment_used": true,
    "assessment_tasks_total": 25,
    "assessment_tasks_successful": 24,
    "assessment_tasks_failed": 1,
    "assessment_time_seconds": 8.5
  }
}
```

### Migration from Standard Assessment

1. **Add granular configuration** to existing assessment config
2. **Test with small documents** first to validate behavior
3. **Tune batch sizes** based on your document complexity
4. **Monitor performance** and cost metrics
5. **Gradually roll out** to production workloads

The granular service maintains full backward compatibility - existing configurations continue to work without changes.

## Cost Optimization

### Token Reduction Strategy

The assessment feature implements several cost optimization techniques:

1. **Text Confidence Data**: Uses condensed OCR confidence information instead of full raw OCR results (80-90% token reduction)
2. **Conditional Image Processing**: Images only processed when `{DOCUMENT_IMAGE}` placeholder is present
3. **Optional Deployment**: Assessment infrastructure only deployed when `IsAssessmentEnabled=true`
4. **Efficient Prompting**: Optimized prompt templates minimize token usage while maintaining accuracy
5. **Configurable Image Dimensions**: Adjust image resolution to balance assessment quality and processing costs
6. **Granular Assessment with Caching**: For complex documents, use granular assessment with prompt caching for 60-80% cost reduction


## Testing and Validation

### End-to-End Testing

Use the provided notebooks for comprehensive testing:

```bash
# Standard assessment testing
jupyter notebook notebooks/e2e-example-with-assessment.ipynb

# Granular assessment testing
jupyter notebook notebooks/examples/step4_assessment_granular.ipynb
```

The notebooks demonstrate:
- Document processing with assessment enabled
- Confidence score interpretation
- Integration with existing extraction workflows
- Performance and cost analysis
- Granular assessment configuration and usage

### Configuration Validation

Assessment enforces strict configuration requirements:

```python
# Missing prompt template
ValueError: "Assessment task_prompt is required in configuration but not found"

# Invalid DOCUMENT_IMAGE usage
ValueError: "Invalid DOCUMENT_IMAGE placeholder usage: found 2 occurrences, but exactly 1 is required"

# Template formatting error
ValueError: "Assessment prompt template formatting failed: missing required placeholder"
```

## Best Practices

### 1. Prompt Design

- **Be Specific**: Clearly define what constitutes high vs. low confidence
- **Include Examples**: Provide examples of confidence reasoning in system prompts
- **Use Structured Output**: Request consistent JSON format for programmatic processing

### 2. Cost Management

- **Enable Selectively**: Only enable assessment for critical document types
- **Text-First**: Start with text-only assessment before adding images
- **Monitor Usage**: Track token consumption and adjust prompts accordingly

### 3. Model Selection

- **Claude 3.5 Sonnet**: Recommended for balanced performance and cost
- **Claude 3 Haiku**: Consider for high-volume, cost-sensitive scenarios
- **Temperature 0**: Use deterministic output for consistent confidence scoring

### 4. Confidence Threshold Configuration

- **Risk-Based Thresholds**: Set higher thresholds (0.90+) for critical financial or personal data
- **Field-Specific Requirements**: Use per-attribute thresholds for different data types
- **Global Defaults**: Establish reasonable global thresholds (0.75-0.85) as baselines
- **Incremental Tuning**: Start with conservative thresholds and adjust based on accuracy analysis

### 5. Integration Patterns

- **Conditional Logic**: Implement business rules based on confidence scores and thresholds
- **Human Review**: Route low-confidence extractions (below threshold) for manual review
- **Quality Metrics**: Track confidence distributions to identify improvement opportunities
- **Visual Feedback**: Leverage color-coded UI indicators for immediate quality assessment

## Troubleshooting

### Common Issues

1. **Assessment Not Running**
   - Verify `IsAssessmentEnabled=true` in deployment
   - Check state machine definition includes assessment step
   - Confirm assessment Lambda function deployed successfully

2. **Template Errors**
   - Ensure `task_prompt` is defined in assessment configuration
   - Validate placeholder syntax and formatting
   - Check for exactly one `{DOCUMENT_IMAGE}` placeholder if using images

3. **Poor Confidence Scores**
   - Review prompt templates for clarity and specificity
   - Consider adding domain-specific guidance in system prompts
   - Validate OCR quality and text confidence data

4. **High Costs**
   - Monitor token usage in CloudWatch logs
   - Consider text-only assessment without images
   - Optimize prompt templates to reduce unnecessary context

5. **Confidence Threshold Issues**
   - Verify `confidence_threshold` values are between 0.0 and 1.0
   - Check explainability_info structure includes threshold data
   - Ensure UI displays match expected color coding (green/red/black)
   - Validate nested data confidence display for complex structures

### Monitoring

Key metrics to monitor:

- `InputDocumentsForAssessment`: Number of documents assessed
- `assessment_time_seconds`: Processing time per assessment
- `assessment_parsing_succeeded`: Success rate of JSON parsing
- Token consumption logs in CloudWatch

## Related Documentation

- [Pattern 2 Documentation](./pattern-2.md) - Assessment integration details
- [Configuration Guide](./configuration.md) - Configuration schema details
- [Extraction Documentation](./extraction.md) - Base extraction functionality
- [Web UI Documentation](./web-ui.md) - UI integration and display
