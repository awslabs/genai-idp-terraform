<!--
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
-->

# Security Policy

## Reporting Security Issues

The GenAI IDP Accelerator for Terraform team and community take security bugs seriously. We appreciate your efforts to responsibly disclose your findings, and will make every effort to acknowledge your contributions.

To report a security issue, please use the GitHub Security Advisory ["Report a Vulnerability"](https://github.com/aws-samples/genaiic-idp-accelerator-terraform/security/advisories/new) tab.

The GenAI IDP Accelerator for Terraform team will send a response indicating the next steps in handling your report. After the initial reply to your report, the security team will keep you informed of the progress towards a fix and full announcement, and may ask for additional information or guidance.

## Security Best Practices

When using the GenAI IDP Accelerator for Terraform, please follow these security best practices:

### Infrastructure Security

1. **IAM Least Privilege**: Use minimal IAM permissions required for each component
2. **Encryption**: Enable encryption at rest and in transit for all data
3. **Network Security**: Use VPC endpoints and security groups to restrict network access
4. **Secrets Management**: Use AWS Secrets Manager or Parameter Store for sensitive data
5. **KMS Keys**: Use customer-managed KMS keys for encryption when possible

### Deployment Security

1. **Terraform State**: Secure your Terraform state files with encryption and access controls
2. **AWS Credentials**: Use IAM roles instead of long-term access keys when possible
3. **Resource Tagging**: Tag all resources for proper governance and cost tracking
4. **Monitoring**: Enable CloudTrail and CloudWatch for audit logging and monitoring

### Application Security

1. **Input Validation**: Validate all inputs to Lambda functions and APIs
2. **Output Sanitization**: Sanitize outputs to prevent injection attacks
3. **Authentication**: Use proper authentication mechanisms for web interfaces
4. **Authorization**: Implement proper authorization controls for API access

### Data Security

1. **Data Classification**: Classify and handle data according to sensitivity levels
2. **Data Retention**: Implement appropriate data retention and deletion policies
3. **Access Logging**: Log all data access for audit purposes
4. **Backup Security**: Secure backups with encryption and access controls

### Model Security

1. **Model Access**: Restrict access to AI/ML models based on business needs
2. **Input Filtering**: Implement input filtering to prevent prompt injection
3. **Output Monitoring**: Monitor model outputs for inappropriate content
4. **Guardrails**: Use Amazon Bedrock Guardrails when available

## Security Features

The GenAI IDP Accelerator for Terraform includes several built-in security features:

### Encryption
- **S3 Encryption**: All S3 buckets use server-side encryption
- **DynamoDB Encryption**: All DynamoDB tables use encryption at rest
- **Lambda Environment Variables**: Encrypted using KMS
- **CloudWatch Logs**: Encrypted using KMS

### Access Control
- **IAM Roles**: Least privilege IAM roles for all components
- **Resource Policies**: Restrictive resource policies for S3 and other services
- **VPC Support**: Optional VPC deployment for network isolation
- **API Authentication**: Secure authentication for GraphQL APIs

### Monitoring
- **CloudTrail Integration**: All API calls are logged
- **CloudWatch Monitoring**: Comprehensive monitoring and alerting
- **Access Logging**: S3 and CloudFront access logging enabled
- **Error Tracking**: Detailed error logging and tracking

## Vulnerability Management

### Dependency Management
- Regularly update Terraform providers and modules
- Monitor for security advisories affecting dependencies
- Use tools like `terraform validate` and security scanners

### Infrastructure Scanning
- Use tools like Checkov or tfsec to scan Terraform code
- Implement security scanning in CI/CD pipelines
- Regular security assessments of deployed infrastructure

### Incident Response
1. **Detection**: Monitor for security incidents using CloudWatch and CloudTrail
2. **Response**: Follow incident response procedures for security events
3. **Recovery**: Implement recovery procedures to restore normal operations
4. **Lessons Learned**: Document and learn from security incidents

## Compliance

The GenAI IDP Accelerator for Terraform is designed to support compliance with various frameworks:

- **AWS Well-Architected Framework**: Security pillar best practices
- **SOC 2**: Security controls for service organizations
- **ISO 27001**: Information security management standards
- **GDPR**: Data protection and privacy requirements
- **HIPAA**: Healthcare data protection (when properly configured)

## Security Updates

Security updates will be communicated through:
- GitHub Security Advisories
- Release notes and changelogs
- Documentation updates
- Community notifications

## Contact

For security-related questions or concerns, please contact:
- GitHub Security Advisories (preferred)
- AWS Security Team: aws-security@amazon.com
- Project maintainers through GitHub issues (for non-sensitive matters)

## Acknowledgments

We thank the security research community for helping to keep the GenAI IDP Accelerator for Terraform and our users safe. If you believe you have found a security vulnerability, please report it responsibly as described above.
