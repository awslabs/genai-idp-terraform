#!/bin/bash
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

# Verification script for CloudWatch logs fix in lambda-layer-codebuild module

echo "🔍 Verifying CloudWatch Logs Fix for Lambda Layer CodeBuild Module..."
echo

# Check that CloudWatch log group resource exists
if grep -q "resource.*aws_cloudwatch_log_group.*codebuild_log_group" main.tf; then
    echo "✅ CloudWatch log group resource added"
else
    echo "❌ CloudWatch log group resource missing"
    exit 1
fi

# Check that CodeBuild project has logs_config
if grep -A 5 "logs_config" main.tf | grep -q "cloudwatch_logs"; then
    echo "✅ CodeBuild project has logs_config with cloudwatch_logs"
else
    echo "❌ CodeBuild project missing logs_config"
    exit 1
fi

# Check that logs_config references the log group
if grep -A 5 "logs_config" main.tf | grep -q "aws_cloudwatch_log_group.codebuild_log_group.name"; then
    echo "✅ CodeBuild logs_config references the created log group"
else
    echo "❌ CodeBuild logs_config should reference aws_cloudwatch_log_group.codebuild_log_group.name"
    exit 1
fi

# Check that aws_caller_identity data source exists
if grep -q "data.*aws_caller_identity.*current" main.tf; then
    echo "✅ AWS caller identity data source added"
else
    echo "❌ AWS caller identity data source missing"
    exit 1
fi

# Check that IAM policy uses specific log group ARNs
if grep -A 10 "logs:CreateLogStream" main.tf | grep -q "data.aws_caller_identity.current.account_id"; then
    echo "✅ IAM policy uses specific log group ARNs with account ID"
else
    echo "❌ IAM policy should use specific log group ARNs instead of wildcards"
    exit 1
fi

# Check that IAM policy includes both log group and log stream permissions
if grep -A 15 "logs:CreateLogStream" main.tf | grep -q ":log-group:/aws/codebuild/" && grep -A 15 "logs:CreateLogStream" main.tf | grep -q ":log-group:/aws/codebuild/.*:\*"; then
    echo "✅ IAM policy includes both log group and log stream ARN patterns"
else
    echo "❌ IAM policy should include both log group and log stream ARN patterns"
    exit 1
fi

# Check that log group has retention configured
if grep -A 5 "aws_cloudwatch_log_group.*codebuild_log_group" main.tf | grep -q "retention_in_days"; then
    echo "✅ CloudWatch log group has retention configured"
else
    echo "❌ CloudWatch log group should have retention_in_days configured"
    exit 1
fi

echo
echo "🎉 CloudWatch Logs Fix verification completed successfully!"
echo
echo "📋 Summary of fixes:"
echo "   - CloudWatch log group created: ✅"
echo "   - CodeBuild logs_config added: ✅"
echo "   - IAM policy uses specific ARNs: ✅"
echo "   - AWS caller identity data source: ✅"
echo "   - Log retention configured: ✅"
echo
echo "🔧 The fix addresses the ACCESS_DENIED error by:"
echo "   1. Creating an explicit CloudWatch log group"
echo "   2. Configuring CodeBuild to use the specific log group"
echo "   3. Granting specific IAM permissions for the log group"
echo "   4. Following security best practices with least privilege"
echo
echo "🚀 Ready for deployment!"
