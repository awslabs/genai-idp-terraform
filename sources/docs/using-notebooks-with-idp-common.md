Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Using Notebooks with IDP Common Library

This guide provides detailed instructions on how to use existing notebooks and create new notebooks for experimentation with the IDP Common Library.

The /notebooks/examples directory contains a complete set of modular Jupyter notebooks that demonstrate the Intelligent Document Processing (IDP) pipeline using the `idp_common` library. Each notebook represents a distinct step in the IDP workflow and can be run independently or sequentially.

## 🏗️ Architecture Overview

The modular approach breaks down the IDP pipeline into discrete, manageable steps:

```
Step 0: Setup → Step 1: OCR → Step 2: Classification → Step 3: Extraction → Step 4: Assessment → Step 5: Summarization → Step 6: Evaluation
```

### Key Benefits

- **Independent Execution**: Each step can be run and tested independently
- **Modular Configuration**: Separate YAML configuration files for different components
- **Data Persistence**: Each step saves results for the next step to consume
- **Easy Experimentation**: Modify configurations without changing code
- **Comprehensive Evaluation**: Professional-grade evaluation with the EvaluationService
- **Debugging Friendly**: Isolate issues to specific processing steps

## 📁 Directory Structure

```
notebooks/examples/
├── README.md                          # This file
├── step0_setup.ipynb                  # Environment setup and document initialization
├── step1_ocr.ipynb                    # OCR processing using Amazon Textract
├── step2_classification.ipynb         # Document classification 
├── step3_extraction.ipynb             # Structured data extraction
├── step4_assessment.ipynb             # Confidence assessment and explainability
├── step5_summarization.ipynb          # Content summarization
├── step6_evaluation.ipynb             # Final evaluation and reporting
├── config/                            # Modular configuration files
│   ├── main.yaml                      # Main pipeline configuration
│   ├── classes.yaml                   # Document classification definitions
│   ├── ocr.yaml                       # OCR service configuration
│   ├── classification.yaml            # Classification method configuration
│   ├── extraction.yaml                # Extraction method configuration
│   ├── assessment.yaml                # Assessment method configuration
│   ├── summarization.yaml             # Summarization method configuration
│   └── evaluation.yaml                # Evaluation method configuration
└── data/                              # Step-by-step processing results
    ├── step0_setup/                   # Setup outputs
    ├── step1_ocr/                     # OCR results
    ├── step2_classification/          # Classification results
    ├── step3_extraction/              # Extraction results
    ├── step4_assessment/              # Assessment results
    ├── step5_summarization/           # Summarization results
    └── step6_evaluation/              # Final evaluation results
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Credentials**: Ensure your AWS credentials are configured
2. **Required Libraries**: Install the `idp_common` package
3. **Sample Document**: Place a PDF file in the project samples directory

### Running the Complete Pipeline

Execute the notebooks in sequence:

```bash
# 1. Setup environment and document
jupyter notebook step0_setup.ipynb

# 2. Process OCR
jupyter notebook step1_ocr.ipynb

# 3. Classify document sections
jupyter notebook step2_classification.ipynb

# 4. Extract structured data
jupyter notebook step3_extraction.ipynb

# 5. Assess confidence and explainability
jupyter notebook step4_assessment.ipynb

# 6. Generate summaries
jupyter notebook step5_summarization.ipynb

# 7. Evaluate results and generate reports
jupyter notebook step6_evaluation.ipynb
```

### Running Individual Steps

Each notebook can be run independently by ensuring the required input data exists:

```python
# Each notebook loads its inputs from the previous step's data directory
previous_step_dir = Path("data/step{n-1}_{previous_step_name}")
```

## ⚙️ Configuration Management

### Modular Configuration Files

Configuration is split across multiple YAML files for better organization:

- **`config/main.yaml`**: Overall pipeline settings and AWS configuration
- **`config/classes.yaml`**: Document type definitions and attributes to extract
- **`config/ocr.yaml`**: Textract features and OCR-specific settings  
- **`config/classification.yaml`**: Classification model and method configuration
- **`config/extraction.yaml`**: Extraction model and prompting configuration
- **`config/assessment.yaml`**: Assessment model and confidence thresholds
- **`config/summarization.yaml`**: Summarization models and output formats
- **`config/evaluation.yaml`**: Evaluation metrics and reporting settings

### Configuration Loading

Each notebook automatically merges all configuration files:

```python
# Automatic configuration loading in each notebook
CONFIG = load_and_merge_configs("config/")
```

### Experimentation with Configurations

To experiment with different settings:

1. **Backup Current Config**: Copy the config directory
2. **Modify Settings**: Edit the relevant YAML files
3. **Run Specific Steps**: Execute only the affected notebooks
4. **Compare Results**: Review outputs in the data directories

## 📊 Data Flow

### Input/Output Structure

Each step follows a consistent pattern:

```python
# Input (from previous step)
input_data_dir = Path("data/step{n-1}_{previous_name}")
document = Document.from_json((input_data_dir / "document.json").read_text())
config = json.load(open(input_data_dir / "config.json"))

# Processing
# ... step-specific processing ...

