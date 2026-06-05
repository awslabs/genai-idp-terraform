Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Utils Module

The Utils module provides common utility functions used across the IDP pipeline.

## Public Functions

| Function | Description |
|----------|-------------|
| `build_s3_uri(bucket, key)` | Construct an `s3://bucket/key` URI from components |
| `parse_s3_uri(s3_uri)` | Parse an S3 URI into `(bucket, key)` tuple |
| `merge_metering_data(existing, new)` | Merge token usage / metering dictionaries (sums numeric values) |
| `get_bedrock_region()` | Get the AWS region for Bedrock API calls |
| `extract_structured_data_from_text(text)` | Extract JSON or YAML structured data from LLM response text |

## Usage

### S3 URI Helpers

```python
from idp_common.utils import build_s3_uri, parse_s3_uri

# Build a URI
uri = build_s3_uri("my-bucket", "documents/sample.pdf")
# Returns: "s3://my-bucket/documents/sample.pdf"

# Parse a URI
bucket, key = parse_s3_uri("s3://my-bucket/documents/sample.pdf")
# Returns: ("my-bucket", "documents/sample.pdf")
```

### Metering Data

```python
from idp_common.utils import merge_metering_data

# Merge token usage from multiple LLM calls
combined = merge_metering_data(
    existing={"inputTokens": 100, "outputTokens": 50, "requests": 1},
    new={"inputTokens": 200, "outputTokens": 75, "requests": 1}
)
# Returns: {"inputTokens": 300, "outputTokens": 125, "requests": 2}
```

### Parse LLM Responses

```python
from idp_common.utils import extract_structured_data_from_text

# Extract JSON or YAML from LLM response text
data, format_type = extract_structured_data_from_text(llm_response_text)
# data: parsed dict/list
# format_type: "json" or "yaml"
```
