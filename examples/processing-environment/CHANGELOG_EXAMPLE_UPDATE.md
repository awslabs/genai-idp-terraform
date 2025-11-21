# Processing Environment Example - IDP Common Layer Integration

## Changes Made

### 1. Added IDP Common Layer Module

**File: `main.tf`**

- ✅ Added `module "idp_common_layer"` before the processing environment
- ✅ Configured layer with customizable extras
- ✅ Updated processing environment to use `idp_common_layer_arn = module.idp_common_layer.layer_arn`
- ✅ Updated module documentation to reflect the new architecture

### 2. Added New Variables

**File: `variables.tf`**

- ✅ `idp_common_layer_extras`: Configure which dependencies to include (default: `["appsync", "evaluation"]`)
- ✅ `force_layer_rebuild`: Force rebuild during development (default: `false`)
- ✅ `layer_build_wait_time`: Timeout for layer build (default: `600` seconds)

### 3. Enhanced Outputs

**File: `outputs.tf`**

- ✅ `idp_common_layer_arn`: ARN of the created layer for reuse
- ✅ `lambda_functions`: Detailed information about created Lambda functions

### 4. Updated Configuration Examples

**File: `terraform.tfvars.example`**

- ✅ Added IDP common layer configuration examples
- ✅ Documented available options and defaults
- ✅ Included comments explaining each option

### 5. Comprehensive Documentation Update

**File: `README.md`**

- ✅ Added "IDP Common Layer Integration" section
- ✅ Documented which functions use the layer and why
- ✅ Added "Available IDP Common Layer Extras" section
- ✅ Updated architecture description
- ✅ Enhanced customization examples
- ✅ Added notes about layer build times and behavior

### 6. Added Verification Script

**File: `verify_example.sh`**

- ✅ Comprehensive verification of all changes
- ✅ Checks module integration, variables, outputs, and documentation
- ✅ Provides usage guidance

## Architecture Changes

### Before (Internal Layer)

```
examples/processing-environment/
└── main.tf
    └── module "processing_environment"
        └── Creates internal IDP common layer
```

### After (External Layer)

```
examples/processing-environment/
└── main.tf
    ├── module "idp_common_layer"      # Created first
    └── module "processing_environment"
        └── Uses external layer ARN
```

## Benefits Demonstrated

### ✅ **Clear Separation of Concerns**

- Layer creation is explicit and visible
- Processing environment focuses on core infrastructure
- Easy to understand the dependency relationship

### ✅ **Reusability Pattern**

- Shows how to create a layer once and use it multiple times
- Layer ARN is exposed for use in other Lambda functions
- Demonstrates best practices for layer sharing

### ✅ **Flexible Configuration**

- Users can customize layer extras based on their needs
- Development-friendly options (force rebuild, custom timeouts)
- Sensible defaults

### ✅ **Complete Example**

- End-to-end working example
- Proper resource dependencies
- Real-world configuration options

## Usage Patterns Demonstrated

### 1. Basic Usage

```hcl
# Default configuration - suitable for most use cases
module "idp_common_layer" {
  source = "../../modules/idp-common-layer"
  stack_name = "${var.prefix}-processing-env-${random_string.suffix.result}"
  idp_common_extras = ["appsync", "evaluation"]
}
```

### 2. Development Usage

```hcl
# Development configuration with faster rebuilds
idp_common_layer_extras = ["appsync", "evaluation", "ocr"]
force_layer_rebuild = true
layer_build_wait_time = 900
```

### 3. Full Feature Configuration

```hcl
# Configuration with all features
idp_common_layer_extras = ["all"]
force_layer_rebuild = false
layer_build_wait_time = 600
```

### 4. Layer Reuse

```hcl
# Using the same layer in custom functions
resource "aws_lambda_function" "custom_processor" {
  # ... configuration ...
  layers = [module.idp_common_layer.layer_arn]
}
```

## Function Layer Assignments

The example demonstrates the hardcoded layer assignments:

| Function | Layer Assignment | Reasoning |
|----------|------------------|-----------|
| `queue_sender` | ✅ Gets IDP common layer | Uses `idp_common[appsync]` |
| `workflow_tracker` | ✅ Gets IDP common layer | Uses `idp_common[appsync]` |
| `lookup_function` | ❌ No IDP common layer | Only uses boto3 |
| `update_configuration` | ❌ No IDP common layer | Uses PyYAML/cfnresponse |

## Migration Guide

### For Existing Users

1. **Update your Terraform configuration**:

   ```bash
   cd examples/processing-environment
   git pull  # Get the latest changes
   ```

2. **Review new variables**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferences
   ```

3. **Plan and apply**:

   ```bash
   terraform plan  # Review the changes
   terraform apply # Apply the updates
   ```

### For New Users

Simply follow the updated README instructions - the example now demonstrates the complete, modern architecture.

## Verification

Run the verification script to ensure everything is properly configured:

```bash
cd examples/processing-environment
./verify_example.sh
```

## Notes

- The layer build may take 5-10 minutes on first deployment
- Use `force_layer_rebuild = true` during development for faster iteration
- The layer is automatically rebuilt when source code changes
- The same layer can be reused across multiple environments

The example now serves as a complete reference implementation of the new IDP common layer architecture! 🚀
