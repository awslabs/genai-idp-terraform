Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Evaluation Service

The Evaluation Service component provides functionality to evaluate document extraction results by comparing extracted attributes against expected values.

## Features

- Compares document extraction results with expected (ground truth) results
- Supports multiple evaluation methods:
  - Exact match - Character-for-character comparison after normalizing whitespace and punctuation
  - Numeric exact match - Value-based comparison after normalizing numeric formats
  - Fuzzy string matching - Similarity-based matching with configurable thresholds
  - Hungarian algorithm - Optimal matching for lists of values
  - Semantic similarity - Meaning-based comparison using Bedrock Titan embeddings
  - LLM-based semantic evaluation - Advanced meaning comparison with explanation using Bedrock models
- Smart attribute discovery and evaluation:
  - Automatically discovers attributes in the extraction results not defined in the configuration
  - Handles attributes found only in expected data, only in actual data, or in both
  - Applies default comparison method (LLM) for unconfigured attributes with clear indication
- **Assessment Confidence Integration**:
  - Automatically extracts and displays confidence scores from assessment results
  - Shows confidence (extraction confidence)
  - Integrates with explainability_info from the assessment feature
  - Provides insights into data quality for both baseline and extraction results
- Calculates key metrics including:
  - Precision, Recall, and F1 score
  - Accuracy and Error rates
  - False alarm rate and False discovery rate
- Generates rich, visual evaluation reports with:
  - Color-coded status indicators
  - Performance ratings
  - Progress bar visualizations
  - Detailed attribute comparisons
  - Confidence score columns for quality analysis
- Supports both JSON and Markdown report formats
- Fully integrated with the Document model architecture

## Usage

```python
from idp_common.models import Document, Status
from idp_common import ocr, classification, extraction, evaluation

# Get configuration (with evaluation methods specified for all attribute types)
config = {
    "evaluation": {
        "llm_method": {
            "model": "anthropic.claude-3-sonnet-20240229-v1:0",
            "temperature": 0.0,
            "top_k": 5,
            "system_prompt": "You are an evaluator that helps determine if the predicted and expected values match...",
            "task_prompt": "I need to evaluate attribute extraction for a document of class: {DOCUMENT_CLASS}..."
        }
    },
    "classes": [
        {
            "name": "Bank Statement",
            "attributes": [
                # Simple Attributes
                {
                    "name": "Account Number",
                    "description": "Primary account identifier",
                    "attributeType": "simple",  # or omit for default
                    "evaluation_method": "EXACT"
                },
                {
                    "name": "Statement Period",
                    "description": "Statement period (e.g., January 2024)",
                    "attributeType": "simple",
                    "evaluation_method": "FUZZY",
                    "evaluation_threshold": 0.8
                },
                
                # Group Attributes - nested object structures
                {
                    "name": "Account Holder Address",
                    "description": "Complete address information for the account holder",
                    "attributeType": "group",
                    "groupAttributes": [
                        {
                            "name": "Street Number",
                            "description": "House or building number",
                            "evaluation_method": "FUZZY",
                            "evaluation_threshold": 0.9
                        },
                        {
                            "name": "Street Name",
                            "description": "Name of the street",
                            "evaluation_method": "FUZZY",
                            "evaluation_threshold": 0.8
                        },
                        {
                            "name": "City",
                            "description": "City name",
                            "evaluation_method": "FUZZY",
                            "evaluation_threshold": 0.9
                        },
                        {
                            "name": "State",
                            "description": "State abbreviation",
                            "evaluation_method": "EXACT"
                        },
                        {
                            "name": "ZIP Code",
                            "description": "Postal code",
                            "evaluation_method": "EXACT"
                        }
                    ]
                },
                
                # List Attributes - arrays of items with consistent structure
                {
                    "name": "Transactions",
                    "description": "List of all transactions in the statement period",
                    "attributeType": "list",
                    "listItemTemplate": {
                        "itemDescription": "Individual transaction record",
                        "itemAttributes": [
                            {
                                "name": "Date",
                                "description": "Transaction date",
                                "evaluation_method": "FUZZY",
                                "evaluation_threshold": 0.9
                            },
                            {
                                "name": "Description",
                                "description": "Transaction description or merchant name",
                                "evaluation_method": "SEMANTIC",
                                "evaluation_threshold": 0.7
                            },
                            {
                                "name": "Amount",
                                "description": "Transaction amount",
                                "evaluation_method": "NUMERIC_EXACT"
                            }
                        ]
                    }
                }
            ]
        }
    ]
}

# Create evaluation service
evaluation_service = evaluation.EvaluationService(config=config)

# Evaluate documents (stores results in S3 by default)
result_document = evaluation_service.evaluate_document(
    actual_document=processed_document,
    expected_document=expected_document
)

# Access evaluation report URI
evaluation_report_uri = result_document.evaluation_report_uri

# You can also access the evaluation result directly
evaluation_result = result_document.evaluation_result
overall_metrics = evaluation_result.overall_metrics
section_results = evaluation_result.section_results

# Or skip storage if needed (for quick memory-only evaluations)
memory_only_document = evaluation_service.evaluate_document(
    actual_document=processed_document,
    expected_document=expected_document,
    store_results=False
)
```

