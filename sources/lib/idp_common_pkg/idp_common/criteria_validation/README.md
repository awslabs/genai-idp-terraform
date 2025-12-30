# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# IDP Criteria Validation Module

This module provides functionality for validating documents against dynamic business rules/criteria using LLMs, specifically designed for healthcare/insurance prior authorization validation and similar compliance workflows.

## Overview

The criteria validation module processes user history documents, evaluates them against configurable criteria questions, and generates structured validation responses with recommendations (Pass/Fail/Information Not Found). It supports asynchronous processing, intelligent text chunking, multi-file processing with summarization, and comprehensive cost and performance tracking.

## Key Features

- **Asynchronous Processing**: Handles multiple criteria types and questions concurrently using asyncio
- **Rate Limiting**: Built-in semaphore-based rate limiting for API calls to prevent throttling
- **Intelligent Text Chunking**: Automatically chunks large documents with configurable overlap for context preservation
- **Multi-File Support**: Processes multiple user history files with intelligent summarization across responses
- **Comprehensive Tracking**: Token usage, cost tracking, and detailed timing metrics
- **Robust Error Handling**: Graceful degradation with fallback responses and detailed error logging
- **Pydantic Validation**: Strong data validation for inputs and outputs with automatic data cleaning
- **JSON Response Parsing**: Intelligent parsing of LLM responses including markdown code block handling

## Components

### Models

The module provides three core data models with comprehensive validation:

#### BedrockInput
Input model for Bedrock LLM criteria validation requests:
- **question**: The criteria question to evaluate
- **prompt**: The formatted prompt for the LLM
- **system_prompt**: System-level instructions for the LLM
- **criteria_type**: Type of criteria being evaluated
- **recommendation**: Available recommendation options
- **user_history**: Patient/user history as context (optional)
- **txt_file_uri**: Source file location (optional)
- **initial_response**: Initial results for multi-file processing (optional)

#### LLMResponse
Validated response model from LLM with automatic data cleaning:
- **criteria_type**: Type of criteria being evaluated
- **source_file**: List of source file S3 URIs (automatically normalized)
- **question**: Question being evaluated
- **Recommendation**: Validated recommendation (Pass/Fail/Information Not Found)
- **Reasoning**: Cleaned explanation text with markdown/special character removal

Features automatic validation and cleaning:
- Recommendation values are strictly validated
- Reasoning text is cleaned of non-printable characters and markdown
- Source files are normalized to S3 URI format
- Whitespace is automatically stripped

#### CriteriaValidationResult
Complete validation result dataclass:
- **request_id**: Unique identifier for the request
- **criteria_type**: Primary criteria type processed
- **validation_responses**: List of all validation responses
- **summary**: Summarized responses for multi-file processing (optional)
- **metering**: Token usage and cost tracking data
- **metadata**: Additional metadata including timing and output URIs
- **output_uri**: Primary output location (optional)
- **errors**: List of any errors encountered (optional)
- **cost_tracking**: Detailed cost tracking information (optional)

### Service

#### CriteriaValidationService
Main service class providing comprehensive validation functionality:

**Core Methods:**
- `validate_request()`: Synchronous wrapper for complete request validation
- `validate_request_async()`: Main async method for processing requests with full workflow
- `_process_criteria_type()`: Process all questions for a specific criteria type
- `_process_criteria_question()`: Process individual criteria questions with rate limiting
- `_chunk_text_with_overlap()`: Intelligent text chunking with configurable overlap
- `_prepare_prompt()`: Template-based prompt preparation with placeholder substitution
- `_invoke_model_async()`: Async wrapper for bedrock client integration
- `_summarize_responses()`: Multi-file response summarization

**Key Features:**
- Automatic text chunking for large documents
- Concurrent processing with configurable semaphore limits
- Comprehensive token and timing metrics collection
- Thread-safe metering data aggregation using async locks
- Graceful error handling with fallback responses

## Usage

### Basic Synchronous Usage

