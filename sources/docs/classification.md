Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Customizing Classification

Document classification is a key component of the GenAIIDP solution that categorizes each document or page into predefined classes. This guide explains how to customize classification to best suit your document processing needs.

## Classification Methods Across Patterns

The solution supports multiple classification approaches that vary by pattern:

### Pattern 1: BDA-Based Classification

- Classification is performed by the BDA (Bedrock Data Automation) project configuration
- Uses BDA blueprints to define classification rules
- Not configurable inside the GenAIIDP solution itself
- Configuration happens at the BDA project level

### Pattern 2: Bedrock LLM-Based Classification

Pattern 2 offers two main classification approaches, configured through different templates:

#### MultiModal Page-Level Classification with Sequence Segmentation (default)

- Classifies each page independently using both text and image data
- **Uses sequence segmentation with BIO-like tagging for document boundary detection**
- **Each page receives both a document type and a boundary indicator ("start" or "continue")**
- **Automatically segments multi-document packets where multiple documents may be combined**
- Works exceptionally well for complex document packets containing multiple documents of the same or different types
- Supports optional few-shot examples to improve classification accuracy
- Deployed when you select 'few_shot_example_with_multimodal_page_classification' during stack deployment
- See the [few-shot-examples.md](./few-shot-examples.md) documentation for details on configuring examples

##### Sequence Segmentation Approach

The multimodal page-level classification implements a sophisticated sequence segmentation approach similar to BIO (Begin-Inside-Outside) tagging commonly used in NLP. This enables accurate segmentation of multi-document packets where a single file may contain multiple distinct documents.

**How It Works:**

Each page receives two pieces of information during classification:
1. **Document Type**: The classification label (e.g., "invoice", "letter", "financial_statement")
2. **Document Boundary**: A boundary indicator that signals document transitions:
   - `"start"`: Indicates the beginning of a new document (similar to "Begin" in BIO)
   - `"continue"`: Indicates continuation of the current document (similar to "Inside" in BIO)

**Benefits of Sequence Segmentation:**

- **Multi-Document Packet Support**: Accurately segments packets containing multiple documents
- **Type-Aware Boundaries**: Detects when a new document of the same type begins
- **Automatic Section Creation**: Pages are grouped into sections based on both type and boundaries
- **Improved Accuracy**: Context-aware classification that considers document flow
- **No Manual Splitting Required**: Eliminates the need to manually separate documents before processing

**Example Segmentation:**

Consider a packet with 6 pages containing two invoices and one letter:

```
Page 1: type="invoice", boundary="start"      → Section 1 (Invoice #1)
Page 2: type="invoice", boundary="continue"   → Section 1 (Invoice #1)
Page 3: type="letter", boundary="start"       → Section 2 (Letter)
Page 4: type="letter", boundary="continue"    → Section 2 (Letter)
Page 5: type="invoice", boundary="start"      → Section 3 (Invoice #2)
Page 6: type="invoice", boundary="continue"   → Section 3 (Invoice #2)
```

The system automatically creates three sections, properly separating the two invoices despite them having the same document type.

**Configuration for Boundary Detection:**

The boundary detection is automatically included in the classification results. No special configuration is needed - the system will populate the `document_boundary` field in the metadata for each page:

```json
{
  "page_id": "1",
  "classification": {
    "doc_type": "invoice",
    "confidence": 0.95,
    "metadata": {
      "document_boundary": "start"  // New document begins
    }
  }
}
```
#### Text-Based Holistic Classification

- Analyzes entire document packets to identify logical boundaries
- Identifies distinct document segments within multi-page documents
- Determines document type for each segment
- Better suited for multi-document packets where context spans multiple pages
- Deployed when you select the default pattern-2 configuration during stack deployment or update

The default configuration in `config_library/pattern-2/default/config.yaml` implements this approach with a task prompt that instructs the model to:

1. Read through the entire document package to understand its contents
2. Identify page ranges that form complete, distinct documents
3. Match each document segment to one of the defined document types
4. Record the start and end pages for each identified segment

Example configuration:

