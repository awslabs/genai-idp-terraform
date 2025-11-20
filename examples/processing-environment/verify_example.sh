#!/bin/bash
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

# Verification script for the updated processing-environment example

echo "🔍 Verifying Processing Environment Example..."
echo

# Check that idp_common_layer module is included
if grep -q "module.*idp_common_layer" main.tf; then
    echo "✅ IDP common layer module included"
else
    echo "❌ IDP common layer module missing"
    exit 1
fi

# Check that processing environment uses the layer ARN
if grep -q "idp_common_layer_arn.*=.*module.idp_common_layer.layer_arn" main.tf; then
    echo "✅ Processing environment uses external layer ARN"
else
    echo "❌ Processing environment should use external layer ARN"
    exit 1
fi

# Check that new variables are defined
new_vars=("idp_common_layer_extras" "force_layer_rebuild" "layer_build_wait_time")
for var in "${new_vars[@]}"; do
    if grep -q "variable \"$var\"" variables.tf; then
        echo "✅ Variable $var defined"
    else
        echo "❌ Variable $var missing"
        exit 1
    fi
done

# Check that new outputs are defined
if grep -q "output.*idp_common_layer_arn" outputs.tf; then
    echo "✅ IDP common layer ARN output defined"
else
    echo "❌ IDP common layer ARN output missing"
    exit 1
fi

if grep -q "output.*lambda_functions" outputs.tf; then
    echo "✅ Lambda functions output defined"
else
    echo "❌ Lambda functions output missing"
    exit 1
fi

# Check that terraform.tfvars.example includes new variables
if grep -q "idp_common_layer_extras" terraform.tfvars.example; then
    echo "✅ terraform.tfvars.example includes layer configuration"
else
    echo "❌ terraform.tfvars.example should include layer configuration"
    exit 1
fi

# Check that README mentions IDP common layer
if grep -q -i "idp common layer" README.md; then
    echo "✅ README documents IDP common layer"
else
    echo "❌ README should document IDP common layer"
    exit 1
fi

# Check that README mentions the new architecture
if grep -q "external layer ARN" README.md; then
    echo "✅ README documents external layer dependency"
else
    echo "❌ README should document external layer dependency"
    exit 1
fi

# Check that README includes layer extras documentation
if grep -q "Available IDP Common Layer Extras" README.md; then
    echo "✅ README documents available layer extras"
else
    echo "❌ README should document available layer extras"
    exit 1
fi

echo
echo "🎉 Processing Environment Example verification completed successfully!"
echo
echo "📋 Summary:"
echo "   - IDP common layer module: ✅"
echo "   - External layer dependency: ✅"
echo "   - New variables defined: ✅"
echo "   - Updated outputs: ✅"
echo "   - Updated documentation: ✅"
echo
echo "📖 Usage:"
echo "   cd examples/processing-environment"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo
echo "🔧 Customization:"
echo "   cp terraform.tfvars.example terraform.tfvars"
echo "   # Edit terraform.tfvars with your configuration"
echo "   terraform apply"