```python
from idp_common import get_config
from idp_common.criteria_validation import CriteriaValidationService

# Initialize service with configuration
config = get_config()
service = CriteriaValidationService(config=config)

# Validate a request
result = service.validate_request(
    request_id="123456789",
    config={
        "request_bucket": "my-bucket",
        "request_history_prefix": "prior-auth",
        "criteria_bucket": "criteria-bucket",
        "criteria_types": ["administration_requirements", "medical_necessity"],
        "model_id": "us.anthropic.claude-3-5-sonnet-20240620-v1:0",
        "recommendation_options": "Pass/Fail/Information Not Found",
        "system_prompt": "You are an expert at evaluating healthcare criteria...",
        "task_prompt": "Evaluate the following criteria: {question}...",
        # Configuration details below
    }
)

# Access results
print(f"Request ID: {result.request_id}")
print(f"Token usage: {result.metering}")
print(f"Total duration: {result.metadata['timing']['total_duration']} seconds")
print(f"Output URIs: {result.metadata['output_uris']}")
```

### Advanced Async Usage

```python
import asyncio
from idp_common.criteria_validation import CriteriaValidationService

async def validate_multiple_requests():
    service = CriteriaValidationService(config=config)
    
    # Process multiple requests concurrently
    tasks = []
    for request_id in ["req1", "req2", "req3"]:
        task = service.validate_request_async(
            request_id=request_id,
            config=validation_config
        )
        tasks.append(task)
    
    # Wait for all to complete
    results = await asyncio.gather(*tasks)
    
    # Aggregate metrics
    total_tokens = sum(r.metering.get('total_tokens', 0) for r in results)
    print(f"Total tokens used: {total_tokens}")
    
    return results

# Run async processing
results = asyncio.run(validate_multiple_requests())
```

### Document-based Integration

```python
from idp_common.models import Document
from idp_common.criteria_validation import CriteriaValidationService

# For future integration with Document model
# (Currently processes S3 text files directly)
def process_document_criteria(document: Document, criteria_types: List[str]):
    service = CriteriaValidationService(config=config)
    
    # Extract text content from document sections
    user_history = "\n".join([
        section.get_text_content() 
        for section in document.sections
    ])
    
    # Process criteria (future enhancement)
    # This would integrate with the existing validate_request flow
    pass
```

## Configuration

The service expects comprehensive configuration with the following structure:

### Core Configuration

```python
{
    "criteria_validation": {
        "model": "us.anthropic.claude-3-5-sonnet-20240620-v1:0",
        "temperature": 0.0,  # Default: 0.0
        "top_k": 5,  # Default: 5
        "top_p": 0.1,  # Default: 0.1
        "max_tokens": None,  # Optional max tokens
        "semaphore": 5,  # Default: 5 - Concurrent request limit
        "max_chunk_size": 10000,  # Default: 10000 - Max tokens per chunk
        "token_size": 4,  # Default: 4 - Average chars per token estimation
        "overlap_percentage": 10,  # Default: 10 - Chunk overlap percentage
    },
    
    # Required prompts
    "system_prompt": "You are an expert at evaluating healthcare prior authorization criteria...",
    "task_prompt": """Evaluate the following criteria question against the user history:
        
        Question: {question}
        Criteria Type: {criteria_type}
        User History: {content}
        Source File: {source_filepath}
        
        Recommendation Options: {recommendation_options}
        
        Provide your response in JSON format...""",
    
    # S3 locations
    "request_bucket": "user-history-bucket",
    "request_history_prefix": "prior-auth",
    "criteria_bucket": "criteria-bucket",
    "output_bucket": "results-bucket",  # Optional, defaults to request_bucket
    
    # Processing configuration
    "criteria_types": ["administration_requirements", "medical_necessity"],
    "recommendation_options": "Pass/Fail/Information Not Found",
    
    # Multi-file summarization (optional)
    "summary": {
        "system_prompt": "You are an expert at summarizing validation responses...",
        "task_prompt": """Summarize the following responses for question: {question}
        
        Initial Responses: {initial_response}
        Criteria Type: {criteria_type}
        
        Provide consolidated recommendation...""",
        "temperature": 0.0
    }
}
```

