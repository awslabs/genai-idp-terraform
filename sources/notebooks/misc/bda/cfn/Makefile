
# Replace these values with the BDA values to work with 
BDA_PROJECT_ARN?=arn:aws:bedrock:us-xxx-1:1234567890:data-automation-project/a1b2c3d4e5
BDA_BLUEPRINT_ARN?=arn:aws:bedrock:us-xxx-1:1234567890:blueprint/a1b2c3d4e5

# First run list-projects to get the ARN of the project to work with
list-projects:
	aws bedrock-data-automation list-data-automation-projects --no-cli-pager

list-blueprints:
	aws bedrock-data-automation list-blueprints --no-cli-pager

get-project:
	aws bedrock-data-automation get-data-automation-project --project-arn $(BDA_PROJECT_ARN) --no-cli-pager > bda-project.json

get-blueprint:
	aws bedrock-data-automation get-blueprint --blueprint-arn $(BDA_BLUEPRINT_ARN)