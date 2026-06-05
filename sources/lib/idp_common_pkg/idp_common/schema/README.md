Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Schema Module

The Schema module provides utilities for dynamically generating Pydantic v2 models from JSON Schema definitions. This enables structured extraction where LLM responses are validated against user-defined schemas.

## Overview

The module uses `datamodel-code-generator` to convert JSON Schema into Pydantic models at runtime. It handles:
- Cleaning custom `x-aws-idp-` extension fields from schemas
- Generating Pydantic v2 `BaseModel` classes from JSON Schema
- Optional JSON Schema validation for advanced constraints (`contains`, `if/then/else`, `dependentSchemas`, etc.)
- Circular reference detection

## Public API

### Functions

| Function | Description |
|----------|-------------|
| `create_pydantic_model_from_json_schema(schema, class_label, ...)` | Main entry point — generates a Pydantic model from a JSON Schema dict |
| `clean_schema_for_generation(schema, fields_to_remove=None)` | Recursively removes custom extension fields from a JSON Schema |

### Exceptions

| Exception | Description |
|-----------|-------------|
| `PydanticModelGenerationError` | Raised when Pydantic model generation fails |
| `CircularReferenceError` | Raised when circular references are detected in the schema |

## Usage

### Generate a Pydantic Model from JSON Schema

```python
from idp_common.schema import create_pydantic_model_from_json_schema

schema = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "Invoice",
    "type": "object",
    "properties": {
        "invoice_number": {"type": "string", "description": "The invoice number"},
        "total_amount": {"type": "number", "description": "Total amount due"},
        "line_items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "description": {"type": "string"},
                    "amount": {"type": "number"}
                }
            }
        }
    }
}

# Generate model
Model = create_pydantic_model_from_json_schema(
    schema=schema,
    class_label="Invoice",
    clean_schema=True,
    enable_json_schema_validation=True
)

# Use the model to validate data
result = Model(invoice_number="INV-001", total_amount=1250.00, line_items=[])
```

### Clean Custom Extension Fields

```python
from idp_common.schema import clean_schema_for_generation

schema_with_extensions = {
    "type": "object",
    "x-aws-idp-document-type": "Invoice",
    "x-aws-idp-examples": [...],
    "properties": {
        "name": {"type": "string", "x-aws-idp-custom": "value"}
    }
}

cleaned = clean_schema_for_generation(schema_with_extensions)
# All x-aws-idp-* fields are removed
```

## Integration with Extraction

The schema module is used internally by the extraction service to validate LLM responses against configured JSON Schemas. When `classes` in the configuration use JSON Schema format, the extraction service calls `create_pydantic_model_from_json_schema()` to build validation models.

## Related Documentation

- [JSON Schema Migration](../../../../docs/json-schema-migration.md) — Migrating to JSON Schema format
- [Extraction](../extraction/README.md) — How extraction uses schema validation