### Configuration Parameters Details

#### Processing Controls
- **semaphore** (default: 5): Controls concurrent LLM requests to prevent rate limiting
- **max_chunk_size** (default: 10000): Maximum tokens per text chunk for processing
- **token_size** (default: 4): Average characters per token for chunking estimation
- **overlap_percentage** (default: 10): Percentage overlap between text chunks for context preservation

#### Model Parameters
- **temperature** (default: 0.0): LLM temperature for deterministic responses
- **top_k** (default: 5): Top-k sampling parameter
- **top_p** (default: 0.1): Top-p sampling parameter  
- **max_tokens**: Optional maximum tokens in response

#### Text Chunking Strategy
Large documents are automatically chunked with intelligent overlap:
1. Estimate tokens using `len(text) // token_size`
2. If exceeding `max_chunk_size`, split into overlapping chunks
3. Each chunk overlaps by `overlap_percentage` with the next
4. Process each chunk independently and aggregate results

## File Structure Requirements

### User History Files
User history documents must be stored as text files in S3:
```
s3://{request_bucket}/{request_history_prefix}-{request_id}/extracted_text/
├── file1.txt
├── file2.txt
└── file3.txt
```

**Requirements:**
- Must be `.txt` files with UTF-8 encoding
- Automatically chunked if exceeding token limits
- Multiple files are processed with optional summarization

### Criteria Files
Criteria definitions are stored as JSON files in S3:
```
s3://{criteria_bucket}/{criteria_type}.json
```

**Format:**
```json
{
    "criteria": [
        "Will the therapy be administered under qualified medical supervision?",
        "Is the facility equipped to handle potential emergency situations?",
        "Has the physician determined the appropriate dosage and schedule?",
        "Are there documented contraindications or drug interactions?"
    ]
}
```

**Requirements:**
- Valid JSON format with `criteria` array
- Each criteria is a string question
- Questions should be specific and answerable from user history

## Output Format

### Individual Response Format
Each validation generates a structured response:

```json
{
    "criteria_type": "administration_requirements",
    "source_file": ["s3://bucket/extracted_text/file1.txt"],
    "question": "Is the facility equipped to handle emergencies?",
    "Recommendation": "Pass",
    "Reasoning": "The document confirms that the outpatient facility has emergency protocols and staff trained in emergency response procedures."
}
```

### Result Storage Structure
Results are saved to S3 with organized structure:

```
s3://{output_bucket}/responses/
├── request_id_{request_id}_administration_requirements_responses.json
├── request_id_{request_id}_medical_necessity_responses.json
└── request_id_{request_id}_coverage_requirements_responses.json
```

### Validation Response Processing
The service includes intelligent JSON response parsing:

1. **Markdown Code Block Handling**: Automatically extracts JSON from ```json code blocks
2. **Validation**: Uses Pydantic models for strict response validation
3. **Fallback Responses**: Generates structured fallback for parsing failures
4. **Data Cleaning**: Automatically cleans reasoning text and normalizes file paths

```python
# Example parsing logic
if "```json" in response_text:
    start_idx = response_text.find("```json") + 7
    end_idx = response_text.find("```", start_idx)
    response_text = response_text[start_idx:end_idx].strip()

try:
    response_dict = json.loads(response_text)
    validated_response = LLMResponse(**response_dict)
except json.JSONDecodeError:
    # Fallback response with error details
    response_dict = {
        "criteria_type": criteria_type,
        "question": question,
        "source_file": [txt_file_uri],
        "Recommendation": "Information Not Found",
        "Reasoning": f"Failed to parse response: {response_text}"
    }
```

## Performance Tracking

### Token Usage Tracking
The service provides comprehensive token and cost tracking:

```python
# Automatic token aggregation using utils.merge_metering_data
async with self.metrics_lock:  # Thread-safe updates
    self.token_metrics = utils.merge_metering_data(
        self.token_metrics, 
        response.get("metering", {})
    )