# Output (for next step)
output_data_dir = Path("data/step{n}_{current_name}")
output_data_dir.mkdir(parents=True, exist_ok=True)
(output_data_dir / "document.json").write_text(document.to_json())
json.dump(config, open(output_data_dir / "config.json", "w"))
```

### Serialized Artifacts

Each step produces:
- **`document.json`**: Updated Document object with step results
- **`config.json`**: Complete merged configuration  
- **`environment.json`**: Environment settings and metadata
- **Step-specific result files**: Detailed processing outputs

## 🔬 Detailed Step Descriptions

### Step 0: Setup (`step0_setup.ipynb`)
- **Purpose**: Initialize the Document object and prepare the processing environment
- **Inputs**: PDF file path, configuration files
- **Outputs**: Document object with pages and metadata
- **Key Features**: Multi-page PDF support, metadata extraction

### Step 1: OCR (`step1_ocr.ipynb`)
- **Purpose**: Extract text and analyze document structure using Amazon Textract
- **Inputs**: Document object with PDF pages
- **Outputs**: OCR results with text blocks, tables, and forms
- **Key Features**: Textract API integration, feature selection, result caching

### Step 2: Classification (`step2_classification.ipynb`)
- **Purpose**: Identify document types and create logical sections
- **Inputs**: Document with OCR results
- **Outputs**: Classified sections with confidence scores
- **Key Features**: Multi-modal classification, few-shot prompting, custom classes

### Step 3: Extraction (`step3_extraction.ipynb`)
- **Purpose**: Extract structured data from each classified section
- **Inputs**: Document with classified sections
- **Outputs**: Structured data for each section based on class definitions
- **Key Features**: Class-specific extraction, JSON schema validation

### Step 4: Assessment (`step4_assessment.ipynb`)
- **Purpose**: Evaluate extraction confidence and provide explainability
- **Inputs**: Document with extraction results
- **Outputs**: Confidence scores and reasoning for each extracted attribute
- **Key Features**: Confidence assessment, hallucination detection, explainability

### Step 5: Summarization (`step5_summarization.ipynb`)
- **Purpose**: Generate human-readable summaries of processing results
- **Inputs**: Document with assessed extractions
- **Outputs**: Section and document-level summaries in multiple formats
- **Key Features**: Multi-format output (JSON, Markdown, HTML), customizable templates

### Step 6: Evaluation (`step6_evaluation.ipynb`)
- **Purpose**: Comprehensive evaluation of pipeline performance and accuracy
- **Inputs**: Document with complete processing results
- **Outputs**: Evaluation reports, accuracy metrics, performance analysis
- **Key Features**: EvaluationService integration, ground truth comparison, detailed reporting

## 🧪 Experimentation Guide

### Modifying Document Classes

To add new document types or modify existing ones:

1. **Edit `config/classes.yaml`**:
```yaml
classes:
  new_document_type:
    description: "Description of the new document type"
    attributes:
      - name: "attribute_name"
        description: "What this attribute represents"
        type: "string"  # or "number", "date", etc.
```

2. **Run from Step 2**: Classification onwards to process with new classes

### Changing Models

To experiment with different AI models:

1. **Edit relevant config files**:
```yaml
# In config/extraction.yaml
llm_method:
  model: "anthropic.claude-3-5-sonnet-20241022-v2:0"  # Change model
  temperature: 0.1  # Adjust parameters
```

2. **Run affected steps**: Only the steps that use the changed configuration

### Adjusting Confidence Thresholds

To experiment with confidence thresholds:

1. **Edit `config/assessment.yaml`**:
```yaml
assessment:
  confidence_threshold: 0.7  # Lower threshold = more permissive
```

2. **Run Steps 4-6**: Assessment, Summarization, and Evaluation

### Performance Optimization

- **Parallel Processing**: Modify extraction/assessment to process sections in parallel
- **Caching**: Results are automatically cached between steps
- **Batch Processing**: Process multiple documents by running the pipeline multiple times

## 🐛 Troubleshooting

### Common Issues

1. **AWS Credentials**: Ensure proper AWS configuration
```bash
aws configure list
```

2. **Missing Dependencies**: Install required packages
```bash
pip install boto3 jupyter ipython
```

3. **Memory Issues**: For large documents, consider processing sections individually

4. **Configuration Errors**: Validate YAML syntax
```bash
python -c "import yaml; yaml.safe_load(open('config/main.yaml'))"
```

### Debug Mode

Enable detailed logging in any notebook:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Data Inspection

Each step saves detailed results that can be inspected:
```python
# Inspect intermediate results
import json
with open("data/step3_extraction/extraction_summary.json") as f:
    results = json.load(f)
    print(json.dumps(results, indent=2))
```

## 📈 Performance Monitoring

### Metrics Tracked

Each step automatically tracks:
- **Processing Time**: Total time for the step
- **Throughput**: Pages per second
- **Memory Usage**: Peak memory consumption
- **API Calls**: Number of service calls made
- **Error Rates**: Failed operations

### Performance Analysis

The evaluation step provides comprehensive performance analysis:
- Step-by-step timing breakdown
- Bottleneck identification  
- Resource utilization metrics
- Cost analysis (for AWS services)

## 🔒 Security and Best Practices

### AWS Security
- Use IAM roles with minimal required permissions
- Enable CloudTrail for API logging
- Store sensitive data in S3 with appropriate encryption

### Data Privacy
- Documents are processed in your AWS account
- No data is sent to external services (except configured AI models)
- Temporary files are cleaned up automatically

### Configuration Management
- Version control your configuration files
- Use environment-specific configurations for different deployments
- Document any custom modifications

## 🤝 Contributing

To extend or modify the notebooks:

1. **Follow the Pattern**: Maintain the input/output structure for compatibility
2. **Update Configurations**: Add new configuration options to appropriate YAML files
3. **Document Changes**: Update this README and add inline documentation
4. **Test Thoroughly**: Verify that changes work across the entire pipeline

## 📚 Additional Resources

- [IDP Common Library Documentation](../docs/using-notebooks-with-idp-common.md)
- [Configuration Guide](../docs/configuration.md)
- [Evaluation Methods](../docs/evaluation.md)
- [AWS Textract Documentation](https://docs.aws.amazon.com/textract/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)

---

**Happy Document Processing! 🚀**

For questions or support, refer to the main project documentation or create an issue in the project repository.
