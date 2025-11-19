# GenAI IDP Accelerator - Active Context

## Current Task Focus

**Customer Question**: "We are encountering difficulties deploying your IDP stack outside of a sandbox environment due to an organization-wide Service Control Policy (SCP). This policy mandates the attachment of a Permissions Boundary to any new role. Could you please inform us if it is possible to update the CloudFormation template to include a parameterized Permissions Boundary? Without this update, our ability to transition the code to production will be significantly impeded."

**Task Status**: Implementation phase - Need to add Permissions Boundary parameter support to CloudFormation templates

## Problem Analysis

### Current Situation
- IDP stack creates numerous IAM roles across main template and pattern templates
- Organization has SCP requiring Permissions Boundary on all new IAM roles
- Current templates don't support Permissions Boundary configuration
- Blocking production deployment

### Affected Templates
- **Main Template**: `template.yaml` - ~15 IAM roles
- **Pattern 1**: `patterns/pattern-1/template.yaml` - ~8 IAM roles  
- **Pattern 2**: `patterns/pattern-2/template.yaml` - ~6 roles
- **Pattern 3**: `patterns/pattern-3/template.yaml` - ~5 roles
- **Options**: `options/bda-lending-project/template.yaml`, `options/bedrockkb/template.yaml`

## Solution Design

### Approach: Parameterized Permissions Boundary
1. **Add optional parameter** to main template for Permissions Boundary ARN
2. **Conditionally apply boundary** to all IAM roles when provided
3. **Maintain backward compatibility** for deployments without boundaries
4. **Cascade parameter** to all nested pattern stacks

### Implementation Plan

#### Step 1: Main Template Updates (`template.yaml`)
- Add `PermissionsBoundaryArn` parameter
- Add `HasPermissionsBoundary` condition
- Update all IAM role resources with conditional boundary
- Pass parameter to nested stacks
- Update CloudFormation interface metadata

#### Step 2: Pattern Template Updates
- Add parameter to each pattern template
- Update all IAM roles in patterns
- Maintain consistency across all patterns

#### Step 3: Options Template Updates
- Update BDA lending project template
- Update Bedrock KB template

### Key Implementation Details

**Parameter Definition:**
```yaml
PermissionsBoundaryArn:
  Type: String
  Default: ""
  Description: (Optional) ARN of IAM Permissions Boundary policy
  AllowedPattern: "^(|arn:aws:iam::[0-9]{12}:policy/.+)$"
```

**Condition:**
```yaml
HasPermissionsBoundary: !Not [!Equals [!Ref PermissionsBoundaryArn, ""]]
```

**Role Update Pattern:**
```yaml
SomeRole:
  Type: AWS::IAM::Role
  Properties:
    # existing properties...
    PermissionsBoundary: !If [HasPermissionsBoundary, !Ref PermissionsBoundaryArn, !Ref AWS::NoValue]
```

## Benefits
- **SCP Compliance**: Satisfies organizational requirements
- **Backward Compatible**: Existing deployments unaffected
- **Flexible**: Works with any Permissions Boundary policy
- **Comprehensive**: Covers all IAM roles across all components

## Next Steps
1. Implement main template changes
2. Update all pattern templates
3. Update options templates
4. Test deployment scenarios
5. Document usage examples
