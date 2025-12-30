# Testing Guide for IDP CloudFormation Service Role

This guide provides testing procedures to validate the `IDP-Cloudformation-Service-Role.yaml` CloudFormation service role for GenAI IDP Accelerator management.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Console Deployment Steps](#console-deployment-steps)
- [Test Scenario: Pattern Migration](#test-scenario-pattern-migration)

## Prerequisites

**IMPORTANT**: The following steps require a user or role with permissions to deploy IAM roles.

## Console Deployment Steps

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

## Test Scenario: Pattern Migration

**Objective**: Test the CloudFormation service role's ability to deploy and update IDP stacks.

**Prerequisites**: The iam:PassRole policy created by the role template must be attached to the user or role performing IDP stack changes.

## Console Stack Update with Service Role

### Step 1: Navigate to CloudFormation Console
1. **Open AWS Management Console**
2. **Go to CloudFormation service**
3. **Select your region** (where IDP stack is deployed)

### Step 2: Make a Direct Update
1. **Click "Update stack" button**
2. **Select "Make a direct update"**
3. **Select "Use existing template"**
4. **Click "Next"**

### Step 3: Modify Parameters
1. **Locate the IDPPattern parameter**
2. **Change the value** (e.g., from Pattern 2 to Pattern 1)
3. **Leave other parameters unchanged**
4. **Click "Next"**

### Step 4: Configure Stack Options with Service Role
1. **Scroll down to "Permissions-optional" section**
2. **For IAM role, choose IDPAcceleratorCloudFormationServiceRole** from dropdown
3. **Leave other options as default**
4. **In the Capabilities section, check both acknowledgements**
5. **Click "Next"**

### Step 5: Review and Execute
1. **Review parameter changes**
2. **Verify service role is selected** in Permissions section
3. **Check "I acknowledge that AWS CloudFormation might create IAM resources"**
4. **Click "Submit"**

### Step 6: Monitor Update Progress
1. **Watch "Events" tab** for real-time progress
2. **Monitor "Resources" tab** for resource changes
3. **Wait for status** to show `UPDATE_COMPLETE`

## Expected Results

### Successful Pattern Migration
- **Stack Update**: CloudFormation update completes without errors
- **Resource Changes**: Pattern 2 nested stack removed, Pattern 1 (BDA) nested stack created
- **Parameter Update**: IDPPattern parameter reflects new value
- **Functional Resources**: New BDA resources are created and operational

### Role Permission Validation
- **Assumption Success**: Non-administrator user or role can assume the CloudFormation service role
- **CloudFormation Access**: Full stack management capabilities
- **Service Access**: All required AWS services accessible

### Security Validation
- **Account Isolation**: Role cannot be assumed cross-account

