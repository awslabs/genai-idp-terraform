# Reporting Module

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

## Overview

The Reporting module provides comprehensive functionality for saving document processing data to reporting storage in structured formats for analytics and reporting purposes. It supports saving evaluation results, metering data, and document sections as Parquet files in S3, with automatic AWS Glue table creation and partition projection for efficient querying with Amazon Athena.

## Key Components

### SaveReportingData Class

The `SaveReportingData` class is the main component of the reporting module. It provides methods to save different types of document data to a reporting bucket in Parquet format.

```python
from idp_common.reporting import SaveReportingData
from idp_common.models import Document

# Initialize the SaveReportingData class with a reporting bucket
reporter = SaveReportingData(reporting_bucket="my-reporting-bucket")

# Save specific data types for a document
results = reporter.save(document, data_to_save=["evaluation_results"])
```

## Features

- **Modular Design**: Each data type has its own processing method, making it easy to add support for new data types
- **Parquet Format**: Data is saved in Parquet format, which is optimized for analytics workloads
- **Hierarchical Storage**: Data is organized in a hierarchical structure by date/document with unique timestamped filenames
- **Flexible Schema**: Each data type has its own schema definition, allowing for specialized data structures
- **Dynamic Schema Inference**: Automatically infers schemas for document sections without predefined structures
- **Partition Projection**: Uses AWS Glue partition projection for efficient querying without MSCK REPAIR operations
- **Automatic Table Discovery**: AWS Glue Crawler automatically discovers new section types and creates tables
- **Unique File Naming**: Timestamp-based filenames prevent overwrites when documents are reprocessed
- **Error Handling**: Comprehensive error handling with detailed logging and graceful failure recovery
- **AWS Athena Ready**: All data is immediately queryable through Amazon Athena with optimized partition pruning

## Supported Data Types

### Evaluation Results

The module supports saving document evaluation results, which include:

1. **Document-level metrics**: Overall accuracy, precision, recall, F1 score, etc.
2. **Section-level metrics**: Metrics for each document section
3. **Attribute-level details**: Detailed information about each attribute, including expected vs. actual values, match status, and confidence

```python
# Save evaluation results for a document
result = reporter.save_evaluation_results(document)
```

### Metering Data

The module supports saving document processing metering data for cost tracking and analytics:

```python
# Save metering data for a document
result = reporter.save_metering_data(document)
```

### Document Sections

The module supports saving document section extraction results as Parquet files with dynamic schema inference. This functionality processes each section in the document, loads the extraction results from S3, and saves them in a structured, partitioned format suitable for analytics.

#### Key Features

- **Dynamic Schema Inference**: Automatically constructs PyArrow schemas from JSON data without requiring predefined schemas
- **Flexible Data Handling**: Supports various JSON structures (objects, arrays, primitives)
- **Nested JSON Flattening**: Converts nested objects to flat structure using dot notation
- **Partition Structure**: Organizes data with section_type and date-based partitioning
- **Error Resilience**: Continues processing other sections if individual sections fail
- **Comprehensive Logging**: Detailed logging for monitoring and debugging

#### Usage

```python
# Save document sections along with other data types
data_to_save = ["sections"]  # New option
results = reporter.save(document, data_to_save)

# Or combine with existing functionality
data_to_save = ["evaluation_results", "metering", "sections"]
results = reporter.save(document, data_to_save)
```

#### Requirements

For the sections functionality to work, your `Document` object must have:

1. **Sections**: A list of `Section` objects in `document.sections`
2. **Extraction Results**: Each section should have `extraction_result_uri` pointing to S3 JSON file
3. **Classification**: Each section should have a `classification` field for partitioning

#### Data Processing

**Schema Inference**: The method dynamically infers PyArrow schemas by analyzing the JSON data:
- **Strings**: Mapped to `pa.string()`
- **Integers**: Mapped to `pa.int64()`
- **Floats**: Mapped to `pa.float64()`
- **Booleans**: Mapped to `pa.bool_()`
- **Lists/Objects**: Converted to JSON strings and mapped to `pa.string()`
- **Mixed Types**: Defaults to `pa.string()`

**JSON Flattening**: Nested JSON structures are flattened using dot notation:

```json
// Input JSON
{
  "customer": {
    "name": "John Doe",
    "address": {
      "street": "123 Main St",
      "city": "Anytown"
    }
  },
  "items": ["item1", "item2"]
}

// Flattened Output
{
  "customer.name": "John Doe",
  "customer.address.street": "123 Main St", 
  "customer.address.city": "Anytown",
  "items": "[\"item1\", \"item2\"]"  // Arrays become JSON strings
}
```

**Metadata Fields**: Each record includes the following metadata fields:
- `section_id`: The unique identifier of the section
- `document_id`: The document identifier
- `section_classification`: The section's classification/type
- `section_confidence`: The confidence score for the section
- `timestamp`: The timestamp when the document was processed

## Storage Structure

Data is stored in S3 with the following structure:

```
reporting-bucket/
├── evaluation_metrics/
│   ├── document_metrics/
│   │   └── date=YYYY-MM-DD/
│   │       ├── doc-id_20240115_143052_123_results.parquet
│   │       ├── doc-id_20240115_143127_456_results.parquet  # Same doc, reprocessed
│   │       └── another-doc-id_20240115_144001_789_results.parquet
│   ├── section_metrics/
│   │   └── date=YYYY-MM-DD/
│   │       ├── doc-id_20240115_143052_123_results.parquet
│   │       └── another-doc-id_20240115_144001_789_results.parquet
│   └── attribute_metrics/
│       └── date=YYYY-MM-DD/
│           ├── doc-id_20240115_143052_123_results.parquet
│           └── another-doc-id_20240115_144001_789_results.parquet
├── metering/
│   └── date=YYYY-MM-DD/
│       ├── doc-id_20240115_143052_123_results.parquet
│       └── another-doc-id_20240115_144001_789_results.parquet
└── document_sections/
    ├── invoice/
    │   └── date=YYYY-MM-DD/
    │       ├── doc-id_section_1.parquet
    │       └── doc-id_section_4.parquet
    ├── receipt/
    │   └── date=YYYY-MM-DD/
    │       └── doc-id_section_2.parquet
    └── bank_statement/
        └── date=YYYY-MM-DD/
            └── doc-id_section_3.parquet
```

