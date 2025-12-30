# CloudFormation Service Role for GenAI IDP Accelerator

This directory contains the `IDP-Cloudformation-Service-Role.yaml` CloudFormation template that creates a dedicated IAM Cloudformation service role for CloudFormation to deploy, manage and modify all GenAI IDP Accelerator patterns deployments.

## <span style="color: blue;">Administrator Access and Deployment Options</span>

**Note**: As detailed in [./docs/deployment.md](../docs/deployment.md), administrator access is required to deploy the GenAI IDP Accelerator solution. However, this directory provides an example CloudFormation service role that administrators can provision to allow other users to pass this role to CloudFormation for deploying and maintaining the solution stack without themselves needing administrator permissions.

This approach enables a security model where:
- **Administrators** deploy this service role once with their elevated privileges
- **Developer/DevOps users** can then deploy and manage IDP stacks using this pre-provisioned service role
- **Operational teams** can maintain the solution without requiring ongoing administrator access

## <span style="color: blue;">What This Role Does</span>

The **IDPAcceleratorCloudFormationServiceRole** is a CloudFormation service role that provides the necessary permissions for AWS CloudFormation to deploy, update, and manage GenAI IDP Accelerator stacks across all patterns (Pattern 1: BDA, Pattern 2: Textract+Bedrock, Pattern 3: Textract+UDOP+Bedrock). This role can only be assumed by the CloudFormation service, not by users directly.

### Key Capabilities
- **Full CloudFormation Management**: Create, update, delete IDP stacks - This IAM service role (which CloudFormation assumes) gives necessary privileges to create/update/delete the stack which is helpful in development and sandbox environments. In production environments, admins can further limit these permissions to their discretion (e.g. disabling stack deletion).

- **All Pattern Support**: Works with Pattern 1 (BDA), Pattern 2 (Textract+Bedrock), and Pattern 3 (UDOP)

- **Comprehensive AWS Service Access**: Supports all services required by IDP Accelerator


## <span style="color: blue;">Security Features</span>

### Session Management
- **Administrator Note**: This role also creates an IAM Managed Policy to allow passing the Cloudformation service role.  Administrators must add the inline IAM policy to users wanting to deploy or modify CloudFormation IDP stacks with this service role, allowing them to pass the `IDPAcceleratorCloudFormationServiceRole` role to the CloudFormation principal:

  ```yaml
  PassRolePolicy:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      ManagedPolicyName: IDP-PassRolePolicy
      Description: Policy to allow passing the IDP CloudFormation service role
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - iam:PassRole
            Resource: !GetAtt CloudFormationServiceRole.Arn
  ```

### Access Control
- **Account-Scoped**: Only IAM entities within the same AWS account can assume the role


## <span style="color: blue;">Files in this Directory</span>

- `IDP-Cloudformation-Service-Role.yaml` - CloudFormation service role template 
- `README.md` - This documentation file
- `testing-guide.md` - Testing procedures and validation steps

## <span style="color: blue;">Console Deployment Steps</span>

### Prerequisites
- AWS Administrator access or IAM permissions to create roles and policies

### Step-by-Step Deployment

1. **Navigate to CloudFormation Console**
   - Open the AWS Management Console
   - Go to **CloudFormation** service
   - Select your preferred region

2. **Create New Stack**
   - Click **"Create stack"** → **"With new resources (standard)"**

3. **Specify Template**
   - Select **"Upload a template file"**
   - Click **"Choose file"** and select `IDP-Cloudformation-Service-Role.yaml`
   - Click **"Next"**

4. **Stack Details**
   - **Stack name**: Enter your stack a name
   - **Parameters**: No parameters required
   - Click **"Next"**

5. **Configure Stack Options**
   - **Tags** (optional): Add any desired tags
   - **Permissions**: Leave as default
   - **Stack failure options**: Leave as default
   - Click **"Next"**

6. **Review and Create**
   - Review all settings
   - **Capabilities**: Check **"I acknowledge that AWS CloudFormation might create IAM resources with custom names"**
   - Click **"Submit"**

7. **Monitor Deployment**
   - Wait for stack status to show **"CREATE_COMPLETE"**
   - Check the **Events** tab for any issues

