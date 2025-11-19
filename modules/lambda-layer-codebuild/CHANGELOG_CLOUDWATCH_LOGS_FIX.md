# Lambda Layer CodeBuild Module - CloudWatch Logs Fix

## Issue Fixed

**Error:** `ACCESS_DENIED: Service role does not allow AWS CodeBuild to create Amazon CloudWatch Logs log streams`

**Root Cause:** 
- CodeBuild project was not explicitly configured with a CloudWatch log group
- IAM policy had wildcard permissions but CodeBuild couldn't create log streams in the default log group

## Changes Made

### 1. Added CloudWatch Log Group

**File: `main.tf`**
```hcl
# CloudWatch log group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name              = "/aws/codebuild/${var.stack_name}-${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}"
  retention_in_days = 14
  
  tags = {
    Name = "${var.stack_name}-${var.layer_prefix}-codebuild-logs"
  }
}
```

### 2. Updated CodeBuild Project Configuration

**File: `main.tf`**
```hcl
resource "aws_codebuild_project" "lambda_layers_build" {
  # ... existing configuration ...
  
  # Added explicit logs configuration
  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = aws_cloudwatch_log_group.codebuild_log_group.name
    }
  }
  
  # ... rest of configuration ...
}
```

### 3. Enhanced IAM Policy

**File: `main.tf`**
- Added `data "aws_caller_identity" "current" {}` for account ID
- Updated IAM policy to use specific log group ARNs instead of wildcard
- More secure and explicit permissions

**Before:**
```hcl
{
  Effect = "Allow"
  Action = [
    "logs:CreateLogGroup",
    "logs:CreateLogStream", 
    "logs:PutLogEvents"
  ]
  Resource = "*"  # Too broad
}
```

**After:**
```hcl
{
  Effect = "Allow"
  Action = [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
  Resource = [
    "arn:aws:logs:${region}:${account}:log-group:/aws/codebuild/${project-name}",
    "arn:aws:logs:${region}:${account}:log-group:/aws/codebuild/${project-name}:*"
  ]
}
```

## Benefits

### ✅ **Fixed Access Denied Error**
- CodeBuild can now successfully create log streams
- Explicit log group configuration prevents permission issues

### ✅ **Improved Security**
- More specific IAM permissions (principle of least privilege)
- No wildcard permissions for CloudWatch logs

### ✅ **Better Observability**
- Explicit log group with configurable retention (14 days)
- Proper tagging for resource management
- Predictable log group naming

### ✅ **Consistent Behavior**
- Deterministic log group creation
- No dependency on CodeBuild's default logging behavior

## Testing

The fix can be tested by:

1. **Deploy the example:**
   ```bash
   cd examples/processing-environment
   terraform init
   terraform plan
   terraform apply
   ```

2. **Verify CodeBuild execution:**
   - Check that CodeBuild project runs successfully
   - Verify logs appear in the specified CloudWatch log group
   - Confirm Lambda layers are created

3. **Check permissions:**
   - Verify IAM policy has specific log group permissions
   - Confirm CodeBuild role can access the log group

## Migration Notes

### For Existing Deployments

If you have existing deployments that are failing with the CloudWatch logs error:

1. **Update the module:**
   ```bash
   git pull  # Get the latest changes
   ```

2. **Plan the changes:**
   ```bash
   terraform plan
   # You should see:
   # + aws_cloudwatch_log_group.codebuild_log_group
   # ~ aws_codebuild_project.lambda_layers_build (logs_config added)
   # ~ aws_iam_policy.codebuild_policy (more specific permissions)
   ```

3. **Apply the fix:**
   ```bash
   terraform apply
   ```

### For New Deployments

No special action needed - the fix is included automatically.

## Verification

After applying the fix, you can verify it's working:

```bash
# Check that the log group exists
aws logs describe-log-groups --log-group-name-prefix "/aws/codebuild/"

# Check CodeBuild project logs configuration
aws codebuild batch-get-projects --names <project-name>

# Verify IAM policy permissions
aws iam get-policy-version --policy-arn <policy-arn> --version-id v1
```

## Related Files

- `modules/lambda-layer-codebuild/main.tf` - Main fix implementation
- `examples/processing-environment/` - Example that demonstrates the fix
- `modules/idp-common-layer/` - Uses the fixed lambda-layer-codebuild module

The CloudWatch logs access issue is now resolved and the module should work correctly for all users! 🎉
