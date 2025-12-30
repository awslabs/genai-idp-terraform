# Discovery Module Unit Tests

This directory contains comprehensive unit tests for the `idp_common.discovery` module, specifically focusing on the `ClassesDiscovery` class.

## Test Files

### `test_classes_discovery.py`
Contains unit tests for individual methods and components of the `ClassesDiscovery` class:

- **Initialization Tests**: Verify proper setup of the class with different configurations
- **Utility Method Tests**: Test helper methods like `_stringify_values`, `_get_base64_image`, etc.
- **Configuration Management Tests**: Test DynamoDB configuration retrieval and updates
- **Document Processing Tests**: Test document content extraction and processing
- **Ground Truth Tests**: Test ground truth data loading and processing
- **Bedrock Integration Tests**: Test integration with the Bedrock client
- **Content Creation Tests**: Test content list creation for different file formats (PDF, images)
- **Prompt Generation Tests**: Test prompt creation for different scenarios
- **Error Handling Tests**: Test various error conditions and edge cases

### `test_classes_discovery_integration.py`
Contains integration tests that demonstrate complete workflows:

- **Complete W-4 Discovery Workflow**: End-to-end test of discovering W-4 form structure
- **Ground Truth Integration**: Test discovery workflow with ground truth data
- **Configuration Updates**: Test updating existing configurations
- **Error Recovery**: Test error handling and recovery mechanisms
- **File Format Support**: Test different file formats (PDF, JPG, etc.)

## Test Coverage

The tests cover:

### Core Functionality
- ✅ Document class discovery from images and PDFs
- ✅ Ground truth-enhanced discovery
- ✅ Configuration management in DynamoDB
- ✅ Bedrock client integration
- ✅ S3 file processing

### Edge Cases
- ✅ Invalid file formats
- ✅ Missing configuration items
- ✅ Bedrock API errors
- ✅ S3 access errors
- ✅ Invalid JSON responses
- ✅ Empty configurations

### Integration Points
- ✅ BedrockClient integration
- ✅ DynamoDB operations
- ✅ S3 file operations
- ✅ JSON parsing and validation
- ✅ Base64 encoding/decoding

## Running the Tests

### Run all discovery tests:
```bash
python -m pytest tests/unit/discovery/ -v
```

### Run specific test file:
```bash
python -m pytest tests/unit/discovery/test_classes_discovery.py -v
python -m pytest tests/unit/discovery/test_classes_discovery_integration.py -v
```

### Run with coverage:
```bash
python -m pytest tests/unit/discovery/ --cov=idp_common.discovery --cov-report=html
```

## Test Patterns

The tests follow established patterns from other modules in the codebase:

1. **Fixture-based Setup**: Using pytest fixtures for consistent test data
2. **Mock-heavy Testing**: Extensive use of mocks to isolate units under test
3. **Comprehensive Error Testing**: Testing both success and failure paths
4. **Integration Testing**: End-to-end workflow validation
5. **Realistic Test Data**: Using realistic form data (W-4 examples)

## Mock Strategy

The tests use a comprehensive mocking strategy:

- **BedrockClient**: Mocked to avoid actual API calls
- **DynamoDB**: Mocked table operations
- **S3Util**: Mocked file operations
- **Environment Variables**: Controlled via `patch.dict`

This ensures tests are:
- Fast and reliable
- Independent of external services
- Deterministic in their outcomes
- Safe to run in any environment

## Test Data

The tests use realistic test data including:
- W-4 form structure examples
- Ground truth data for tax forms
- Various file formats (PDF, JPG)
- Error scenarios and edge cases

This ensures the tests validate real-world usage patterns while maintaining test isolation.