```yaml
classification:
  classificationMethod: textbasedHolisticClassification
  model: us.amazon.nova-pro-v1:0
  task_prompt: >-
    <task-description>
    You are a document classification system. Your task is to analyze a document package 
    containing multiple pages and identify distinct document segments, classifying each 
    segment according to the predefined document types provided below.
    </task-description>

    <document-types>
    {CLASS_NAMES_AND_DESCRIPTIONS}
    </document-types>

    <document-boundary-rules>
    Rules for determining document boundaries:
    - Content continuity: Pages with continuing paragraphs, numbered sections, or ongoing narratives belong to the same document
    - Visual consistency: Similar layouts, headers, footers, and styling indicate pages belong together
    - Logical structure: Documents typically have clear beginning, middle, and end sections
    - New document indicators: Title pages, cover sheets, or significantly different subject matter signal a new document
    </document-boundary-rules>

    <<CACHEPOINT>>

    <document-text>
    {DOCUMENT_TEXT}
    </document-text>
  ```

##### Limitations of Text-Based Holistic Classification

Despite its strengths in handling full-document context, this method has several limitations:

**Context & Model Constraints:**: 
- Long documents can exceed the context window of smaller models, resulting in request failure.
- Lengthy inputs may dilute the model’s focus, leading to inaccurate or inconsistent classifications.
- Requires high-context models such as Amazon Nova Premier, which supports up to 1 million tokens. Smaller models are not suitable for this method.
- For more details on supported models and their context limits, refer to the [Amazon Bedrock Supported Models documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html).

**Scalability Challenges**: Not ideal for very large or visually complex document sets. In such cases, the Multi-Modal Page-Level Classification method is more appropriate.

### Pattern 3: UDOP-Based Classification

- Classification is performed by a pre-trained UDOP (Unified Document Processing) model
- Model is deployed on Amazon SageMaker
- Performs multi-modal page-level classification (classifies each page based on OCR data and page image)
- Not configurable inside the GenAIIDP solution

## Choosing Between Classification Methods

When deciding between Text-Based Holistic Classification and MultiModal Page-Level Classification with Sequence Segmentation, consider these factors:

### Use Text-Based Holistic Classification When:
- Documents have clear logical boundaries based on content
- Text context spans multiple pages and requires understanding the full document
- You have access to high-context models (e.g., Amazon Nova Premier)
- Document packets are relatively small (within model context limits)
- Visual elements are less important than textual continuity

### Use MultiModal Page-Level Classification with Sequence Segmentation When:
- **Document packets contain multiple documents of the same type** (e.g., multiple invoices)
- **Visual layout and image content are important for classification**
- **You need to process very large document packets** that might exceed context limits
- **Documents have clear visual boundaries** (headers, footers, different layouts)
- **You want to leverage both text and image information** for better accuracy
- **Processing speed is important** (parallel page processing is possible)

### Comparison Table

| Feature | Text-Based Holistic | MultiModal Page-Level with Sequence Segmentation |
|---------|-------------------|--------------------------------------------------|
| Context Awareness | Full document context | Page-level with boundary detection |
| Multi-document Packets | Good | Excellent (handles same-type documents) |
| Visual Processing | Text only | Text + Images |
| Model Requirements | High-context models | Standard models |
| Processing Speed | Sequential | Can be parallelized |
| Boundary Detection | Content-based | BIO-like tagging |
| Large Documents | Limited by context | No practical limit |

## Customizing Classification in Pattern 2

### Configuration Settings

#### Page Limit Configuration

Control how many pages are used for classification:

```yaml
classification:
  maxPagesForClassification: "ALL"  # Default: use all pages
  # Or: "1", "2", "3", etc. - use only first N pages
```

**Important**: When set to a number (e.g., `"3"`), only the first N pages are classified, but the result is applied to ALL pages in the document. This forces the entire document to be assigned a single class with one section.

### Prompt Components

In Pattern 2, you can customize classification behavior through various prompt components:

### System Prompts

Define overall model behavior and constraints:

```yaml
system_prompt: |
  You are an expert document classifier specializing in financial and business documents.
  Your task is to analyze document images and classify them into predefined categories.
  Focus on visual layout, textual content, and common patterns found in each document type.
  When in doubt, analyze the most prominent features like headers, logos, and form fields.
```

### Task Prompts

Specify classification instructions and formatting:

```yaml
task_prompt: |
  Analyze the following document page and classify it into one of these categories: 
  {{document_classes}}
  
  Return ONLY the document class name without additional explanations.
  If the document doesn't fit any of the provided classes, classify it as "other".
```

### Class Descriptions

Provide detailed descriptions for each document category:

```yaml
document_classes:
  invoice:
    description: "A commercial document issued by a seller to a buyer, related to a sale transaction and indicating the products, quantities, and agreed prices for products or services."
  receipt:
    description: "A document acknowledging that something of value has been received, often as proof of payment."
  bank_statement:
    description: "A document issued by a bank showing transactions and balances for a specific account over a defined period."
```

