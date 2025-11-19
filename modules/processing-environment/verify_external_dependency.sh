#!/bin/bash

# Verification script for processing-environment module external layer dependency

echo "🔍 Verifying Processing Environment Module External Dependency..."
echo

# Check that idp_common_layer_arn variable exists and is required
if grep -q "variable \"idp_common_layer_arn\"" variables.tf; then
    echo "✅ idp_common_layer_arn variable exists"
    if grep -A 10 "variable \"idp_common_layer_arn\"" variables.tf | grep -q "type.*=.*string"; then
        echo "✅ idp_common_layer_arn is string type"
    else
        echo "❌ idp_common_layer_arn should be string type"
        exit 1
    fi
else
    echo "❌ idp_common_layer_arn variable missing"
    exit 1
fi

# Check that old layer-related variables are removed
old_vars=("idp_common_layer_extras" "force_layer_rebuild")
for var in "${old_vars[@]}"; do
    if grep -q "variable \"$var\"" variables.tf; then
        echo "❌ Old variable $var still exists (should be removed)"
        exit 1
    else
        echo "✅ Old variable $var removed"
    fi
done

# Check that no internal idp-common-layer module exists
if grep -q "module.*idp_common_layer" main.tf; then
    echo "❌ Internal idp_common_layer module still exists (should be removed)"
    exit 1
else
    echo "✅ No internal idp_common_layer module found"
fi

# Check that functions_using_idp_common logic is removed
if grep -q "functions_using_idp_common" main.tf; then
    echo "❌ functions_using_idp_common logic still exists (should be removed)"
    exit 1
else
    echo "✅ functions_using_idp_common logic removed"
fi

# Check that queue_sender uses external layer
if grep -A 20 "resource \"aws_lambda_function\" \"queue_sender\"" lambda_functions.tf | grep -q "var.idp_common_layer_arn"; then
    echo "✅ queue_sender uses external layer ARN"
else
    echo "❌ queue_sender should use var.idp_common_layer_arn"
    exit 1
fi

# Check that workflow_tracker uses external layer
if grep -A 20 "resource \"aws_lambda_function\" \"workflow_tracker\"" lambda_functions.tf | grep -q "var.idp_common_layer_arn"; then
    echo "✅ workflow_tracker uses external layer ARN"
else
    echo "❌ workflow_tracker should use var.idp_common_layer_arn"
    exit 1
fi

# Check that update_configuration does NOT use external layer
if grep -A 20 "resource \"aws_lambda_function\" \"update_configuration\"" lambda_functions.tf | grep -q "var.idp_common_layer_arn"; then
    echo "❌ update_configuration should NOT use external layer ARN"
    exit 1
else
    echo "✅ update_configuration correctly does not use external layer"
fi

# Check that idp_common_layer output is removed
if grep -q "output.*idp_common_layer" outputs.tf; then
    echo "❌ idp_common_layer output still exists (should be removed)"
    exit 1
else
    echo "✅ idp_common_layer output removed"
fi

# Check that examples show external dependency pattern
if [ -f "examples/basic_usage.tf" ]; then
    if grep -q "module.*idp_common_layer" examples/basic_usage.tf; then
        echo "✅ Examples show external layer creation"
    else
        echo "❌ Examples should show external layer creation"
        exit 1
    fi
    
    if grep -q "idp_common_layer_arn.*=.*module.idp_common_layer.layer_arn" examples/basic_usage.tf; then
        echo "✅ Examples show layer ARN dependency"
    else
        echo "❌ Examples should show layer ARN dependency"
        exit 1
    fi
else
    echo "⚠️  No examples file found"
fi

echo
echo "🎉 Processing Environment Module verification completed successfully!"
echo
echo "📋 Summary:"
echo "   - External dependency: ✅"
echo "   - No internal layer module: ✅"
echo "   - Hardcoded layer assignments: ✅"
echo "   - Simplified architecture: ✅"
echo
echo "📖 Usage Pattern:"
echo "   # Create layer separately"
echo "   module \"idp_common_layer\" {"
echo "     source = \"./modules/idp-common-layer\""
echo "     stack_name = \"my-stack\""
echo "   }"
echo
echo "   # Use in processing environment"
echo "   module \"processing_environment\" {"
echo "     source = \"./modules/processing-environment\""
echo "     idp_common_layer_arn = module.idp_common_layer.layer_arn"
echo "     # ... other config ..."
echo "   }"
