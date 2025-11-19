# Document Service Factory

The `docs_service` module provides a factory pattern for creating document services, allowing you to switch between AppSync and DynamoDB implementations while maintaining the same interface.

## Overview

This module enables runtime switching between different document tracking backends:

- **AppSync Mode**: Uses AWS AppSync GraphQL API for document operations
- **DynamoDB Mode**: Uses direct DynamoDB operations for document tracking

The factory pattern ensures that your Lambda functions can work with either backend without code changes, controlled by environment variables.

## Key Components

### DocumentServiceFactory

The main factory class that creates appropriate service instances:

```python
from idp_common.docs_service import DocumentServiceFactory

# Create service based on environment variable
service = DocumentServiceFactory.create_service()

# Override mode explicitly
service = DocumentServiceFactory.create_service(mode='dynamodb')

# Pass additional parameters
service = DocumentServiceFactory.create_service(
    mode='appsync',
    api_url='https://example.appsync-api.us-east-1.amazonaws.com/graphql'
)
```

### Convenience Functions

Simplified functions for common operations:

```python
from idp_common.docs_service import (
    create_document_service,
    get_document_tracking_mode,
    is_appsync_mode,
    is_dynamodb_mode
)

# Create service using convenience function
service = create_document_service()

# Check current mode
current_mode = get_document_tracking_mode()
if is_appsync_mode():
    print("Using AppSync backend")
elif is_dynamodb_mode():
    print("Using DynamoDB backend")
```

## Environment Configuration

The factory uses the `DOCUMENT_TRACKING_MODE` environment variable to determine which service to create:

```bash
# Use AppSync (default)
export DOCUMENT_TRACKING_MODE=appsync

# Use DynamoDB
export DOCUMENT_TRACKING_MODE=dynamodb
```

## Usage Patterns

### Basic Usage

```python
from idp_common.docs_service import create_document_service
from idp_common.models import Document, Status

# Create service (mode determined by environment)
service = create_document_service()

# Use the service (same interface regardless of backend)
document = Document(
    input_key="my-document.pdf",
    status=Status.QUEUED,
    queued_time="2024-01-01T12:00:00Z"
)

# These methods work with both AppSync and DynamoDB services
service.create_document(document)
service.update_document(document)
retrieved_doc = service.get_document("my-document.pdf")
```

### Lambda Function Integration

```python
import os
from idp_common.docs_service import create_document_service

def lambda_handler(event, context):
    # Service type determined by environment variable
    service = create_document_service()
    
    # Your document processing logic here
    document = process_document(event)
    
    # Update document status
    service.update_document(document)
    
    return {"statusCode": 200}
```

### Testing with Different Backends

```python
import pytest
from unittest.mock import patch
from idp_common.docs_service import create_document_service

def test_with_appsync():
    with patch.dict(os.environ, {"DOCUMENT_TRACKING_MODE": "appsync"}):
        service = create_document_service()
        assert service.__class__.__name__ == "DocumentAppSyncService"

def test_with_dynamodb():
    with patch.dict(os.environ, {"DOCUMENT_TRACKING_MODE": "dynamodb"}):
        service = create_document_service()
        assert service.__class__.__name__ == "DocumentDynamoDBService"
```

### Configuration-based Service Creation

```python
from idp_common.docs_service import DocumentServiceFactory

class DocumentProcessor:
    def __init__(self, config):
        # Create service based on configuration
        self.service = DocumentServiceFactory.create_service(
            mode=config.get('tracking_mode', 'appsync'),
            **config.get('service_params', {})
        )
    
    def process(self, document):
        # Process document using configured service
        return self.service.update_document(document)
```

## Service Interface Compatibility

Both AppSync and DynamoDB services implement the same interface:

### Common Methods

- `create_document(document, expires_after=None) -> str`
- `update_document(document) -> Document`
- `calculate_ttl(days=30) -> int`

### AppSync-specific Methods

- Uses GraphQL mutations for operations
- Requires AppSync API URL configuration
- Handles GraphQL-specific error responses

### DynamoDB-specific Methods

- Uses direct DynamoDB operations
- Requires DynamoDB table name configuration
- Includes additional query methods:
  - `get_document(object_key) -> Optional[Document]`
  - `list_documents(...) -> Dict[str, Any]`
  - `list_documents_date_hour(...) -> Dict[str, Any]`
  - `list_documents_date_shard(...) -> Dict[str, Any]`

## Error Handling

The factory provides consistent error handling:

```python
from idp_common.docs_service import DocumentServiceFactory

try:
    service = DocumentServiceFactory.create_service(mode='invalid')
except ValueError as e:
    print(f"Invalid mode: {e}")

# Service-specific errors are handled by the individual services
try:
    service.create_document(document)
except Exception as e:
    # Handle AppSync or DynamoDB specific errors
    logger.error(f"Document creation failed: {e}")
```

## Migration Guide

### From Direct AppSync Usage

```python
# Old code
from idp_common.appsync import DocumentAppSyncService
service = DocumentAppSyncService(api_url=appsync_url)

# New code
from idp_common.docs_service import create_document_service
service = create_document_service()  # Mode controlled by environment
```

### From Direct DynamoDB Usage

```python
# Old code
from idp_common.dynamodb import DocumentDynamoDBService
service = DocumentDynamoDBService(table_name=table_name)

# New code
from idp_common.docs_service import create_document_service
service = create_document_service()  # Mode controlled by environment
```

## Best Practices

1. **Use Environment Variables**: Control service type through `DOCUMENT_TRACKING_MODE` rather than hardcoding
2. **Consistent Interface**: Write code that works with both service types
3. **Error Handling**: Handle service-specific errors appropriately
4. **Testing**: Test with both service types to ensure compatibility
5. **Configuration**: Use the factory for flexible service creation

## Environment Variables

The module recognizes these environment variables:

- `DOCUMENT_TRACKING_MODE`: Service type ('appsync' or 'dynamodb')
- `APPSYNC_API_URL`: AppSync GraphQL endpoint (for AppSync mode)
- `TRACKING_TABLE`: DynamoDB table name (for DynamoDB mode)
- `AWS_REGION`: AWS region for service operations

## Supported Modes

- `appsync` (default): Use AWS AppSync GraphQL API
- `dynamodb`: Use direct DynamoDB operations

## Examples

See `idp_common/dynamodb/example.py` for comprehensive usage examples including:
- Basic service creation and usage
- Factory pattern usage
- Environment-based mode switching
- Complex document operations with pages and sections