## Using CachePoint for Classification

The solution integrates with Amazon Bedrock CachePoint for improved performance:

- Caches frequently used prompts and responses
- Reduces latency for similar classification requests
- Optimizes costs through response reuse
- Automatic cache management and expiration

CachePoint is particularly beneficial with few-shot examples, as these can add significant token count to prompts. The `<<CACHEPOINT>>` delimiter in prompt templates separates:

- **Static portion** (before CACHEPOINT): Class definitions, few-shot examples, instructions
- **Dynamic portion** (after CACHEPOINT): The specific document being processed

This approach allows the static portion to be cached and reused across multiple document processing requests, while only the dynamic portion varies per document, significantly reducing costs and improving performance.

Example task prompt with CachePoint for few-shot examples:

```yaml
classification:
  task_prompt: |
    Classify this document into exactly one of these categories:
    
    {CLASS_NAMES_AND_DESCRIPTIONS}
    
    <few_shot_examples>
    {FEW_SHOT_EXAMPLES}
    </few_shot_examples>
    
    <<CACHEPOINT>>
    
    <document_content>
    {DOCUMENT_TEXT}
    </document_content>
```

## Document Classes

### Standard Document Classes

The solution includes standard document classes based on the RVL-CDIP dataset:

- `letter`: Formal written correspondence
- `form`: Structured documents with fields
- `email`: Digital messages with headers
- `handwritten`: Documents with handwritten content
- `advertisement`: Marketing materials
- `scientific_report`: Research documents
- `scientific_publication`: Academic papers
- `specification`: Technical specifications
- `file_folder`: Organizational documents
- `news_article`: Journalistic content
- `budget`: Financial planning documents
- `invoice`: Commercial billing documents
- `presentation`: Slide-based documents
- `questionnaire`: Survey forms
- `resume`: Employment documents
- `memo`: Internal communications

### Custom Document Classes

You can define custom document classes through the Web UI configuration:

1. Navigate to the Configuration section
2. Select the Document Classes tab
3. Click "Add New Class"
4. Provide:
   - Class name (machine-readable identifier)
   - Display name (human-readable name)
   - Detailed description (to guide the classification model)
5. Save changes

## Image Placement with {DOCUMENT_IMAGE} Placeholder

Pattern 2 supports precise control over where document images are positioned within your classification prompts using the `{DOCUMENT_IMAGE}` placeholder. This feature allows you to specify exactly where images should appear in your prompt template, rather than having them automatically appended at the end.

### How {DOCUMENT_IMAGE} Works

**Without Placeholder (Default Behavior):**
```yaml
classification:
  task_prompt: |
    Analyze this document:
    
    {DOCUMENT_TEXT}
    
    Classify it as one of: {CLASS_NAMES_AND_DESCRIPTIONS}
```
Images are automatically appended after the text content.

**With Placeholder (Controlled Placement):**
```yaml
classification:
  task_prompt: |
    Analyze this document:
    
    {DOCUMENT_IMAGE}
    
    Text content: {DOCUMENT_TEXT}
    
    Classify it as one of: {CLASS_NAMES_AND_DESCRIPTIONS}
```
Images are inserted exactly where `{DOCUMENT_IMAGE}` appears in the prompt.

### Usage Examples

**Image Before Text Analysis:**
```yaml
task_prompt: |
  Look at this document image first:
  
  {DOCUMENT_IMAGE}
  
  Now read the extracted text:
  {DOCUMENT_TEXT}
  
  Based on both the visual layout and text content, classify this document as one of:
  {CLASS_NAMES_AND_DESCRIPTIONS}
```

**Image in the Middle for Context:**
```yaml
task_prompt: |
  You are classifying business documents. Here are the possible types:
  {CLASS_NAMES_AND_DESCRIPTIONS}
  
  Examine this document image:
  {DOCUMENT_IMAGE}
  
  Additional text content extracted from the document:
  {DOCUMENT_TEXT}
  
  Classification:
```

### Integration with Few-Shot Examples

The `{DOCUMENT_IMAGE}` placeholder works seamlessly with few-shot examples:

```yaml
classification:
  task_prompt: |
    Here are examples of each document type:
    {FEW_SHOT_EXAMPLES}
    
    Now classify this new document:
    {DOCUMENT_IMAGE}
    
    Text: {DOCUMENT_TEXT}
    
    Classification: {CLASS_NAMES_AND_DESCRIPTIONS}
```

### Benefits

