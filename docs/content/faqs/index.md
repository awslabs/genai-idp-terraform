# FAQs

Find answers to common questions about the GenAI IDP Accelerator for Terraform. If you don't find your answer here, please check our [troubleshooting guide](../deployment-guides/troubleshooting.md) or open an issue in the repository.

## Quick Navigation

- [General Questions](general.md) - About the project, features, and capabilities
- [Deployment Questions](deployment.md) - Installation, configuration, and setup
- [Troubleshooting](troubleshooting.md) - Common errors and solutions

## Most Common Questions

### What is the GenAI IDP Accelerator?

The GenAI IDP Accelerator is a collection of Terraform modules that enables rapid deployment of **Intelligent Document Processing** solutions on AWS. It combines services like Amazon Textract, Amazon Bedrock, and other AWS AI services to create end-to-end document processing workflows.

### What document formats are supported?

The accelerator supports:
- **PDFs** (text and image-based)
- **Images** (JPEG, PNG, TIFF)
- **Office documents** (Word, Excel, PowerPoint)
- **Text files**
- **Handwritten documents**

### Which AWS regions are supported?

The accelerator works in regions where all required services are available. Recommended regions include:
- `us-east-1` (N. Virginia) - Best service availability
- `us-west-2` (Oregon)
- `eu-west-1` (Ireland)
- `ap-southeast-1` (Singapore)

### How long does deployment take?

- **Basic pipeline**: 10-15 minutes
- **Advanced workflow**: 20-30 minutes
- **Enterprise setup**: 45-60 minutes

### Can I customize the processing logic?

Yes! The accelerator is designed to be highly customizable. You can:
- Modify existing Lambda functions
- Add custom processing steps
- Integrate with external APIs
- Create custom AI prompts
- Add business-specific logic

### How do I get support?

1. Check this FAQ and documentation
2. Review the [troubleshooting guide](../deployment-guides/troubleshooting.md)
3. Search existing issues in the repository
4. Open a new issue with detailed information

## Popular Topics

### Getting Started
- [Prerequisites](../getting-started/prerequisites.md)
- [Quick Start Guide](../getting-started/quick-start.md)
- [First Deployment](deployment.md#first-deployment)

### Common Issues
- [Permission Errors](troubleshooting.md#permission-errors)
- [Resource Limits](troubleshooting.md#resource-limits)
- [Deployment Failures](troubleshooting.md#deployment-failures)

### Customization
- [Custom Processing Logic](general.md#custom-processing)
- [Integration Options](general.md#integrations)

## Can't Find Your Answer?

If your question isn't answered here:

1. **Search the documentation** - Use the search function to find relevant information
2. **Check examples** - Review our [examples](../examples/index.md) for similar use cases
3. **Review deployment guides** - See our [deployment guides](../deployment-guides/index.md) for detailed instructions
4. **Open an issue** - Create a detailed issue in the repository

## Contributing to FAQs

Help improve this FAQ by:
- Suggesting new questions based on your experience
- Providing better answers to existing questions
- Sharing solutions to problems you've encountered
- Contributing examples and use cases

See our [contributing guide](../contributing/index.md) for more information.
