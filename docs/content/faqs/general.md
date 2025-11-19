# General Questions

Common questions about the GenAI IDP Accelerator for Terraform.

## What is the GenAI IDP Accelerator?

The GenAI IDP Accelerator is a comprehensive solution for **Intelligent Document Processing** using AWS services and generative AI. It provides pre-built Terraform modules to quickly deploy document processing pipelines that can extract, analyze, and process information from various document types.

## What document types are supported?

The accelerator supports common document formats including:
- PDF documents
- Images (PNG, JPEG, TIFF)
- Scanned documents
- Forms and invoices
- Contracts and legal documents

## Which AWS services does it use?

Key AWS services include:
- **Amazon Textract**: For text and data extraction
- **Amazon Bedrock**: For AI-powered analysis and processing
- **AWS Lambda**: For serverless compute
- **Amazon S3**: For document storage
- **Amazon DynamoDB**: For metadata storage
- **Amazon API Gateway**: For REST API endpoints

## Can I customize the processing logic?

Yes, the accelerator is designed to be customizable:
- Modify Lambda function code for custom processing
- Adjust AI prompts for specific use cases
- Add new document types and processing workflows
- Integrate with existing systems and databases

## What are the prerequisites?

To use the accelerator, you need:
- AWS account with appropriate permissions
- Terraform installed (version 1.0+)
- AWS CLI configured
- Access to Amazon Bedrock models
- Basic knowledge of Terraform and AWS services

## Is it enterprise-ready?

The accelerator is in experimental stage and provides a foundation for enterprise use but requires additional work:
- Security assessment and hardening
- Monitoring and alerting setup
- Backup and disaster recovery planning
- Performance testing and optimization
- Governance and operational procedures

## How do I get support?

Support options include:
- Documentation and guides
- GitHub issues and discussions
- AWS Support (for AWS service issues)
- Community forums and resources

## Can I integrate with existing systems?

Yes, integration options include:
- REST API endpoints for external systems
- Event-driven processing with SQS/SNS
- Database integration with DynamoDB
- File system integration with S3
- Custom Lambda functions for specific integrations

## What security features are included?

Security features include:
- IAM roles and policies for least privilege access
- Encryption at rest and in transit
- VPC isolation and security groups
- API authentication and authorization
- Audit logging with CloudTrail
- Implementation of AWS security best practices

## How do I monitor the system?

Monitoring capabilities include:
- CloudWatch metrics and alarms
- Application logs and error tracking
- Performance monitoring and optimization
- Custom dashboards and reports

## Can I use it for batch processing?

Yes, the accelerator supports both real-time and batch processing:
- SQS queues for batch job management
- Step Functions for complex workflows
- Scheduled processing with EventBridge
- Parallel processing for high throughput

---

For more specific questions, see:
- [Deployment FAQs](deployment.md)
- [Troubleshooting FAQs](troubleshooting.md)