## Evaluation Methods

The service supports multiple evaluation methods that can be configured for each attribute:

- `EXACT`: Exact string match (after normalizing whitespace and punctuation)
- `NUMERIC_EXACT`: Exact match for numeric values (after normalizing currency symbols)
- `FUZZY`: Fuzzy string matching with configurable evaluation_threshold
- `HUNGARIAN`: Optimal matching for lists of values using the Hungarian algorithm with configurable comparator types:
  - `EXACT`: Default comparator for exact string matching (after normalization)
  - `FUZZY`: Fuzzy string matching with configurable threshold
  - `NUMERIC`: Numeric comparison after normalizing currency symbols and formats
- `SEMANTIC`: Efficient semantic similarity comparison using Bedrock Titan embeddings (amazon.titan-embed-text-v1)
- `LLM`: LLM-based evaluation using Bedrock models (Claude or Titan) for semantically comparable values with detailed explanations

### Semantic vs LLM Evaluation

The service offers two approaches for semantic evaluation:

- **SEMANTIC Method**: Uses embedding-based comparison with Bedrock Titan embeddings
  - Faster and more cost-effective than LLM-based evaluation
  - Provides similarity scores without explanations
  - Great for high-volume comparisons where speed is important
  - Configurable threshold for matching sensitivity
  
- **LLM Method**: Uses Bedrock Claude or other LLM models
  - Provides detailed reasoning for why values match or don't match
  - Better at handling implicit/explicit information differences
  - More nuanced understanding of semantic equivalence
  - Ideal for cases where understanding the rationale is important
  - Used as the default method for attributes discovered in the data but not in the configuration

## Output

The evaluation produces:

1. **JSON Results**: Detailed evaluation results with metrics
2. **Markdown Report**: Human-readable report with tables and summaries

## Metrics

The evaluation calculates the following metrics:

- **Precision**: Accuracy of positive predictions (TP / (TP + FP))
- **Recall**: Coverage of actual positive cases (TP / (TP + FN))
- **F1 Score**: Harmonic mean of precision and recall
- **Accuracy**: Overall correctness (TP + TN) / (TP + TN + FP + FN)
- **False Alarm Rate (FAR)**: Rate of false positives among negatives (FP / (FP + TN))
  - Measures how often the system extracts information that wasn't present in the document
- **False Discovery Rate (FDR)**: Rate of false positives among positive predictions (FP / (FP + TP))
  - Measures what proportion of the extracted information is incorrect

These metrics are calculated at both the attribute level (per field), section level (per document class), and document level (overall performance).

## Visual Reporting

The evaluation module produces richly formatted Markdown reports with:

1. **Summary Dashboard**:
   - Overall match rate with visual progress bar
   - Color-coded indicators for key metrics (🟢 Excellent, 🟡 Good, 🟠 Fair, 🔴 Poor)
   - Fraction of matched attributes (e.g., 8/10 attributes matched)

2. **Performance Tables**:
   - Metrics tables with value ratings
   - First-column status indicators (✅/❌) for immediate identification of matches
   - Detailed attribution of evaluation methods used for each field, including:
     - Method types (EXACT, FUZZY, HUNGARIAN, etc.)
     - Thresholds for fuzzy and semantic matching methods
     - Comparator types for the Hungarian method
     - Combined display for HUNGARIAN with FUZZY comparator showing both comparator type and threshold

3. **Method Explanations**:
   - Clear documentation of evaluation methods
   - Descriptions of scoring mechanisms
   - Guidance on interpreting results
   - Indications for attributes that were discovered in the data but not in the configuration

Examples of method display in reports:
- `EXACT` - Simple exact matching
- `FUZZY (threshold: 0.8)` - Fuzzy matching with threshold
- `HUNGARIAN (comparator: EXACT)` - Hungarian algorithm with exact matching
- `HUNGARIAN (comparator: FUZZY, threshold: 0.7)` - Hungarian with fuzzy matching and threshold
- `HUNGARIAN (comparator: NUMERIC)` - Hungarian with numeric comparison

The reports are designed to provide both at-a-glance performance assessment and detailed diagnostic information.

## Auto-Discovery of Attributes

The EvaluationService can automatically discover and evaluate attributes that exist in the data but are not defined in the configuration:

