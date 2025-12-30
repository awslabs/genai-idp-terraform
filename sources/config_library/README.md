Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# GenAI IDP Accelerator Configuration Library

This directory serves as a centralized repository for configuration files used with the GenAI Intelligent Document Processing (IDP) Accelerator. It contains various configuration examples for different use cases, allowing users to quickly adapt the accelerator to their specific needs.

## Purpose

The Configuration Library:

- Provides ready-to-use configuration examples for common document processing scenarios
- Demonstrates best practices for configuring the GenAI IDP Accelerator
- Serves as a knowledge base of proven configurations for specific use cases
- Enables teams to share and reuse successful configurations
- Showcases advanced features like few-shot example prompting for improved accuracy

## Patterns

The GenAI IDP Accelerator supports three distinct architectural patterns, each with its own configuration requirements:

- **Pattern 1**: Uses Amazon Bedrock Data Automation (BDA) for document processing tasks
- **Pattern 2**: Uses Amazon Bedrock with Nova or Claude models for both page classification/grouping and information extraction
- **Pattern 3**: Uses UDOP (Unified Document Processing) for page classification and grouping, followed by Claude for information extraction

Each configuration in this library is designed for a specific pattern. The library contains configurations for Pattern 2, including examples demonstrating few-shot prompting capabilities.

## Few-Shot Example Support

The accelerator supports few-shot example prompting to improve processing accuracy by providing concrete examples of documents and their expected outputs. This is demonstrated in the `pattern-2/few_shot_example/` configuration.


## Validation Levels

To help users understand the reliability and testing status of each configuration, we use the following validation level indicators:

- **Level 0 - Experimental**: Configuration has been created but not systematically tested
- **Level 1 - Basic Testing**: Configuration has been tested with a small set of documents
- **Level 2 - Comprehensive Testing**: Configuration has been tested with a diverse set of documents and has shown consistent performance
- **Level 3 - Production Validated**: Configuration has been used in production environments with documented performance metrics

Each configuration's README.md should include its validation level and supporting evidence.

## Directory Structure

```
config_library/
├── README.md                      # This file
├── TEMPLATE_README.md             # Template for new configuration READMEs
├── pattern-1/                     # Pattern 1 configurations
│   └── <use_case_name>/           # Use case specific folder
│       ├── config.json            # Use case specific config
│       ├── samples/               # Sample documents for testing
│       └── README.md              # Documentation with validation level
├── pattern-2/                     # Pattern 2 configurations
│   ├── default/                   # Default configuration
│   │   ├── config.json            # Default config file
│   │   └── README.md              # Documentation for default config
│   ├── few_shot_example/          # Few-shot prompting example
│   │   ├── config.yaml            # Config with few-shot examples
│   │   ├── example-images/        # Example document images
│   │   └── README.md              # Documentation for few-shot feature
│   └── medical_records_summarization/  # Use case specific folder
│       ├── config.json            # Use case specific config
│       └── README.md              # Documentation with validation level
└── pattern-3/                     # Pattern 3 configurations
    └── <use_case_name>/           # Use case specific folder
        ├── config.json            # Use case specific config
        ├── samples/               # Sample documents for testing
        └── README.md              # Documentation with validation level
```

## Creating a New Configuration

To add a new configuration to the library:

1. **Determine the appropriate pattern** for your use case (Pattern 1, 2, or 3)

2. **Create a new directory** with a descriptive name that reflects the use case:
   ```
   mkdir -p config_library/pattern-X/your_use_case_name
   ```

3. **Copy and modify** the default configuration for that pattern:
   ```
   cp config_library/pattern-2/default/config.json config_library/pattern-X/your_use_case_name/config.json
   ```

4. **Modify the configuration** to suit your use case:
   - Update document classes and attributes
   - Adjust prompts for classification, extraction, or summarization
   - Tune model parameters (temperature, top_k, etc.)
   - Select appropriate models
   - Add few-shot examples if needed (see few_shot_example configuration for reference)

5. **Create a README.md** in your use case directory using the TEMPLATE_README.md as a guide. Include:
   - Description of the use case
   - Pattern association (Pattern 1, 2, or 3)
   - Validation level with supporting evidence
   - Key changes made to the configuration
   - Findings and results
   - Any limitations or considerations

6. **Include sample documents** in a samples/ directory to demonstrate the configuration's effectiveness

7. **Test your configuration** thoroughly before contributing

### Adding Few-Shot Examples

To add few-shot examples to your configuration:

1. **Create example images**: Collect clear, representative document images for each class
2. **Define examples**: Add `examples` array to each class with:
   - `classPrompt`: Text describing the document class
   - `attributesPrompt`: Expected attribute extraction in JSON format  
   - `imagePath`: Path to the example document image
   - `name`: Descriptive name for the example
3. **Update prompts**: Ensure task prompts include `{FEW_SHOT_EXAMPLES}` placeholder
4. **Test thoroughly**: Validate that examples improve accuracy

## Naming Conventions

- Use lowercase for directory names
- Use underscores to separate words in directory names
- Choose descriptive names that reflect the use case (e.g., `invoice_processing`, `medical_records_summarization`, `few_shot_example`)
- Keep names concise but informative

## Best Practices

### Document Classes

- Define classes with clear, specific descriptions
- Include all relevant attributes for each class
- Provide detailed descriptions for each attribute to guide extraction

### Few-Shot Examples

- **Quality Examples**: Use clear, representative examples of each document type
- **Diverse Examples**: Include examples that cover edge cases and variations
- **Accurate Labels**: Ensure `attributesPrompt` values are correct and consistent
- **Image Quality**: Use high-resolution, clear images for examples
- **Balanced Coverage**: Provide examples for your most important document classes

### Prompts

- Keep prompts clear and focused
- Include specific instructions for handling edge cases
- Balance prompt length with model context limitations
- Use consistent formatting and structure
- Include `{FEW_SHOT_EXAMPLES}` placeholder where appropriate

### Model Selection

- Choose models appropriate for the complexity of your task
- Consider cost vs. performance tradeoffs
- Document the rationale for model selection

### Configuration Management

- Document all significant changes
- Include version information when applicable
- Note any dependencies or requirements

## Contributing

When contributing a new configuration:

1. Ensure your configuration follows the structure and naming conventions
2. Include comprehensive documentation in your README.md with validation level
3. Test your configuration with representative documents
4. Document performance metrics and findings
5. Include sample documents for demonstration and testing
6. If using few-shot examples, include test notebooks demonstrating the capability

## Testing Few-Shot Configurations

Use the provided test notebooks to validate few-shot functionality:

- `notebooks/test_few_shot_classification.ipynb`: Test classification with examples
- `notebooks/test_few_shot_extraction.ipynb`: Test extraction with examples

These notebooks demonstrate how to test and validate few-shot example configurations.

By following these guidelines, we can build a valuable library of configurations that benefit the entire GenAI IDP Accelerator community.
