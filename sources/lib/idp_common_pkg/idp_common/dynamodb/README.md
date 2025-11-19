# DynamoDB Module - Direct DynamoDB Integration

The `dynamodb` module provides direct DynamoDB integration for the IDP Common package, allowing Lambda functions to interact with the TrackingTable without going through AppSync GraphQL API.

## Overview

This module is designed to replace AppSync dependencies in Lambda functions while maintaining the same functionality and data structures. It provides:

- Direct DynamoDB operations using boto3
- Document CRUD operations matching AppSync schema
- Transaction support for atomic operations
- Error handling and logging
- TTL support for document expiration

## Key Components

### DynamoDBClient

Low-level client for DynamoDB operations:
- `put_item()` - Insert items
- `update_item()` - Update existing items
- `get_item()` - Retrieve items by key
- `transact_write_items()` - Execute transactions
- `scan()` - Scan table with filters
- `query()` - Query with key conditions

### DocumentDynamoDBService

High-level service for document operations:
- `create_document()` - Create new documents with list partitioning
- `update_document()` - Update existing documents
- `get_document()` - Retrieve documents by object key
- `list_documents()` - List documents with date filtering
- `list_documents_date_hour()` - List by specific date/hour
- `list_documents_date_shard()` - List by date/shard
- `calculate_ttl()` - Generate TTL timestamps

## Usage

### Basic Usage

```python
from idp_common.dynamodb import DocumentDynamoDBService
from idp_common.models import Document, Status

# Initialize service (uses TRACKING_TABLE env var)
service = DocumentDynamoDBService()

# Create a document
document = Document(
    input_key="my-document.pdf",
    status=Status.QUEUED,
    queued_time="2024-01-01T12:00:00Z"
)

# Create in DynamoDB
service.create_document(document)

# Update document
document.status = Status.PROCESSING
updated_doc = service.update_document(document)

# Retrieve document
retrieved_doc = service.get_document("my-document.pdf")
```

### Advanced Usage

```python
# Custom client configuration
from idp_common.dynamodb import DynamoDBClient, DocumentDynamoDBService

client = DynamoDBClient(
    table_name="my-tracking-table",
    region="us-east-1"
)
service = DocumentDynamoDBService(dynamodb_client=client)

# Create with TTL
ttl = service.calculate_ttl(days=30)
service.create_document(document, expires_after=ttl)

# List documents with filtering
results = service.list_documents(
    start_date_time="2024-01-01T00:00:00Z",
    end_date_time="2024-01-31T23:59:59Z",
    limit=100
)

# Query by date and hour
hourly_docs = service.list_documents_date_hour(
    date="2024-01-01",
    hour=14
)
```

## Data Structure Compatibility

The module maintains full compatibility with the existing AppSync schema:

### Document Table Structure
- **PK**: `doc#{ObjectKey}` - Primary partition key
- **SK**: `none` - Sort key (always "none" for documents)
- **ObjectKey**: Document identifier
- **ObjectStatus**: Document processing status
- **Pages**: List of page objects with Id, Class, ImageUri, TextUri
- **Sections**: List of section objects with Id, PageIds, Class, OutputJSONUri
- **Metering**: JSON string of metering data
- **TTL**: ExpiresAfter timestamp

### List Partition Structure
- **PK**: `list#{date}#s#{shard}` - Time-based partition key
- **SK**: `ts#{timestamp}#id#{ObjectKey}` - Sort key for chronological ordering
- **ObjectKey**: Document identifier
- **QueuedTime**: When document was queued

## Error Handling

The module provides comprehensive error handling:

```python
from idp_common.dynamodb import DynamoDBError

try:
    service.create_document(document)
except DynamoDBError as e:
    logger.error(f"DynamoDB operation failed: {e}")
    logger.error(f"Error code: {e.error_code}")
```

## Environment Variables

The module uses these environment variables:

- `TRACKING_TABLE` - DynamoDB table name
- `AWS_REGION` - AWS region

## Migration from AppSync

To migrate from AppSync to direct DynamoDB:

1. Replace imports:
   ```python
   # Old
   from idp_common.appsync import DocumentAppSyncService
   
   # New
   from idp_common.dynamodb import DocumentDynamoDBService
   ```

2. Update service initialization:
   ```python
   # Old
   service = DocumentAppSyncService(api_url=appsync_url)
   
   # New
   service = DocumentDynamoDBService(table_name=table_name)
   ```

3. Method calls remain the same:
   ```python
   # These work with both services
   service.create_document(document)
   service.update_document(document)
   service.get_document(object_key)
   ```

## Performance Considerations

- **Transactions**: Document creation uses DynamoDB transactions for consistency
- **Sharding**: List partitions are sharded by time to distribute load
- **Pagination**: All list operations support pagination via `exclusive_start_key`
- **Filtering**: Date-based filtering uses efficient query operations when possible

## Logging

The module provides detailed logging at DEBUG and INFO levels:
- Operation success/failure
- Performance metrics
- Data conversion warnings
- Error details with context

## Testing

The module is designed to be easily testable with mocked DynamoDB clients:

```python
from unittest.mock import Mock
from idp_common.dynamodb import DocumentDynamoDBService

# Mock client for testing
mock_client = Mock()
service = DocumentDynamoDBService(dynamodb_client=mock_client)

# Test operations
service.create_document(test_document)
mock_client.transact_write_items.assert_called_once()
```