```python
# Sample extracted data may have more attributes than configured
actual_results = {
    "invoice_number": "INV-12345",          # In configuration
    "amount_due": 1250.00,                  # In configuration
    "issue_date": "2023-01-15",             # Not in configuration
    "due_date": "2023-02-15"                # Not in configuration
}

expected_results = {
    "invoice_number": "INV-12345",          # In configuration
    "amount_due": "$1,250.00",              # In configuration 
    "issue_date": "01/15/2023",             # Not in configuration
    "reference_number": "REF-98765"         # Not in configuration, missing in actual
}

# The service will:
# 1. Evaluate invoice_number and amount_due using methods in configuration
# 2. Discover issue_date (in both) and evaluate using LLM (default method)
# 3. Discover due_date (only in actual) and evaluate as not matched
# 4. Discover reference_number (only in expected) and evaluate as not matched
# 5. Add "[Default method - attribute not specified in the configuration]" to reason for discovered attributes
```

This capability is particularly useful for:
- Exploratory evaluation when the complete schema is not yet defined
- Handling variations in extraction outputs that may contain additional information
- Identifying potential new attributes to add to the configuration
- Ensuring all extracted data is evaluated, even without explicit configuration

## Assessment Confidence Integration

The evaluation service automatically integrates with the assessment feature to display confidence scores alongside evaluation results. When extraction results include `explainability_info` (generated by the assessment feature), the confidence scores are automatically extracted and displayed in both JSON and Markdown reports.

### Confidence Score Types

- **Confidence**: Confidence score for the extraction results being evaluated

### Enhanced Report Format

#### JSON Output with Confidence
```json
{
  "attributes": [
    {
      "name": "invoice_number",
      "expected": "INV-2024-001",
      "actual": "INV-2024-001",
      "matched": true,
      "score": 1.0,
      "confidence": 0.92,
      "evaluation_method": "EXACT"
    }
  ]
}
```

#### Markdown Table with Confidence
```
| Status | Attribute | Expected | Actual | Confidence | Score | Method | Reason |
| :----: | --------- | -------- | ------ | :---------------: | ----- | ------ | ------ |
| ✅ | invoice_number | INV-2024-001 | INV-2024-001 | 0.92 | 1.00 | EXACT | Exact match |
| ❌ | vendor_name | ABC Corp | XYZ Inc | 0.75 | 0.00 | EXACT | Values do not match |
```

### Quality Analysis Benefits

Confidence scores provide additional insights for evaluation analysis:

1. **Extraction Quality Assessment**: Low confidence highlights extraction results needing review
2. **Confidence-Accuracy Correlation**: Compare confidence levels with evaluation accuracy to identify patterns
3. **Quality Prioritization**: Focus improvement efforts on low-confidence, low-accuracy results

### Backward Compatibility

The confidence integration is fully backward compatible:
- Reports without assessment data show "N/A" for confidence columns
- Evaluation logic remains unchanged when confidence data is absent
- Existing evaluation workflows continue to work without modification

## Nested Structure Support

The evaluation service fully supports nested document structures including group attributes and list attributes. The service automatically processes these complex structures by flattening them into individual evaluable fields while preserving the configured evaluation methods.

### Attribute Types and Processing

#### Simple Attributes
Basic single-value extractions that are evaluated directly:

```python
# Configuration
{
    "name": "Account Number",
    "attributeType": "simple",
    "evaluation_method": "EXACT"
}

# Flattened attribute name: "Account Number"
# Evaluation: Direct comparison using EXACT method
```

#### Group Attributes  
Nested object structures where each sub-attribute is evaluated individually:

```python
# Configuration
{
    "name": "Account Holder Address",
    "attributeType": "group",
    "groupAttributes": [
        {
            "name": "Street Number",
            "evaluation_method": "FUZZY",
            "evaluation_threshold": 0.9
        },
        {
            "name": "City",
            "evaluation_method": "FUZZY", 
            "evaluation_threshold": 0.9
        }
    ]
}

# Flattened attribute names:
# - "Account Holder Address.Street Number" (FUZZY evaluation)
# - "Account Holder Address.City" (FUZZY evaluation)
```

#### List Attributes
Arrays of items where each item's attributes are evaluated individually:

```python
# Configuration
{
    "name": "Transactions",
    "attributeType": "list",
    "listItemTemplate": {
        "itemAttributes": [
            {
                "name": "Date",
                "evaluation_method": "FUZZY",
                "evaluation_threshold": 0.9
            },
            {
                "name": "Amount",
                "evaluation_method": "NUMERIC_EXACT"
            }
        ]
    }
}

# Flattened attribute names for each transaction:
# - "Transactions[0].Date" (FUZZY evaluation)
# - "Transactions[0].Amount" (NUMERIC_EXACT evaluation)
# - "Transactions[1].Date" (FUZZY evaluation)
# - "Transactions[1].Amount" (NUMERIC_EXACT evaluation)
# - And so on for each transaction...
```

### Data Flattening Process

