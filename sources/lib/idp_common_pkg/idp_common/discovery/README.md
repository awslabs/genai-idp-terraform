Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Discovery Module

The Discovery module provides automatic document class and schema discovery using LLMs. It analyzes sample documents to generate JSON Schema definitions for new document types, enabling rapid configuration of new document processing workflows.

## Overview

The discovery service uses Amazon Bedrock LLMs to:
- Analyze document content (text + images) to identify document types
- Generate JSON Schema definitions with attribute extraction fields
- Auto-detect document section boundaries in multi-page PDFs
- Optionally compare results against ground truth for validation

## Components

- **`ClassesDiscovery`**: Main service class for document class discovery

## Usage

### Basic Discovery

```python
from idp_common.discovery.classes_discovery import ClassesDiscovery

# Initialize with S3 document location
discovery = ClassesDiscovery(
    input_bucket="my-bucket",
    input_prefix="documents/sample.pdf",
    region="us-east-1"
)

# Discover document classes and generate schema
result = discovery.discovery_classes_with_document(
    input_bucket="my-bucket",
    input_prefix="documents/sample.pdf",
    save_to_config=False  # Don't save to DynamoDB
)

schema = result["schema"]  # JSON Schema dict
```

### Discovery with Local File Bytes

```python
# Use local file bytes (skip S3 read)
with open("sample.pdf", "rb") as f:
    file_bytes = f.read()

result = discovery.discovery_classes_with_document(
    input_bucket="local",
    input_prefix="sample.pdf",
    file_bytes=file_bytes,
    save_to_config=False
)
```

### Discovery with Page Range

```python
# Only analyze specific pages
result = discovery.discovery_classes_with_document(
    input_bucket="my-bucket",
    input_prefix="documents/packet.pdf",
    page_range="3-5",  # Only pages 3-5
    save_to_config=False
)
```

### Discovery with Ground Truth Comparison

```python
result = discovery.discovery_classes_with_document(
    input_bucket="my-bucket",
    input_prefix="documents/sample.pdf",
    ground_truth_attributes={"invoice_number": "INV-001", "date": "2024-01-15"},
    save_to_config=False
)
```

### Auto-Detect Document Sections

For multi-document packets, auto-detect section boundaries:

```python
sections = discovery.auto_detect_sections(
    input_bucket="my-bucket",
    input_prefix="documents/packet.pdf"
)
# Returns: [{"start": 1, "end": 3, "type": "W2 Form"}, {"start": 4, "end": 6, "type": "Invoice"}]
```

### Class Name Hint

Provide a hint for the expected document class:

```python
result = discovery.discovery_classes_with_document(
    input_bucket="my-bucket",
    input_prefix="documents/w2.pdf",
    class_name_hint="W2 Tax Form",
    save_to_config=False
)
```

## Key Methods

| Method | Description |
|--------|-------------|
| `discovery_classes_with_document()` | Main discovery method — analyzes a document and generates JSON Schema |
| `auto_detect_sections()` | Detects document type boundaries in multi-page PDFs |
| `parse_page_range()` | Static method to parse page range strings (e.g., `"3-5"`) |
| `extract_pdf_pages()` | Static method to extract a subset of pages from a PDF |

## Configuration

Discovery uses configuration from DynamoDB (loaded via `get_config()`). Key settings:

```yaml
discovery:
  model: us.amazon.nova-pro-v1:0
  temperature: 0.0
  system_prompt: "..."
  task_prompt: "..."
```

## Integration with IDP SDK

The discovery module is also accessible through the IDP SDK:

```python
from idp_sdk import IDPClient

client = IDPClient(stack_name="my-stack")
result = client.discovery.run(
    file="sample.pdf",
    class_name_hint="Invoice"
)
```

## Related Documentation

- [Discovery Documentation](../../../../docs/discovery.md) — Full discovery workflow guide
- [Configuration Guide](../../../../docs/configuration.md) — Configuration management