### File Naming Convention

All files use a unique timestamp-based naming convention to prevent overwrites:
- **Format**: `{escaped_doc_id}_{timestamp}_results.parquet`
- **Timestamp**: `YYYYMMDD_HHMMSS_mmm` (includes milliseconds)
- **Example**: `invoice-123_20240115_143052_123_results.parquet`

This ensures that if the same document is processed multiple times in the same day, each processing attempt creates a separate file, preserving all data for analysis and debugging.

This structure is designed to be compatible with AWS Glue and Amazon Athena for analytics. The document sections are partitioned by `section_type` (classification) as the first partition level, followed by a single date-based partition using the format `YYYY-MM-DD`. Each file is uniquely named with the document ID and section ID to avoid conflicts, and the document ID is included as a column in the Parquet data for filtering and analysis.

### Partition Structure Benefits

The new single date partition structure provides several advantages:

- **Simplified Queries**: Natural date range queries like `WHERE date BETWEEN '2024-01-01' AND '2024-01-31'`
- **Efficient Pruning**: Athena can efficiently prune partitions based on date ranges
- **Cleaner Organization**: Single date partition is easier to understand and maintain
- **Better Performance**: Reduced partition overhead compared to three-level partitioning
- **Future-Proof**: Easier to extend and modify partition strategies

## AWS Glue Integration

The reporting module is designed to work seamlessly with AWS Glue and Amazon Athena:

### Automatic Table Creation

AWS Glue tables are automatically created via CloudFormation with the following features:

- **Predefined Tables**: `document_evaluations`, `section_evaluations`, `attribute_evaluations`, and `metering` tables
- **Dynamic Tables**: Document sections tables are automatically discovered by AWS Glue Crawler
- **Partition Projection**: All tables use partition projection for efficient querying

### Partition Projection Configuration

All tables use AWS Glue partition projection to eliminate the need for `MSCK REPAIR TABLE` operations:

```yaml
# Example partition projection for date-based partitioning
projection.enabled: "true"
projection.date.type: "date"
projection.date.format: "yyyy-MM-dd"
projection.date.range: "2024-01-01,2030-12-31"
projection.date.interval: "1"
projection.date.interval.unit: "DAYS"
storage.location.template: "s3://bucket/path/date=${date}/"
```

### AWS Glue Crawler for Document Sections

The document sections crawler automatically:

- **Discovers New Section Types**: Creates tables for new document classifications
- **Updates Schemas**: Adapts to changes in extraction result structures
- **Configurable Schedule**: Runs manually, every 15 minutes, hourly, or daily
- **Partition Discovery**: Automatically discovers new date partitions

### Benefits

- **No Manual Maintenance**: Tables and partitions are automatically managed
- **Immediate Availability**: New data is queryable immediately without manual intervention
- **Optimized Performance**: Partition projection provides efficient query performance
- **Schema Evolution**: Automatic adaptation to changing data structures

## Extending the Module

To add support for a new data type:

1. Add a new method to the `SaveReportingData` class:

```python
def save_document_metadata(self, document: Document) -> Optional[Dict[str, Any]]:
    """
    Save document metadata to the reporting bucket.
    
    Args:
        document: Document object containing metadata
        
    Returns:
        Dict with status and message, or None if no metadata
    """
    # Define schema specific to document metadata
    metadata_schema = pa.schema([
        ('document_id', pa.string()),
        ('input_key', pa.string()),
        ('created_at', pa.timestamp('ms')),
        ('page_count', pa.int32()),
        ('file_size', pa.int64()),
        # Add other metadata fields as needed
    ])
    
    # Implementation for saving document metadata
    # ...
    
    return {
        'statusCode': 200,
        'body': "Successfully saved document metadata"
    }
```

2. Update the `save` method to call this new method when the data type is requested:

```python
if 'document_metadata' in data_to_save:
    logger.info("Processing document metadata")
    result = self.save_document_metadata(document)
    if result:
        results.append(result)
```

## Usage in Lambda Functions

The module is designed to be used in Lambda functions for saving document data to reporting storage:

```python
from idp_common.models import Document
from idp_common.reporting import SaveReportingData

def handler(event, context):
    # Extract parameters from the event
    document_dict = event.get('document')
    reporting_bucket = event.get('reporting_bucket')
    data_to_save = event.get('data_to_save', [])
    
    # Convert document dict to Document object
    document = Document.from_dict(document_dict)
    
    # Use the SaveReportingData class to save the data
    reporter = SaveReportingData(reporting_bucket)
    results = reporter.save(document, data_to_save)
    
    # Return success if all operations completed
    return {
        'statusCode': 200,
        'body': "Successfully saved data to reporting bucket"
    }
```

## Dependencies

The reporting module has the following dependencies:

- `boto3`: For AWS S3 operations
- `pyarrow`: For Parquet file creation and schema definition
- `idp_common.models`: For the Document data model

When deploying Lambda functions that use this module, ensure that these dependencies are included in the deployment package.
