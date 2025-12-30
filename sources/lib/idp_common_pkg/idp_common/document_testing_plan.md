Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Document Class Standardization Testing Plan

## Overview

This testing plan outlines the strategy to validate the unified Document class implementation that combines features from both the main IDP Document class and the KIE Document class. The goal is to ensure the refactored Document class maintains all existing functionality while incorporating improvements in validation, type safety, and resource management.

## Test Categories

### 1. Unit Tests

#### Basic Functionality
- [ ] Test Document initialization with minimal parameters
- [ ] Test Document initialization with all parameters
- [ ] Verify default values are set correctly
- [ ] Test immutability of appropriate fields
- [ ] Verify validation rules on field values

#### URI Handling
- [ ] Test S3 URI parsing and validation
- [ ] Test local file URI parsing and validation
- [ ] Verify URI template placeholder substitution
- [ ] Test URI type detection (S3 vs local)
- [ ] Test invalid URI handling and error messages

#### Serialization/Deserialization
- [ ] Test to/from_dict conversion for simple documents
- [ ] Test to/from_dict conversion for complex documents with pages and sections
- [ ] Test to/from_json serialization
- [ ] Test from_s3_event creation
- [ ] Verify backward compatibility with old serialized documents

#### Lazy Loading
- [ ] Test cached_property behavior for heavy resources
- [ ] Verify resources are loaded only when accessed
- [ ] Test cleanup of cached resources
- [ ] Measure memory usage with lazy vs. eager loading

#### State Management
- [ ] Test status transitions
- [ ] Test timing fields update correctly
- [ ] Test error collection and reporting

### 2. Integration Tests

#### OCR Service Integration
- [ ] Test Document with OCR service 
- [ ] Verify page creation and population
- [ ] Test handling of OCR metadata
- [ ] Verify image and text URIs are stored correctly

#### Classification Service Integration
- [ ] Test Document with classification service
- [ ] Verify section creation based on classifications
- [ ] Test confidence scoring
- [ ] Verify multipage classification

#### Extraction Service Integration
- [ ] Test Document with extraction service
- [ ] Verify attribute extraction and storage
- [ ] Test section-based extraction
- [ ] Verify extraction URIs are stored correctly

#### Evaluation Service Integration
- [ ] Test Document with evaluation service
- [ ] Verify metrics calculation and storage
- [ ] Test comparison logic

### 3. Migration Tests

- [ ] Test converting old Document instances to new format
- [ ] Verify old code using Document class still works
- [ ] Test loading documents from existing S3 structures
- [ ] Verify compatibility with existing notebook examples

### 4. Performance Tests

- [ ] Measure initialization time comparison
- [ ] Measure serialization/deserialization performance
- [ ] Benchmark memory usage
- [ ] Test with large documents (100+ pages)
- [ ] Compare resource usage under load

### 5. Edge Case Tests

- [ ] Test with empty documents
- [ ] Test with malformed input
- [ ] Test with missing required fields
- [ ] Test with invalid URIs
- [ ] Test with corrupt OCR data
- [ ] Test with unavailable S3 resources
- [ ] Test with invalid sections or pages structure

## Testing Infrastructure

### Test Environment
- Local development environment
- CI/CD pipeline
- AWS environment for S3 integration tests

### Test Data
- Sample PDFs of various sizes and complexities
- Predefined OCR results
- Classification fixtures
- Extraction fixtures
- Evaluation fixtures

### Test Automation
- PyTest for unit and integration tests
- Performance benchmarking with pytest-benchmark
- Mocking S3 with moto
- CI/CD integration

## Test Implementation Strategy

1. **Setup Test Framework**
   - [ ] Set up PyTest with appropriate fixtures
   - [ ] Create mocks for AWS services
   - [ ] Establish test data repository

2. **Implement Core Tests**
   - [ ] Start with basic initialization and validation tests
   - [ ] Add serialization tests
   - [ ] Implement service integration tests

3. **Implement Migration Tests**
   - [ ] Create fixtures representing old Document instances
   - [ ] Test conversion logic
   - [ ] Verify backward compatibility

4. **Performance Testing**
   - [ ] Establish baseline with current implementation
   - [ ] Compare with new implementation
   - [ ] Optimize based on results

5. **Documentation**
   - [ ] Document test coverage
   - [ ] Add test examples to documentation
   - [ ] Update testing guidelines

## Success Criteria

1. All tests pass with the new implementation
2. No regressions in existing functionality
3. Performance meets or exceeds current implementation
4. Type safety and validation errors are caught early
5. Existing code using the Document class continues to work
6. New features are adequately tested

## Timeline

1. **Week 1**: Setup test framework and implement core unit tests
2. **Week 2**: Implement integration tests with main services
3. **Week 3**: Implement migration and backward compatibility tests
4. **Week 4**: Performance testing and optimization
5. **Week 5**: Edge case testing and final validation

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking changes to API | High | Medium | Thorough interface testing, backward compatibility layer |
| Performance degradation | High | Low | Performance benchmarking, optimization phase |
| Missed edge cases | Medium | Medium | Comprehensive test suite, code reviews |
| S3 integration issues | Medium | Low | Mocking S3 for tests, separate integration test suite |
| Migration issues | High | Medium | Extensive migration testing, rollback plan |
