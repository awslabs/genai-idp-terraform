# Reporting Database

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

The GenAI IDP Accelerator includes a comprehensive reporting database that captures detailed metrics about document processing. This database is implemented as AWS Glue tables over Amazon S3 data in Parquet format, making it queryable through Amazon Athena for analytics and reporting purposes.

## Table of Contents

- [Evaluation Tables](#evaluation-tables)
  - [Document Evaluations](#document-evaluations)
  - [Section Evaluations](#section-evaluations)
  - [Attribute Evaluations](#attribute-evaluations)
- [Metering Table](#metering-table)
- [Document Sections Tables](#document-sections-tables)
  - [Dynamic Section Tables](#dynamic-section-tables)
  - [Crawler Configuration](#crawler-configuration)
- [Using the Reporting Database with Athena](#using-the-reporting-database-with-athena)
  - [Sample Queries](#sample-queries)
  - [Creating Dashboards](#creating-dashboards)

## Evaluation Tables

The evaluation tables store metrics and results from comparing extracted document data against baseline (ground truth) data. These tables provide insights into the accuracy and performance of the document processing system.

### Document Evaluations

The `document_evaluations` table contains document-level evaluation metrics:

| Column | Type | Description |
|--------|------|-------------|
| document_id | string | Unique identifier for the document |
| input_key | string | S3 key of the input document |
| evaluation_date | timestamp | When the evaluation was performed |
| accuracy | double | Overall accuracy score (0-1) |
| precision | double | Precision score (0-1) |
| recall | double | Recall score (0-1) |
| f1_score | double | F1 score (0-1) |
| false_alarm_rate | double | False alarm rate (0-1) |
| false_discovery_rate | double | False discovery rate (0-1) |
| execution_time | double | Time taken to evaluate (seconds) |

This table is partitioned by date (YYYY-MM-DD format).

### Section Evaluations

The `section_evaluations` table contains section-level evaluation metrics:

| Column | Type | Description |
|--------|------|-------------|
| document_id | string | Unique identifier for the document |
| section_id | string | Identifier for the section |
| section_type | string | Type/class of the section |
| accuracy | double | Section accuracy score (0-1) |
| precision | double | Section precision score (0-1) |
| recall | double | Section recall score (0-1) |
| f1_score | double | Section F1 score (0-1) |
| false_alarm_rate | double | Section false alarm rate (0-1) |
| false_discovery_rate | double | Section false discovery rate (0-1) |
| evaluation_date | timestamp | When the evaluation was performed |

This table is partitioned by date (YYYY-MM-DD format).

### Attribute Evaluations

The `attribute_evaluations` table contains attribute-level evaluation metrics:

| Column | Type | Description |
|--------|------|-------------|
| document_id | string | Unique identifier for the document |
| section_id | string | Identifier for the section |
| section_type | string | Type/class of the section |
| attribute_name | string | Name of the attribute |
| expected | string | Expected (ground truth) value |
| actual | string | Actual extracted value |
| matched | boolean | Whether the values matched |
| score | double | Match score (0-1) |
| reason | string | Explanation for the match result |
| evaluation_method | string | Method used for comparison |
| confidence | string | Confidence score from extraction |
| confidence_threshold | string | Confidence threshold used |
| evaluation_date | timestamp | When the evaluation was performed |

This table is partitioned by date (YYYY-MM-DD format).

## Metering Table

The `metering` table captures detailed usage metrics for each document processing operation:

| Column | Type | Description |
|--------|------|-------------|
| document_id | string | Unique identifier for the document |
| context | string | Processing context (OCR, Classification, Extraction, etc.) |
| service_api | string | Specific API or model used (e.g., textract/analyze_document, bedrock/claude-3) |
| unit | string | Unit of measurement (pages, inputTokens, outputTokens, etc.) |
| value | double | Quantity of the unit consumed |
| number_of_pages | int | Number of pages in the document |
| timestamp | timestamp | When the operation was performed |

This table is partitioned by date (YYYY-MM-DD format).

The metering table is particularly valuable for:
- Cost analysis and allocation
- Usage pattern identification
- Resource optimization
- Performance benchmarking across different document types and sizes

## Document Sections Tables

The document sections tables store the actual extracted data from document sections in a structured format suitable for analytics. These tables are automatically discovered by AWS Glue Crawler and are organized by section type (classification).

### Dynamic Section Tables

Document sections are stored in dynamically created tables based on the section classification. Each section type gets its own table (e.g., `document_sections_invoice`, `document_sections_receipt`, `document_sections_bank_statement`, etc.) with the following characteristics:

**Common Metadata Columns:**
| Column | Type | Description |
|--------|------|-------------|
| section_id | string | Unique identifier for the section |
| document_id | string | Unique identifier for the document |
| section_classification | string | Type/class of the section |
| section_confidence | double | Confidence score for the section classification |
| timestamp | timestamp | When the document was processed |

**Dynamic Data Columns:**
The remaining columns are dynamically inferred from the JSON extraction results and vary by section type. Common patterns include:
- Nested JSON objects are flattened using dot notation (e.g., `customer.name`, `customer.address.street`)
- Arrays are converted to JSON strings
- Primitive values (strings, numbers, booleans) are preserved as their native types

**Partitioning:**
Each section type table is partitioned by date (YYYY-MM-DD format) for efficient querying.

**File Organization:**
```
document_sections/
├── invoice/
│   └── date=2024-01-15/
│       ├── doc-123_section_1.parquet
│       └── doc-456_section_3.parquet
├── receipt/
│   └── date=2024-01-15/
│       └── doc-789_section_2.parquet
└── bank_statement/
    └── date=2024-01-15/
        └── doc-abc_section_1.parquet
```

### Crawler Configuration

The AWS Glue Crawler automatically discovers new section types and creates corresponding tables. The crawler can be configured to run:
- Manually (on-demand)
- Every 15 minutes
- Every hour 
- Daily (default)

This ensures that new section types are automatically available for querying without manual intervention.

## Using the Reporting Database with Athena

Amazon Athena provides a serverless query service to analyze data directly in Amazon S3. The reporting database tables are automatically registered in the AWS Glue Data Catalog, making them immediately available for querying in Athena.

To use the reporting database with Athena:

1. Open the [Amazon Athena console](https://console.aws.amazon.com/athena/)
2. Select the database named after your stack (e.g., `idp_reporting`)
3. Start querying the tables using standard SQL

### Sample Queries

Here are some example queries to get you started:

**Overall accuracy by document type:**
```sql
SELECT 
  section_type, 
  AVG(accuracy) as avg_accuracy, 
  COUNT(*) as document_count
FROM 
  section_evaluations
GROUP BY 
  section_type
ORDER BY 
  avg_accuracy DESC;
```

**Token usage by model:**
```sql
SELECT 
  service_api, 
  SUM(CASE WHEN unit = 'inputTokens' THEN value ELSE 0 END) as total_input_tokens,
  SUM(CASE WHEN unit = 'outputTokens' THEN value ELSE 0 END) as total_output_tokens,
  SUM(CASE WHEN unit = 'totalTokens' THEN value ELSE 0 END) as total_tokens,
  COUNT(DISTINCT document_id) as document_count
FROM 
  metering
WHERE 
  context = 'Extraction'
GROUP BY 
  service_api
ORDER BY 
  total_tokens DESC;
```

**Extraction confidence vs. accuracy:**
```sql
SELECT 
  CASE 
    WHEN CAST(confidence AS double) < 0.7 THEN 'Low (<0.7)'
    WHEN CAST(confidence AS double) < 0.9 THEN 'Medium (0.7-0.9)'
    ELSE 'High (>0.9)'
  END as confidence_band,
  AVG(CASE WHEN matched THEN 1.0 ELSE 0.0 END) as accuracy,
  COUNT(*) as attribute_count
FROM 
  attribute_evaluations
WHERE 
  confidence IS NOT NULL
GROUP BY 
  CASE 
    WHEN CAST(confidence AS double) < 0.7 THEN 'Low (<0.7)'
    WHEN CAST(confidence AS double) < 0.9 THEN 'Medium (0.7-0.9)'
    ELSE 'High (>0.9)'
  END
ORDER BY 
  confidence_band;
```

**Token usage per page by document type:**
```sql
SELECT 
  se.section_type,
  AVG(m.value / m.number_of_pages) as avg_tokens_per_page
FROM 
  metering m
JOIN 
  section_evaluations se ON m.document_id = se.document_id
WHERE 
  m.unit = 'totalTokens'
  AND m.number_of_pages > 0
GROUP BY 
  se.section_type
ORDER BY 
  avg_tokens_per_page DESC;
```

**Document sections analysis by type:**
```sql
-- Query invoice sections for customer analysis
SELECT 
  document_id,
  section_id,
  "customer.name" as customer_name,
  "customer.address.city" as customer_city,
  "total_amount" as invoice_total,
  date
FROM 
  invoice
WHERE 
  date BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY 
  date DESC;
```

**Section processing volume by date:**
```sql
-- Count sections processed by type and date
SELECT 
  date,
  section_classification,
  COUNT(*) as section_count,
  COUNT(DISTINCT document_id) as document_count
FROM (
  SELECT date, section_classification, document_id FROM invoice
  UNION ALL
  SELECT date, section_classification, document_id FROM receipt
  UNION ALL
  SELECT date, section_classification, document_id FROM bank_statement
)
GROUP BY 
  date, section_classification
ORDER BY 
  date DESC, section_count DESC;
```

**Date range queries with new partition structure:**
```sql
-- Efficient date range query using single date partition
SELECT 
  COUNT(*) as total_documents,
  AVG(accuracy) as avg_accuracy
FROM 
  document_evaluations
WHERE 
  date BETWEEN '2024-01-01' AND '2024-01-31';

-- Monthly aggregation
SELECT 
  SUBSTR(date, 1, 7) as month,
  COUNT(*) as document_count,
  AVG(accuracy) as avg_accuracy
FROM 
  document_evaluations
WHERE 
  date >= '2024-01-01'
GROUP BY 
  SUBSTR(date, 1, 7)
ORDER BY 
  month;
```

### Creating Dashboards

For more advanced visualization and dashboarding:

1. Use [Amazon QuickSight](https://aws.amazon.com/quicksight/) to connect to your Athena queries
2. Create interactive dashboards to monitor:
   - Extraction accuracy over time
   - Cost trends by document type
   - Performance metrics by model
   - Resource utilization patterns

You can also export query results to CSV or other formats for use with external business intelligence tools.