- **🎯 Contextual Placement**: Position images where they provide maximum context
- **📱 Better Multimodal Understanding**: Help models correlate visual and textual information
- **🔄 Flexible Prompt Design**: Create prompts that flow naturally between different content types
- **⚡ Improved Performance**: Strategic image placement can improve classification accuracy
- **🔒 Backward Compatible**: Existing prompts without the placeholder continue to work unchanged

### Multi-Page Documents

For documents with multiple pages, the system automatically handles image limits:

- **Bedrock Limit**: Maximum 20 images per request (automatically enforced)
- **Warning Logging**: System logs warnings when images are truncated due to limits
- **Smart Handling**: Images are processed in page order, with excess images automatically dropped

## Setting Up Few Shot Examples in Pattern 2

Pattern 2's multimodal page-level classification supports few-shot example prompting, which can significantly improve classification accuracy by providing concrete document examples. This feature is available when you select the 'few_shot_example_with_multimodal_page_classification' configuration.

### Benefits of Few-Shot Examples

- **🎯 Improved Accuracy**: Models understand document patterns better through concrete examples
- **📏 Consistent Output**: Examples establish exact structure and formatting standards
- **🚫 Reduced Hallucination**: Examples reduce likelihood of made-up classifications
- **🔧 Domain Adaptation**: Examples help models understand domain-specific terminology
- **💰 Cost Effectiveness with Caching**: Using prompt caching with few-shot examples significantly reduces costs

### Few Shot Example Configuration

In Pattern 2, few-shot examples are configured within document class definitions:

```yaml
classes:
  - name: letter
    description: "A formal written correspondence..."
    attributes:
      - name: sender_name
        description: "The name of the person who wrote the letter..."
    examples:
      - classPrompt: "This is an example of the class 'letter'"
        name: "Letter1"
        imagePath: "config_library/pattern-2/your_config/example-images/letter1.jpg"
      - classPrompt: "This is an example of the class 'letter'"
        name: "Letter2"
        imagePath: "config_library/pattern-2/your_config/example-images/letter2.png"
```

### Example Image Path Support

The `imagePath` field supports multiple formats:

- **Single Image File**: `"config_library/pattern-2/examples/letter1.jpg"`
- **Local Directory with Multiple Images**: `"config_library/pattern-2/examples/letters/"`
- **S3 Prefix with Multiple Images**: `"s3://my-config-bucket/examples/letter/"`
- **Direct S3 Image URI**: `"s3://my-config-bucket/examples/letter1.jpg"`

For comprehensive details on configuring few-shot examples, including multimodal vs. text-only approaches, example management, and advanced features, refer to the [few-shot-examples.md](./few-shot-examples.md) documentation.

## Image Processing Configuration

The classification service supports configurable image dimensions for optimal performance and quality:

### New Default Behavior (Preserves Original Resolution)

**Important Change**: Empty strings or unspecified image dimensions now preserve the original document resolution for maximum classification accuracy:

```yaml
classification:
  model: us.amazon.nova-pro-v1:0
  # Image processing settings - preserves original resolution
  image:
    target_width: ""     # Empty string = no resizing (recommended)
    target_height: ""    # Empty string = no resizing (recommended)
```

### Custom Image Dimensions

Configure specific dimensions when performance optimization is needed:

```yaml
# For high-accuracy classification with controlled dimensions
classification:
  image:
    target_width: "1200"   # Resize to 1200 pixels wide
    target_height: "1600"  # Resize to 1600 pixels tall

# For fast processing with lower resolution
classification:
  image:
    target_width: "600"    # Smaller for faster processing
    target_height: "800"   # Maintains reasonable quality
```

### Image Resizing Features

- **Original Resolution Preservation**: Empty strings preserve full document resolution for maximum accuracy
- **Aspect Ratio Preservation**: Images are resized proportionally without distortion when dimensions are specified
- **Smart Scaling**: Only downsizes images when necessary (scale factor < 1.0)
- **High-Quality Resampling**: Better visual quality after resizing
- **Performance Optimization**: Configurable dimensions allow balancing accuracy vs. speed

### Configuration Benefits

- **Maximum Classification Accuracy**: Empty strings preserve full document resolution for best results
- **Service-Specific Tuning**: Each service can use optimal image dimensions
- **Runtime Configuration**: No code changes needed to adjust image processing
- **Backward Compatibility**: Existing numeric values continue to work as before
- **Memory Optimization**: Configurable dimensions allow resource optimization
- **Better Resource Utilization**: Choose between accuracy (original resolution) and performance (smaller dimensions)