```

**Tracked Metrics:**
- Input tokens per request
- Output tokens per request
- Total tokens across all criteria
- Cost estimations
- Token usage by criteria type

### Timing Metrics
Detailed timing information is collected:

```python
{
    "timing": {
        "start_time": "2024-01-15T10:30:00",
        "end_time": "2024-01-15T10:32:15", 
        "total_duration": 135.2,  # seconds
        "criteria_processing_time": [
            {"criteria_type": "administration_requirements", "duration": 45.1},
            {"criteria_type": "medical_necessity", "duration": 67.3}
        ]
    }
}
```

## Integration with IDP Pipeline

The criteria validation module integrates seamlessly with the IDP accelerator:

### Common Components Integration
1. **Bedrock Client**: Uses `idp_common.bedrock.invoke_model` for consistent LLM interactions
2. **Metering Collection**: Automatic token usage tracking with `utils.merge_metering_data`
3. **S3 Operations**: Uses `idp_common.s3` for file operations and content management
4. **Configuration Management**: Compatible with `idp_common.get_config()`

### Future Document Model Integration
```python
# Planned integration with Document model
from idp_common.models import Document

def validate_document_criteria(
    document: Document, 
    criteria_types: List[str]
) -> Document:
    """Future method to validate Document instances directly."""
    # Will integrate with existing validation workflow
    # Adding criteria validation results to document metadata
    pass
```

### Pipeline Workflow Integration
1. **Document Processing**: Extract text content from processed documents
2. **Criteria Validation**: Apply business rules validation
3. **Result Integration**: Combine with classification and extraction results
4. **Downstream Processing**: Use validation results for decision making

## Error Handling

The service includes comprehensive error handling at multiple levels:

### Request-Level Error Handling
```python
try:
    result = service.validate_request(request_id, config)
except ValueError as e:
    # Configuration or input validation errors
    logger.error(f"Validation error: {str(e)}")
except Exception as e:
    # Unexpected errors
    logger.error(f"Unexpected error: {str(e)}")
```

### Question-Level Error Handling
Individual question processing includes graceful degradation:
- **LLM Failures**: Automatic fallback responses with error details
- **JSON Parsing Errors**: Structured error responses maintaining data integrity
- **Network Issues**: Retry logic and detailed error logging
- **Rate Limiting**: Automatic semaphore-based throttling

### Multi-File Error Handling
- **Missing Files**: Clear error messages for missing user history files
- **Partial Failures**: Continue processing remaining files if some fail
- **Summarization Errors**: Fallback to individual responses if summarization fails

## Performance Optimization

### Concurrent Processing
```python
# Optimal semaphore configuration
"semaphore": 5,  # Start with 5, adjust based on rate limits

