# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when deploying the GenAI IDP Accelerator with Terraform.

## Common Deployment Issues

### Permission Errors

**Symptom**: Access denied errors during Terraform deployment

```
Error: AccessDenied: User is not authorized to perform action
```

**Solutions**:

1. **Check IAM Permissions**: Ensure your AWS credentials have the required permissions
2. **Verify Service Roles**: Check that service-linked roles exist for required services
3. **Review Resource Policies**: Ensure bucket policies and resource policies allow access

```bash
# Check current AWS identity
aws sts get-caller-identity

# Verify required permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USERNAME \
  --action-names s3:CreateBucket,lambda:CreateFunction
```

### Resource Limits

**Symptom**: Service quotas exceeded

```
Error: LimitExceededException: Account has reached the maximum number of functions
```

**Solutions**:

1. **Check Service Quotas**: Review current usage in AWS Console
2. **Request Quota Increases**: Submit requests through AWS Support
3. **Clean Up Unused Resources**: Remove old deployments

```bash
# Check Lambda function count
aws lambda list-functions --query 'Functions[].FunctionName' --output table

# Check S3 bucket count
aws s3api list-buckets --query 'Buckets[].Name' --output table
```

### Deployment Failures

**Symptom**: Terraform apply fails with resource creation errors

**Common Causes**:

- **Network Issues**: VPC/subnet configuration problems
- **Dependency Issues**: Resources created in wrong order
- **Configuration Errors**: Invalid parameter values

**Debugging Steps**:

1. **Enable Detailed Logging**:

```bash
export TF_LOG=DEBUG
terraform apply
```

2. **Check Resource Dependencies**:

```bash
terraform graph | dot -Tpng > dependency-graph.png
```

3. **Validate Configuration**:

```bash
terraform validate
terraform plan -detailed-exitcode
```

## Service-Specific Issues

### Amazon Bedrock

**Issue**: Model access denied

```
Error: AccessDeniedException: Your account is not authorized to invoke this model
```

**Solution**: Request model access in Bedrock console

1. Go to Amazon Bedrock console
2. Navigate to Model access
3. Request access for required models (Claude, Titan, etc.)

### Amazon Textract

**Issue**: Document processing failures

```
Error: InvalidParameterException: Document format not supported
```

**Solutions**:

- Verify document format (PDF, PNG, JPEG, TIFF)
- Check document size limits (10MB for synchronous, 500MB for asynchronous)
- Ensure proper S3 permissions for document access

### Lambda Functions

**Issue**: Function timeout or memory errors

```
Error: Task timed out after 15.00 seconds
```

**Solutions**:

1. **Increase Timeout**:

```hcl
resource "aws_lambda_function" "processor" {
  timeout = 300  # 5 minutes
  memory_size = 1024  # 1GB
}
```

2. **Optimize Code**: Review function logic for efficiency
3. **Use Step Functions**: For long-running processes

## State Management Issues

### State Lock Conflicts

**Issue**: Terraform state is locked

```
Error: Error acquiring the state lock
```

**Solutions**:

1. **Wait for Lock Release**: Another operation may be in progress
2. **Force Unlock** (use carefully):

```bash
terraform force-unlock LOCK_ID
```

3. **Check DynamoDB Table**: Verify state lock table exists and is accessible

### State Corruption

**Issue**: State file corruption or inconsistency

**Solutions**:

1. **Import Existing Resources**:

```bash
terraform import aws_s3_bucket.example bucket-name
```

2. **Refresh State**:

```bash
terraform refresh
```

3. **Restore from Backup**: Use versioned S3 backend

## Network and Security Issues

### VPC Configuration

**Issue**: Resources cannot communicate

**Checklist**:

- [ ] Subnets in correct AZs
- [ ] Route tables configured
- [ ] Security groups allow required traffic
- [ ] NACLs not blocking traffic
- [ ] NAT Gateway for private subnets

### Security Group Rules

**Issue**: Connection timeouts

**Debug Steps**:

1. **Check Security Group Rules**:

```bash
aws ec2 describe-security-groups --group-ids sg-12345678
```

2. **Test Connectivity**:

```bash
# From EC2 instance
telnet target-host 443
```

3. **Review VPC Flow Logs**: Check for rejected connections

## Performance Issues

### Slow Processing

**Symptoms**:

- Long document processing times
- Lambda function timeouts
- High costs

**Optimization Strategies**:

1. **Parallel Processing**: Use Step Functions for concurrent execution
2. **Batch Processing**: Process multiple documents together
3. **Caching**: Store processed results to avoid reprocessing
4. **Right-sizing**: Adjust Lambda memory and timeout settings

### Cost Optimization

**High Cost Indicators**:

- Excessive Lambda invocations
- Large S3 storage costs
- High Bedrock API usage

**Cost Reduction Tips**:

1. **Implement Caching**: Avoid duplicate processing
2. **Use Lifecycle Policies**: Archive old documents
3. **Monitor Usage**: Set up billing alerts
4. **Optimize Models**: Use smaller models when appropriate

## Monitoring and Debugging

### CloudWatch Logs

**Key Log Groups to Monitor**:

- `/aws/lambda/idp-processor-*`
- `/aws/stepfunctions/idp-workflow`
- `/aws/apigateway/idp-api`

**Useful Log Queries**:

```sql
-- Find errors in last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### X-Ray Tracing

**Enable Tracing**:

```hcl
resource "aws_lambda_function" "processor" {
  tracing_config {
    mode = "Active"
  }
}
```

**Analyze Traces**: Look for bottlenecks and errors in service map

## Getting Help

### AWS Support

For critical issues:

1. **Create Support Case**: Include error messages and logs
2. **Provide Context**: Terraform configuration and deployment details
3. **Include Diagnostics**: CloudWatch logs and X-Ray traces

### Community Resources

- **AWS Forums**: Search for similar issues
- **GitHub Issues**: Check project repository for known issues
- **Documentation**: Review AWS service documentation

### Emergency Procedures

**Critical System Issues**:

1. **Rollback**: Use previous Terraform state
2. **Scale Down**: Reduce resource usage
3. **Enable Monitoring**: Increase logging verbosity
4. **Contact Support**: Open high-priority support case

## Prevention Best Practices

### Pre-Deployment Checks

- [ ] Run `terraform plan` and review changes
- [ ] Test in development environment first
- [ ] Verify IAM permissions
- [ ] Check service quotas
- [ ] Review security configurations

### Monitoring Setup

- [ ] CloudWatch alarms for key metrics
- [ ] Log aggregation and analysis
- [ ] Cost monitoring and alerts
- [ ] Performance baseline establishment

### Documentation

- [ ] Document custom configurations
- [ ] Maintain runbooks for common issues
- [ ] Keep architecture diagrams updated
- [ ] Record lessons learned

---

For additional help, see our [FAQ section](../faqs/index.md) or [contact support](../contributing/index.md#getting-help).