8. **Retrieve Role ARN**
   - Go to the **Outputs** tab
   - Copy the **CloudFormationServiceRoleArn** value for future use

### Post-Deployment
- The role is now ready to be used with `--role-arn` parameter in CloudFormation deployments via CLI or as a "an existing AWS Identity and Access Management (IAM) service role that CloudFormation can assume" from the Permissions-Optional section in the Cloudformation Console. 
- Users will need `iam:PassRole` permission to use this role

## <span style="color: blue;">AWS Service Permissions</span>

The role provides comprehensive access to AWS services required by all IDP patterns:

### Core Infrastructure Services
- **CloudFormation**: `cloudformation:*` - Full stack management
- **IAM**: Complete role and policy management for IDP components
- **Lambda**: `lambda:*` - Function creation and management
- **Step Functions**: `states:*` - State machine orchestration
- **S3**: `s3:*` - Bucket and object management
- **DynamoDB**: `dynamodb:*` - Table and data management
- **SQS**: `sqs:*` - Queue management
- **EventBridge**: `events:*` - Event rule configuration
- **KMS**: `kms:*` - Encryption key management
- **CloudWatch**: `logs:*`, `cloudwatch:*` - Monitoring and logging
- **Secrets Manager**: `secretsmanager:*` - Secure credential storage and retrieval

### AI/ML Services
- **Amazon Bedrock**: `bedrock:*` - All foundation models and features
- **Amazon Textract**: `textract:*` - Document OCR capabilities
- **Amazon SageMaker**: `sagemaker:*` - Model endpoint management
- **AWS Glue**: `glue:*` - Data catalog and ETL
- **OpenSearch Serverless**: `aoss:*` - Vector search capabilities

### Web & API Services
- **Amazon Cognito**: `cognito-idp:*`, `cognito-identity:*` - Authentication
- **AWS AppSync**: `appsync:*` - GraphQL API management
- **CloudFront**: `cloudfront:*` - Content delivery
- **AWS WAF**: `wafv2:*` - Web application firewall
- **SNS**: `sns:*` - Notification services
- **Systems Manager**: `ssm:*` - Parameter management
- **CodeBuild**: `codebuild:*` - Build automation

### Network & Compute
- **EC2**: Limited VPC, subnet, and security group management
- **Application Auto Scaling**: `application-autoscaling:*`
- **EventBridge Scheduler**: `scheduler:*`

### Additional Permissions
- **STS**: `sts:AssumeRole` for service integrations

## <span style="color: blue;">Security Considerations</span>

### Regional Restrictions
- **Deployment Region**: Role assumption restricted to deployment region
- **Compliance**: Helps meet data residency requirements

### Session Security
- **Account Isolation**: Cannot be assumed cross-account with the current trust policy

### Permission Scope
- **Broad Service Access**: Full service permissions for comprehensive IDP deployment services
- **No Resource Restrictions**: Allows flexibility but requires careful usage
- **Service Trust**: CloudFormation service can assume role for stack operations
- **Compliance Note**: Organizations may need to refine and make more granular the service action permissions based on their specific security compliance guidelines and least privilege requirements

## <span style="color: blue;">Troubleshooting</span>

### Common Issues

1. **Access Denied when Using Role**:
   - Verify your user/role has `iam:PassRole` permission for this specific role ARN

   - Ensure the role exists and is in the same account
   - Remember: Users cannot assume this role directly - only CloudFormation service can

2. **Region Restriction Errors**:
   - Role should be deployed in same region where IDP stacks are deployed

3. **Session Timeout**:
   - Re-assume the role to get fresh credentials

4. **CloudFormation Deployment Failures**:
   - If using the CLI, ensure you're using `CAPABILITY_IAM` and `CAPABILITY_NAMED_IAM`
   - Check CloudWatch logs for specific service errors



## <span style="color: blue;">Best Practices</span>

1. **Regular Auditing**: Periodically review who has access to assume this role
2. **Least Privilege**: Only grant this role to users who need to manage IDP stacks
3. **Session Management**: Use temporary credentials and limit session duration
4. **Monitoring**: Enable CloudTrail logging for role assumption and usage
5. **Rotation**: Regularly review and update the role permissions as needed