# Monitor for rate limiting and adjust accordingly
"semaphore": 3,  # Reduce if hitting rate limits
"semaphore": 8,  # Increase if responses are slow and no rate limiting
```

### Text Chunking Optimization
```python
# Balance context preservation vs. cost
"max_chunk_size": 8000,   # Smaller chunks = more requests, better accuracy
"max_chunk_size": 15000,  # Larger chunks = fewer requests, higher cost
"overlap_percentage": 15,  # Higher overlap = better context, more tokens
```

### Memory Management
- **Async Processing**: Non-blocking I/O for better resource utilization
- **Result Streaming**: Immediate S3 storage to prevent memory buildup
- **Chunk Processing**: Process large documents in manageable pieces

### Cost Optimization
1. **Token Monitoring**: Track usage per criteria type for cost attribution
2. **Chunk Size Tuning**: Balance accuracy vs. token consumption
3. **Summarization Strategy**: Use only when processing multiple files
4. **Model Selection**: Choose appropriate model for accuracy/cost balance

## Troubleshooting

### Common Issues and Solutions

#### No Text Files Found
```python
# Error: "No text files found for request {request_id}"
# Solution: Verify file locations and naming
expected_location = f"s3://{request_bucket}/{request_history_prefix}-{request_id}/extracted_text/"
# Ensure files exist and have .txt extension
```

#### JSON Parsing Failures
```python
# Symptoms: "Information Not Found" responses with parsing errors
# Solutions:
1. Review system_prompt and task_prompt for clear JSON format instructions
2. Add example JSON structure in prompts
3. Check for temperature = 0.0 for deterministic responses
4. Verify recommendation_options match expected values
```

#### Rate Limiting Issues
```python
# Symptoms: HTTP 429 errors or slow processing
# Solutions:
"semaphore": 3,  # Reduce concurrent requests
# Add exponential backoff in production
# Monitor CloudWatch metrics for throttling
```

#### High Token Costs
```python
# Solutions for cost optimization:
"max_chunk_size": 8000,    # Reduce chunk size
"overlap_percentage": 5,   # Reduce overlap
# Use more specific criteria questions
# Implement response caching for repeated requests
```

#### Memory Issues with Large Files
```python
# Solutions:
1. Enable chunking for all files above certain size
2. Process files sequentially instead of concurrently
3. Implement streaming for very large documents
4. Use smaller overlap percentages
```

### Debug Logging
Enable detailed logging to troubleshoot issues:

```python
import logging
logging.getLogger('idp_common.criteria_validation').setLevel(logging.DEBUG)

# Key debug information logged:
# - Token metrics before/after merge
# - Chunk processing details
# - Response parsing steps
# - Timing information
# - S3 operations
```

### Monitoring and Metrics

Key metrics to monitor in production:
- **Token Usage**: Track usage patterns and costs
- **Processing Time**: Monitor timing metrics by criteria type
- **Error Rates**: Track parsing failures and LLM errors
- **Throughput**: Requests processed per hour
- **Cost Attribution**: Cost breakdown by criteria type and request

## Best Practices

### Configuration Management
1. **Environment-specific Configs**: Separate configs for dev/prod
2. **Parameter Tuning**: Start with defaults, adjust based on performance
3. **Cost Monitoring**: Set up alerts for unexpected token usage
4. **Error Thresholds**: Monitor error rates and adjust accordingly

### Criteria Design
1. **Specific Questions**: Write clear, answerable criteria questions
2. **Binary Decisions**: Design for Pass/Fail outcomes when possible
3. **Context Requirements**: Ensure questions can be answered from typical user history
4. **Regular Updates**: Review and update criteria based on business needs

### Processing Optimization
1. **Batch Processing**: Process multiple requests together when possible
2. **Caching**: Cache results for identical requests
3. **Monitoring**: Set up comprehensive monitoring and alerting
4. **Testing**: Regular testing with representative data

## Future Enhancements

### Planned Features
- **Document Model Integration**: Direct integration with Document instances
- **Confidence Scoring**: Confidence levels for recommendations
- **Custom Validation Rules**: Programmable validation logic beyond LLM
- **Real-time Endpoints**: API endpoints for real-time validation
- **Enhanced Caching**: Intelligent caching based on content similarity

### Advanced Features Under Consideration
- **Multi-Modal Support**: Integration of document images with text
- **Feedback Loop Integration**: Learning from validation corrections
- **Custom Model Support**: Support for domain-specific fine-tuned models
- **Workflow Integration**: Integration with approval workflows
- **Audit Trail**: Comprehensive audit logging for compliance

### Performance Enhancements
- **Streaming Responses**: Real-time processing updates
- **Parallel File Processing**: Concurrent processing of multiple files
- **Advanced Chunking**: Semantic chunking based on document structure
- **Response Optimization**: Optimized prompts for faster/cheaper responses

## Version History

- **v1.0**: Initial implementation with basic validation workflow
- **v1.1**: Added async processing and rate limiting
- **v1.2**: Implemented text chunking and multi-file support
- **v1.3**: Added comprehensive tracking and error handling
- **Current**: Enhanced documentation and troubleshooting guidance