### Migration from Previous Versions

**Previous Behavior**: Empty strings defaulted to 951x1268 pixel resizing
**New Behavior**: Empty strings preserve original image resolution

If you were relying on the previous default resizing behavior, explicitly set dimensions:

```yaml
# To maintain previous default behavior
classification:
  image:
    target_width: "951"
    target_height: "1268"
```

### Best Practices for Classification

1. **Use Empty Strings for High Accuracy**: For critical document classification, use empty strings to preserve original resolution
2. **Consider Document Types**: Complex layouts benefit from higher resolution, simple text documents may work well with smaller dimensions
3. **Test Performance Impact**: Higher resolution images provide better accuracy but consume more resources
4. **Monitor Processing Time**: Balance classification accuracy with processing speed based on your requirements

## JSON and YAML Output Support

The classification service supports both JSON and YAML output formats from LLM responses, with automatic format detection and parsing:

### Automatic Format Detection

The system automatically detects whether the LLM response is in JSON or YAML format:

```yaml
# JSON response (traditional)
classification:
  task_prompt: |
    Classify this document and respond with JSON:
    {"class": "invoice", "confidence": 0.95}

# YAML response (more token-efficient)
classification:
  task_prompt: |
    Classify this document and respond with YAML:
    class: invoice
    confidence: 0.95
```

### Token Efficiency Benefits

YAML format provides significant token savings:

- **10-30% fewer tokens** than equivalent JSON
- No quotes required around keys
- More compact syntax for nested structures
- Natural support for multiline content

### Example Prompt Configurations

**JSON-focused prompt:**
```yaml
classification:
  system_prompt: |
    You are a document classifier. Respond only with JSON format.
  task_prompt: |
    Classify this document and return a JSON object with the class name and confidence score.
```

**YAML-focused prompt:**
```yaml
classification:
  system_prompt: |
    You are a document classifier. Respond only with YAML format.
  task_prompt: |
    Classify this document and return YAML with the class name and confidence score.
```

### Backward Compatibility

- All existing JSON-based prompts continue to work unchanged
- The system automatically detects and parses both formats
- No configuration changes required for existing deployments
- Intelligent fallback between formats if parsing fails

### Implementation Details

The classification service uses the new `extract_structured_data_from_text()` function which:

- Automatically detects JSON vs YAML format
- Provides robust parsing with multiple extraction strategies
- Handles malformed content gracefully
- Returns both parsed data and detected format for logging

## Regex-Based Classification for Performance Optimization

Pattern 2 now supports optional regex-based classification that can provide significant performance improvements and cost savings by bypassing LLM calls when document patterns are recognized.

### Document Name Regex (All Pages Same Class)

When you want all pages of a document to be classified as the same class, you can use document name regex to instantly classify entire documents based on their filename or ID:

```yaml
classes:
  - name: Payslip
    description: "Employee wage statement showing earnings and deductions"
    document_name_regex: "(?i).*(payslip|paystub|salary|wage).*"
    attributes:
      - name: EmployeeName
        description: "Name of the employee"
        attributeType: simple
```

**Benefits:**
- **Instant Classification**: Entire document classified without any LLM calls
- **Massive Performance Gains**: ~100-1000x faster than LLM classification
- **Zero Token Usage**: Complete elimination of API costs for matched documents
- **Deterministic Results**: Consistent classification for known patterns

**When document ID matches the pattern:**
- All pages are immediately classified as the matching class
- Single section is created containing all pages
- No backend service calls are made
- Info logging confirms regex match

### Page Content Regex (Multi-Modal Page-Level Classification)

For multi-class configurations using page-level classification, you can use page content regex to classify individual pages based on text patterns:

```yaml
classification:
  classificationMethod: multimodalPageLevelClassification

classes:
  - name: Invoice
    description: "Business invoice document"
    document_page_content_regex: "(?i)(invoice\\s+number|bill\\s+to|amount\\s+due)"
    attributes:
      - name: InvoiceNumber
        description: "Invoice number"
        attributeType: simple
  - name: Payslip
    description: "Employee wage statement"
    document_page_content_regex: "(?i)(gross\\s+pay|net\\s+pay|employee\\s+id)"
    attributes:
      - name: EmployeeName
        description: "Employee name"
        attributeType: simple
  - name: Other
    description: "Documents that don't match specific patterns"
    # No regex - will always use LLM
    attributes: []
```

