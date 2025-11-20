# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import re

# Read the IAM file
with open('iam.tf', 'r') as f:
    content = f.read()

# Define the evaluation resources to comment out
resources = [
    'aws_iam_role.evaluation_role',
    'aws_iam_policy.evaluation_policy', 
    'aws_iam_role_policy_attachment.evaluation_policy_attachment',
    'aws_iam_policy.evaluation_bedrock_policy',
    'aws_iam_role_policy_attachment.evaluation_bedrock_attachment',
    'aws_iam_role_policy_attachment.evaluation_kms_attachment',
    'aws_iam_role_policy_attachment.evaluation_vpc_attachment'
]

# Comment out each resource block
for resource in resources:
    # Find the resource block and comment it out
    pattern = rf'(# IAM.*?evaluation.*?\n)?^(resource "{resource}".*?\n)(.*?\n}})'
    
    def replace_func(match):
        comment = match.group(1) if match.group(1) else f"# {resource.split('.')[-1].replace('_', ' ').title()} - DISABLED: Using shared evaluation function from processing environment\n"
        resource_line = f"# {match.group(2)}"
        body = match.group(3)
        # Comment out each line in the body
        commented_body = '\n'.join(f"#   {line}" if line.strip() else "#" for line in body.split('\n'))
        return comment + resource_line + commented_body
    
    content = re.sub(pattern, replace_func, content, flags=re.MULTILINE | re.DOTALL)

# Write back to file
with open('iam.tf', 'w') as f:
    f.write(content)

print("Commented out evaluation resources")