The evaluation service automatically flattens nested extraction results for comparison:

#### Input Data (Nested)
```json
{
  "Account Number": "1234567890",
  "Account Holder Address": {
    "Street Number": "123",
    "Street Name": "Main St",
    "City": "Seattle",
    "State": "WA"
  },
  "Transactions": [
    {
      "Date": "01/15/2024",
      "Description": "Coffee Shop",
      "Amount": "-4.50"
    },
    {
      "Date": "01/16/2024", 
      "Description": "ATM Withdrawal",
      "Amount": "-20.00"
    }
  ]
}
```

#### Flattened Data (For Evaluation)
```json
{
  "Account Number": "1234567890",
  "Account Holder Address.Street Number": "123",
  "Account Holder Address.Street Name": "Main St", 
  "Account Holder Address.City": "Seattle",
  "Account Holder Address.State": "WA",
  "Transactions[0].Date": "01/15/2024",
  "Transactions[0].Description": "Coffee Shop",
  "Transactions[0].Amount": "-4.50",
  "Transactions[1].Date": "01/16/2024",
  "Transactions[1].Description": "ATM Withdrawal", 
  "Transactions[1].Amount": "-20.00"
}
```

### Evaluation Results for Nested Structures

The evaluation service provides detailed results for all flattened attributes:

#### Sample Evaluation Output
```json
{
  "attributes": [
    {
      "name": "Account Number",
      "expected": "1234567890",
      "actual": "1234567890", 
      "matched": true,
      "score": 1.0,
      "confidence": 0.95,
      "evaluation_method": "EXACT"
    },
    {
      "name": "Account Holder Address.City",
      "expected": "Seattle",
      "actual": "Seattle",
      "matched": true,
      "score": 1.0,
      "confidence": 0.88,
      "evaluation_method": "FUZZY",
      "evaluation_threshold": 0.9
    },
    {
      "name": "Transactions[0].Amount",
      "expected": "-4.50",
      "actual": "-4.50",
      "matched": true,
      "score": 1.0,
      "confidence": 0.92,
      "evaluation_method": "NUMERIC_EXACT"
    },
    {
      "name": "Transactions[1].Description", 
      "expected": "ATM Withdrawal",
      "actual": "ATM Cash",
      "matched": true,
      "score": 0.85,
      "confidence": 0.87,
      "evaluation_method": "SEMANTIC",
      "evaluation_threshold": 0.7
    }
  ]
}
```

#### Markdown Report for Nested Structures
```markdown
| Status | Attribute | Expected | Actual | Confidence | Score | Method | Reason |
| :----: | --------- | -------- | ------ | :--------: | ----- | ------ | ------ |
| ✅ | Account Number | 1234567890 | 1234567890 | 0.95 | 1.00 | EXACT | Exact match |
| ✅ | Account Holder Address.Street Number | 123 | 123 | 0.95 | 1.00 | FUZZY (threshold: 0.9) | Exact match |
| ✅ | Account Holder Address.City | Seattle | Seattle | 0.88 | 1.00 | FUZZY (threshold: 0.9) | Exact match |
| ❌ | Account Holder Address.State | WA | Washington | 0.82 | 0.00 | EXACT | Values do not match exactly |
| ✅ | Transactions[0].Date | 01/15/2024 | 01/15/2024 | 0.94 | 1.00 | FUZZY (threshold: 0.9) | Exact match |
| ✅ | Transactions[0].Amount | -4.50 | -4.50 | 0.92 | 1.00 | NUMERIC_EXACT | Exact numeric match |
| ✅ | Transactions[1].Description | ATM Withdrawal | ATM Cash | 0.87 | 0.85 | SEMANTIC (threshold: 0.7) | Semantically similar |
```

### Benefits of Nested Structure Support

1. **Granular Analysis**: Individual evaluation of each nested field provides precise insights
2. **Flexible Configuration**: Different evaluation methods can be applied to different parts of nested structures
3. **Comprehensive Coverage**: All attributes in complex documents are evaluated, regardless of nesting level
4. **Pattern Recognition**: Identify consistent issues with specific nested attributes (e.g., address parsing problems)
5. **Scalable Processing**: Handles documents with varying numbers of list items efficiently
6. **Detailed Reporting**: Clear attribution of evaluation results to specific nested fields

### Use Cases for Nested Evaluation

- **Bank Statements**: Evaluate account details (group) and individual transactions (list)
- **Invoices**: Evaluate vendor information (group) and line items (list)
- **Medical Records**: Evaluate patient information (group) and procedures/medications (lists)
- **Legal Documents**: Evaluate parties (group) and clauses/terms (lists)
- **Financial Reports**: Evaluate company info (group) and financial line items (lists)

The nested structure support enables comprehensive evaluation of complex documents while maintaining the flexibility to apply appropriate evaluation methods to each type of data within the document.
