Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

move# Document Class Standardization Todos

## Background

The IDP Accelerator currently has two different Document class implementations:

1. **Main Document Class** (in `idp_common/models.py`):
   - Comprehensive document representation for the entire pipeline
   - Uses dataclasses
   - Tracks processing state, pages, sections, and various metadata
   - Built for end-to-end integration

2. **KIE Document Class** (in `genaidp_lib/src/genaidp_lib/key_information_extraction/src/datatypes/document.py`):
   - Pydantic-based implementation with strong validation
   - More focused on document loading for extraction
   - Better URI handling with explicit type checking
   - Immutable design with lazy loading

## Standardization Goals

The goal is to unify these implementations into a single, robust Document model that combines the best aspects of both.

## Action Items

1. **Migrate to Pydantic**
   - [ ] Refactor main Document class to use Pydantic instead of dataclasses
   - [ ] Add field validators for core attributes
   - [ ] Create proper config with immutability settings where appropriate

2. **Improve Type Safety**
   - [ ] Replace usages of `Any` type with specific type definitions
   - [ ] Add proper typing for nested structures
   - [ ] Add type hints for all methods

3. **Enhance URI Handling**
   - [ ] Adopt the URI type distinction (S3 vs local) from KIE implementation
   - [ ] Implement cleaner URI parsing and validation
   - [ ] Add template support with placeholders

4. **Optimize Resource Usage**
   - [ ] Implement lazy loading with cached_property for heavy resources
   - [ ] Add explicit cleanup methods for large resources
   - [ ] Consider context manager support for resource management

5. **Define Clear Interfaces**
   - [ ] Create Protocol or ABC definitions for service interactions
   - [ ] Separate interface from implementation details
   - [ ] Define standard methods for document processing stages

6. **Improve Serialization**
   - [ ] Ensure comprehensive serialization/deserialization
   - [ ] Support JSON Schema validation
   - [ ] Add versioning for backward compatibility

7. **Documentation & Examples**
   - [ ] Add comprehensive docstrings to all classes and methods
   - [ ] Create example workflows showing document usage patterns
   - [ ] Document best practices for document manipulation

## Implementation Strategy

1. Start with the main Document class as the foundation
2. Incrementally adopt features from the KIE implementation
3. Maintain backward compatibility where possible
4. Introduce new interfaces gradually with deprecation warnings for old methods
5. Ensure comprehensive test coverage for all changes
