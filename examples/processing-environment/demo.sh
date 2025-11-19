#!/bin/bash

# Demo script for the Processing Environment Example with IDP Common Layer

set -e

echo "🚀 Processing Environment Example with IDP Common Layer Demo"
echo "============================================================"
echo

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    echo "❌ Please run this script from the examples/processing-environment directory"
    exit 1
fi

echo "📋 Step 1: Verify the example configuration"
echo "-------------------------------------------"
if [ -f "verify_example.sh" ]; then
    ./verify_example.sh
    echo
else
    echo "⚠️  Verification script not found, skipping verification"
    echo
fi

echo "📋 Step 2: Initialize Terraform"
echo "-------------------------------"
terraform init
echo

echo "📋 Step 3: Validate configuration"
echo "---------------------------------"
terraform validate
echo "✅ Configuration is valid"
echo

echo "📋 Step 4: Create example terraform.tfvars (optional)"
echo "----------------------------------------------------"
if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ Created terraform.tfvars - you can edit it to customize the deployment"
else
    echo "✅ terraform.tfvars already exists"
fi
echo

echo "📋 Step 5: Plan the deployment"
echo "-----------------------------"
echo "This will show you what resources will be created:"
echo "- KMS key for encryption"
echo "- S3 buckets for input/output"
echo "- IDP common Lambda layer"
echo "- Processing environment infrastructure"
echo
terraform plan
echo

echo "🎯 Next Steps:"
echo "=============="
echo
echo "To deploy the infrastructure:"
echo "  terraform apply"
echo
echo "To customize the deployment:"
echo "  1. Edit terraform.tfvars"
echo "  2. Run: terraform plan"
echo "  3. Run: terraform apply"
echo
echo "To clean up when done:"
echo "  terraform destroy"
echo
echo "📚 Key Features Demonstrated:"
echo "- External IDP common layer creation"
echo "- Layer dependency in processing environment"
echo "- Configurable layer extras"
echo "- Complete end-to-end infrastructure"
echo "- Proper resource dependencies and encryption"
echo
echo "🔧 Layer Configuration Options:"
echo "- idp_common_layer_extras: Choose which dependencies to include"
echo "- force_layer_rebuild: Force rebuild during development"
echo "- layer_build_wait_time: Adjust timeout for layer builds"
echo
echo "✨ The layer will be automatically attached to Lambda functions that need it:"
echo "  ✅ queue_sender (uses idp_common[appsync])"
echo "  ✅ workflow_tracker (uses idp_common[appsync])"
echo "  ❌ lookup_function (no idp_common dependency)"
echo "  ❌ update_configuration (uses PyYAML/cfnresponse only)"
echo
echo "🎉 Demo completed! The example is ready for deployment."
