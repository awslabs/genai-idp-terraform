# Troubleshooting Questions

Common issues and solutions when using the GenAI IDP Accelerator.

## Permission Errors

### "AccessDenied" when deploying with Terraform

**Symptoms**:
```
Error: AccessDenied: User is not authorized to perform action
```

**Solutions**:
1. **Check IAM permissions**:
   ```bash
   aws sts get-caller-identity
   aws iam get-user
   ```

2. **Verify required permissions**:
   - IAM: Create/manage roles and policies
   - Lambda: Create/update functions
   - S3: Create/manage buckets
   - DynamoDB: Create/manage tables
   - API Gateway: Create/manage APIs

3. **Use administrator access temporarily**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "*",
         "Resource": "*"
       }
     ]
   }
   ```

### "User is not authorized to invoke Bedrock model"

**Symptoms**:
```
Error: AccessDeniedException: Your account is not authorized to invoke this model
```

**Solutions**:
1. **Request model access**:
   - Go to Amazon Bedrock console
   - Navigate to "Model access"
   - Request access for required models

2. **Check region availability**:
   - Bedrock models aren't available in all regions
   - Use supported regions like `us-east-1`, `us-west-2`

3. **Verify model ARN**:
   ```hcl
   # Correct model ARN format
   model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
   ```

## Resource Limits

### "LimitExceededException" errors

**Symptoms**:
```
Error: LimitExceededException: Account has reached the maximum number of functions
```

**Solutions**:
1. **Check service quotas**:
   ```bash
   aws service-quotas get-service-quota \
     --service-code lambda \
     --quota-code L-B99A9384
   ```

2. **Request quota increases**:
   - Go to AWS Service Quotas console
   - Find the relevant service and quota
   - Submit increase request

3. **Clean up unused resources**:
   ```bash
   # List unused Lambda functions
   aws lambda list-functions --query 'Functions[?LastModified<`2024-01-01`]'
   ```

### "ThrottlingException" from AWS services

**Symptoms**:
```
Error: ThrottlingException: Rate exceeded
```

**Solutions**:
1. **Implement exponential backoff**:
   ```python
   import time
   import random
   
   def retry_with_backoff(func, max_retries=3):
       for attempt in range(max_retries):
           try:
               return func()
           except ThrottlingException:
               if attempt == max_retries - 1:
                   raise
               wait_time = (2 ** attempt) + random.uniform(0, 1)
               time.sleep(wait_time)
   ```

2. **Reduce request rate**:
   - Add delays between API calls
   - Use batch operations where possible
   - Implement queue-based processing

## Deployment Failures

### Terraform state lock conflicts

**Symptoms**:
```
Error: Error acquiring the state lock
```

**Solutions**:
1. **Wait for lock release**:
   - Another Terraform operation may be running
   - Wait 10-15 minutes for automatic release

2. **Check lock status**:
   ```bash
   aws dynamodb get-item \
     --table-name terraform-locks \
     --key '{"LockID":{"S":"your-state-file"}}'
   ```

3. **Force unlock** (use carefully):
   ```bash
   terraform force-unlock LOCK_ID
   ```

### "Resource already exists" errors

**Symptoms**:
```
Error: ResourceAlreadyExistsException: Resource already exists
```

**Solutions**:
1. **Import existing resource**:
   ```bash
   terraform import aws_s3_bucket.documents existing-bucket-name
   ```

2. **Use different resource names**:
   ```hcl
   resource "aws_s3_bucket" "documents" {
     bucket = "${var.environment}-idp-documents-${random_id.suffix.hex}"
   }
   ```

3. **Check for naming conflicts**:
   - S3 bucket names must be globally unique
   - Lambda function names must be unique per region/account

## Runtime Errors

### Lambda function timeouts

**Symptoms**:
```
Task timed out after 15.00 seconds
```

**Solutions**:
1. **Increase timeout**:
   ```hcl
   resource "aws_lambda_function" "processor" {
     timeout = 300  # 5 minutes
   }
   ```

2. **Optimize function performance**:
   ```python
   # Initialize clients outside handler
   import boto3
   
   s3_client = boto3.client('s3')
   textract_client = boto3.client('textract')
   
   def lambda_handler(event, context):
       # Use pre-initialized clients
       pass
   ```

3. **Increase memory allocation**:
   ```hcl
   resource "aws_lambda_function" "processor" {
     memory_size = 1024  # More memory = more CPU
   }
   ```

### "Document format not supported" errors

**Symptoms**:
```
Error: InvalidParameterException: Document format not supported
```

**Solutions**:
1. **Check supported formats**:
   - PDF, PNG, JPEG, TIFF only
   - Maximum file size: 10MB (sync), 500MB (async)

2. **Validate file before processing**:
   ```python
   import os
   
   SUPPORTED_EXTENSIONS = {'.pdf', '.png', '.jpg', '.jpeg', '.tiff'}
   
   def validate_document(file_name):
       ext = os.path.splitext(file_name)[1].lower()
       return ext in SUPPORTED_EXTENSIONS
   ```

3. **Convert unsupported formats**:
   - Use Lambda layers with image processing libraries
   - Convert to supported format before processing

## Performance Issues

### Slow document processing

**Symptoms**:
- Long processing times
- Frequent timeouts

**Solutions**:
1. **Optimize Lambda configuration**:
   ```hcl
   resource "aws_lambda_function" "processor" {
     memory_size = 2048  # Higher memory for better performance
     timeout     = 900   # 15 minutes max
   }
   ```

2. **Implement parallel processing**:
   ```python
   import concurrent.futures
   
   def process_documents_parallel(documents):
       with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
           futures = [executor.submit(process_document, doc) for doc in documents]
           results = [future.result() for future in futures]
       return results
   ```

3. **Use asynchronous processing**:
   - Use Textract async APIs for large documents
   - Implement Step Functions for complex workflows
   - Use SQS for queue-based processing

### High memory usage

**Symptoms**:
```
Runtime.OutOfMemoryError: JavaScript heap out of memory
```

**Solutions**:
1. **Increase Lambda memory**:
   ```hcl
   memory_size = 3008  # Maximum available
   ```

2. **Optimize memory usage**:
   ```python
   # Process documents in chunks
   def process_large_document(document_text):
       chunk_size = 10000  # characters
       chunks = [document_text[i:i+chunk_size] 
                for i in range(0, len(document_text), chunk_size)]
       
       results = []
       for chunk in chunks:
           result = process_chunk(chunk)
           results.append(result)
       
       return combine_results(results)
   ```

## Network Issues

### VPC connectivity problems

**Symptoms**:
- Lambda functions can't reach AWS services
- Timeout errors when calling APIs

**Solutions**:
1. **Check VPC configuration**:
   ```hcl
   # Ensure NAT Gateway for private subnets
   resource "aws_nat_gateway" "main" {
     allocation_id = aws_eip.nat.id
     subnet_id     = aws_subnet.public[0].id
   }
   ```

2. **Use VPC endpoints**:
   ```hcl
   resource "aws_vpc_endpoint" "s3" {
     vpc_id       = aws_vpc.main.id
     service_name = "com.amazonaws.${var.region}.s3"
   }
   ```

3. **Check security groups**:
   ```hcl
   resource "aws_security_group" "lambda" {
     egress {
       from_port   = 443
       to_port     = 443
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }
   }
   ```

## Data Issues

### Inconsistent processing results

**Symptoms**:
- Different results for same document
- Missing or incorrect extracted data

**Solutions**:
1. **Improve prompt consistency**:
   ```python
   CONSISTENT_PROMPT = """
   Extract the following information from this document:
   1. Document type
   2. Date (format: YYYY-MM-DD)
   3. Amount (format: $X.XX)
   4. Parties involved
   
   Return as JSON with these exact keys: type, date, amount, parties
   """
   ```

2. **Implement validation**:
   ```python
   def validate_extraction_result(result):
       required_fields = ['type', 'date', 'amount', 'parties']
       return all(field in result for field in required_fields)
   ```

3. **Add error handling**:
   ```python
   def process_with_fallback(document):
       try:
           result = primary_processing(document)
           if validate_result(result):
               return result
       except Exception as e:
           logger.warning(f"Primary processing failed: {e}")
       
       # Fallback to simpler processing
       return fallback_processing(document)
   ```

## Monitoring and Debugging

### How to debug Lambda functions

1. **Enable detailed logging**:
   ```python
   import logging
   
   logger = logging.getLogger()
   logger.setLevel(logging.DEBUG)
   
   def lambda_handler(event, context):
       logger.debug(f"Received event: {event}")
       # ... processing logic
       logger.debug(f"Processing result: {result}")
   ```

2. **Use X-Ray tracing**:
   ```hcl
   resource "aws_lambda_function" "processor" {
     tracing_config {
       mode = "Active"
     }
   }
   ```

3. **Monitor CloudWatch metrics**:
   - Duration, Errors, Throttles
   - Memory utilization
   - Concurrent executions

### How to trace API requests

1. **Enable API Gateway logging**:
   ```hcl
   resource "aws_api_gateway_stage" "main" {
     xray_tracing_enabled = true
     
     access_log_settings {
       destination_arn = aws_cloudwatch_log_group.api_gateway.arn
       format = jsonencode({
         requestId      = "$context.requestId"
         ip            = "$context.identity.sourceIp"
         caller        = "$context.identity.caller"
         user          = "$context.identity.user"
         requestTime   = "$context.requestTime"
         httpMethod    = "$context.httpMethod"
         resourcePath  = "$context.resourcePath"
         status        = "$context.status"
         protocol      = "$context.protocol"
         responseLength = "$context.responseLength"
       })
     }
   }
   ```

2. **Use correlation IDs**:
   ```python
   import uuid
   
   def lambda_handler(event, context):
       correlation_id = str(uuid.uuid4())
       logger.info(f"Processing request {correlation_id}")
       
       # Pass correlation ID through processing chain
       result = process_document(event, correlation_id)
       
       return {
           'statusCode': 200,
           'headers': {'X-Correlation-ID': correlation_id},
           'body': json.dumps(result)
       }
   ```

---

For more troubleshooting help, see:
- [Deployment Troubleshooting](../deployment-guides/troubleshooting.md)
- [Monitoring Guide](../deployment-guides/monitoring.md)
- [Best Practices](../deployment-guides/best-practices.md)
