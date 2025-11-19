# Security Guide

This guide covers the security features and best practices implemented in the GenAI IDP Accelerator for Terraform.

## Security Features

### Recent Security Enhancements

Based on the context from the restored README.md, the solution includes recent security improvements:

#### Enhanced IAM Permissions
- **DynamoDB**: Full CRUD operations for tracking and configuration tables
- **SSM Parameter Store**: Secure parameter management with GetParameter, PutParameter, and GetParametersByPath
- **Bedrock Data Automation**: Complete API access including GetDataAutomationProject, ListDataAutomationProjects, GetBlueprint, and GetBlueprintRecommendation
- **S3 Enhanced Permissions**: Full CRUD operations including DeleteObject and GetBucketLocation for comprehensive bucket management

#### Conditional HITL (Human-in-the-Loop) Support
- **Modular HITL Policies**: Separate conditional policies for Human-in-the-Loop functionality
- **Optional BDA Metadata Table**: Configurable access to BDAMetadataTable based on deployment requirements
- **Environment Variable Consistency**: Standardized CONFIGURATION_TABLE_NAME across all Lambda functions

### Core Security Implementation

#### IAM Security Model
- **Least Privilege Access**: IAM policies follow the principle of least privilege with specific resource ARNs
- **Conditional Resource Access**: HITL functionality deployed only when required using Terraform for_each patterns
- **Resource Separation**: Clear separation between core processing permissions and optional HITL permissions

#### Data Protection
- **KMS Encryption**: All data encrypted at rest and in transit
- **VPC Support**: Optional VPC deployment for network isolation
- **Secure Parameter Management**: SSM Parameter Store for sensitive configuration

#### Monitoring & Logging
- **CloudWatch Integration**: Comprehensive logging and monitoring
- **Resource Compliance**: Basic resource compliance monitoring
- **API Call Tracking**: CloudTrail integration for API call auditing

## Configuration Examples

### HITL Configuration
To enable Human-in-the-Loop functionality, configure the BDA metadata table:

```hcl
# Enable HITL functionality by providing BDA metadata table ARN
bda_metadata_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/my-bda-metadata-table"
```

### Basic Security Configuration
```hcl
# terraform.tfvars
# Basic security settings
region = "us-east-1"
prefix = "secure-idp"

# Extended log retention for security monitoring
log_retention_days = 30

# Extended data retention
data_tracking_retention_days = 365

# Tags for resource management
tags = {
  Environment = "production"
  Project     = "genai-idp-accelerator"
  Security    = "enabled"
}
```

## Security Best Practices

### Deployment Security
1. **Review IAM Policies**: Ensure least privilege access before deployment
2. **Enable CloudTrail**: Set up comprehensive API logging
3. **Configure KMS**: Use customer-managed encryption keys where needed
4. **Network Planning**: Consider VPC deployment for sensitive workloads

### Operational Security
1. **Regular Updates**: Keep Lambda runtimes and dependencies updated
2. **Access Reviews**: Regularly review IAM permissions
3. **Log Monitoring**: Monitor CloudWatch logs for security events
4. **Resource Tagging**: Implement consistent security tags

## Troubleshooting Security Issues

### Common Security Issues

#### IAM Permission Errors
```
Error: AccessDeniedException: User is not authorized to perform: bedrock:InvokeModel
```
**Solution**: Ensure the Lambda execution role has the required Bedrock permissions

#### HITL Configuration Issues
```
Error: Access denied to BDA metadata table
```
**Solution**: Ensure `bda_metadata_table_arn` is correctly configured if using HITL functionality

#### KMS Access Denied
```
Error: KMS access denied when accessing encrypted resources
```
**Solution**: Verify KMS key policy includes necessary principals

### Security Validation

#### Pre-Deployment Checks
```bash
# Validate Terraform configuration
terraform validate

# Review planned changes
terraform plan
```

#### Post-Deployment Verification
```bash
# Verify S3 bucket encryption
aws s3api get-bucket-encryption --bucket your-bucket-name

# Check CloudTrail status
aws cloudtrail describe-trails

# Review IAM policies
aws iam list-attached-role-policies --role-name your-lambda-role
```

## Limitations

### Current Limitations
- **Experimental Status**: Solution is in experimental stage
- **No Compliance Certification**: Not certified for specific compliance standards
- **Limited Security Scanning**: Basic security controls implemented
- **Manual Security Review**: Requires manual security assessment for production use

### Recommendations for Production
1. **Security Assessment**: Conduct thorough security assessment
2. **Penetration Testing**: Perform security testing before production deployment
3. **Compliance Review**: Review against your organization's compliance requirements
4. **Monitoring Enhancement**: Implement additional security monitoring as needed

## Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