**Benefits:**
- **Selective Performance Gains**: Pages matching patterns are classified instantly
- **Mixed Processing**: Some pages use regex, others fall back to LLM
- **Cost Optimization**: Reduced token usage proportional to regex matches
- **Maintained Accuracy**: LLM fallback ensures all pages are properly classified

**How it works:**
- Each page's text content is checked against all class regex patterns
- First matching pattern wins and classifies the page instantly
- Pages with no matches use standard LLM classification
- Results are seamlessly integrated into document sections

### Regex Pattern Best Practices

1. **Case-Insensitive Matching**: Always use `(?i)` flag
   ```regex
   (?i).*(invoice|bill).*  # Matches any case variation
   ```

2. **Flexible Whitespace**: Use `\\s+` for varying spaces/tabs
   ```regex
   (?i)(gross\\s+pay|net\\s+pay)  # Handles "gross pay", "gross  pay"
   ```

3. **Multiple Alternatives**: Use `|` for different terms
   ```regex
   (?i).*(payslip|paystub|salary|wage).*  # Any of these terms
   ```

4. **Balanced Specificity**: Specific enough to avoid false matches
   ```regex
   # Good: Specific to W2 forms
   (?i)(form\\s+w-?2|wage\\s+and\\s+tax|employer\\s+identification)
   
   # Too broad: Could match many documents
   (?i)(form|wage|tax)
   ```

### Performance Analysis

Use `notebooks/examples/step2_classification_with_regex.ipynb` to:
- Test regex patterns against your documents
- Compare processing speeds (regex vs LLM)
- Analyze cost savings through token usage reduction
- Validate classification accuracy
- Debug pattern matching behavior

### Error Handling

The regex system includes robust error handling:
- **Invalid Patterns**: Compilation errors are logged, system falls back to LLM
- **Runtime Failures**: Pattern matching errors default to LLM classification  
- **Graceful Degradation**: Service continues working with invalid regex
- **Comprehensive Logging**: Detailed logs for debugging pattern issues

### Configuration Examples

**Common Document Types:**
```yaml
classes:
  # W2 Tax Forms
  - name: W2
    document_page_content_regex: "(?i)(form\\s+w-?2|wage\\s+and\\s+tax|social\\s+security)"
    
  # Bank Statements  
  - name: Bank-Statement
    document_page_content_regex: "(?i)(account\\s+number|statement\\s+period|beginning\\s+balance)"
    
  # Driver Licenses
  - name: US-drivers-licenses
    document_page_content_regex: "(?i)(driver\\s+license|state\\s+id|date\\s+of\\s+birth)"
    
  # Invoices
  - name: Invoice
    document_page_content_regex: "(?i)(invoice\\s+number|bill\\s+to|remit\\s+payment)"
```

## Best Practices for Classification

1. **Provide Clear Class Descriptions**: Include distinctive features and common elements
2. **Use Few Shot Examples**: Include 2-3 diverse examples per class
3. **Choose the Right Method**: Use page-level with sequence segmentation for multi-document packets, holistic for context-dependent documents
4. **Balance Class Coverage**: Ensure all expected document types have classes
5. **Monitor and Refine**: Use the evaluation framework to track classification accuracy
6. **Consider Visual Elements**: Describe visual layout and design patterns in class descriptions
7. **Test with Real Documents**: Validate classification against actual document samples
8. **Optimize Image Dimensions**: Configure appropriate image sizes based on document complexity and processing requirements
9. **Balance Quality vs Performance**: Higher resolution images provide better accuracy but consume more resources
10. **Consider Output Format**: Use YAML prompts for token efficiency, especially with complex nested responses
11. **Leverage Format Flexibility**: Take advantage of automatic format detection to optimize prompts for different use cases
12. **Understand Boundary Indicators**: Review the `document_boundary` metadata to understand how documents are being segmented
13. **Handle Multi-Document Packets**: Use sequence segmentation when processing files containing multiple documents of the same type
14. **Test Segmentation Logic**: Verify that documents are correctly separated by reviewing section boundaries in the results
15. **Consider Document Flow**: Ensure your document classes account for typical document structures (headers, body, footers)
16. **Leverage BIO-like Tagging**: Take advantage of the automatic boundary detection to eliminate manual document splitting
17. **Use Regex for Known Patterns**: Add regex patterns for document types with predictable content or naming conventions
18. **Test Regex Thoroughly**: Validate regex patterns against diverse document samples before production use
19. **Balance Regex Specificity**: Make patterns specific enough to avoid false matches but flexible enough to catch variations
20. **Monitor Regex Performance**: Track how often regex patterns match vs fall back to LLM classification
