# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Agent Analytics AppSync Resolvers
# These resolvers provide GraphQL API access to agent analytics functionality

#
# Data Sources for Agent Analytics
#

# Agent Request Handler Lambda Data Source
resource "aws_appsync_datasource" "agent_request_handler" {
  count            = var.agent_analytics.enabled ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "AgentRequestHandler"
  description      = "Lambda function to handle agent query requests"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = module.agent_analytics[0].agent_request_handler_function_arn
  }
}

# List Available Agents Lambda Data Source
resource "aws_appsync_datasource" "list_available_agents" {
  count            = var.agent_analytics.enabled ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "ListAvailableAgents"
  description      = "Lambda function to list available analytics agents"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = module.agent_analytics[0].list_available_agents_function_arn
  }
}

# Agent Table DynamoDB Data Source
resource "aws_appsync_datasource" "agent_table" {
  count            = var.agent_analytics.enabled ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "AgentTable"
  description      = "DynamoDB table for agent job tracking"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = aws_iam_role.appsync_dynamodb_role.arn

  dynamodb_config {
    table_name = module.agent_analytics[0].agent_table_name
  }
}

#
# Resolvers for Agent Analytics
#

# Submit Agent Query Resolver (Query)
resource "aws_appsync_resolver" "submit_agent_query" {
  count       = var.agent_analytics.enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "submitAgentQuery"
  data_source = aws_appsync_datasource.agent_request_handler[0].name
}

# List Available Agents Resolver (Query)
resource "aws_appsync_resolver" "list_available_agents" {
  count       = var.agent_analytics.enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listAvailableAgents"
  data_source = aws_appsync_datasource.list_available_agents[0].name
}

# Get Agent Job Status Resolver (Query)
resource "aws_appsync_resolver" "get_agent_job_status" {
  count       = var.agent_analytics.enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getAgentJobStatus"
  data_source = aws_appsync_datasource.agent_table[0].name

  request_template = <<EOF
#set($userId = $context.identity.username)
#if(!$userId)
  #set($userId = $context.identity.sub)
#end
#if(!$userId)
  #set($userId = "anonymous")
#end
{
  "version": "2018-05-29",
  "operation": "GetItem",
  "key": {
    "PK": $util.dynamodb.toDynamoDBJson("agent#$${userId}"),
    "SK": $util.dynamodb.toDynamoDBJson($ctx.args.jobId)
  }
}
EOF

  response_template = <<EOF
#if(!$ctx.result)
  null
#else
  {
    "jobId": $util.toJson($ctx.result.SK),
    "status": $util.toJson($ctx.result.status),
    "query": $util.toJson($ctx.result.query),
    "agentIds": $util.toJson($ctx.result.agentIds),
    "createdAt": $util.toJson($ctx.result.createdAt),
    "completedAt": $util.toJson($ctx.result.completedAt),
    "result": $util.toJson($ctx.result.result),
    "error": $util.toJson($ctx.result.error),
    "agent_messages": $util.toJson($ctx.result.agent_messages)
  }
#end
EOF
}

# List Agent Jobs Resolver (Query)
resource "aws_appsync_resolver" "list_agent_jobs" {
  count       = var.agent_analytics.enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listAgentJobs"
  data_source = aws_appsync_datasource.agent_table[0].name

  request_template = <<EOF
#set($userId = $context.identity.username)
#if(!$userId)
  #set($userId = $context.identity.sub)
#end
#if(!$userId)
  #set($userId = "anonymous")
#end
{
  "version": "2018-05-29",
  "operation": "Query",
  "query": {
    "expression": "PK = :pk",
    "expressionValues": {
      ":pk": $util.dynamodb.toDynamoDBJson("agent#$${userId}")
    }
  },
  #if($ctx.args.limit)
    "limit": $ctx.args.limit,
  #else
    "limit": 20,
  #end
  #if($ctx.args.nextToken)
    "nextToken": "$ctx.args.nextToken",
  #end
  "scanIndexForward": false
}
EOF

  response_template = <<EOF
{
  "items": [
    #foreach($item in $ctx.result.items)
      {
        "jobId": $util.toJson($item.SK),
        "status": $util.toJson($item.status),
        "query": $util.toJson($item.query),
        "agentIds": $util.toJson($item.agentIds),
        "createdAt": $util.toJson($item.createdAt),
        #if($item.completedAt)
        "completedAt": $util.toJson($item.completedAt),
        #end
        #if($item.result)
        "result": $util.toJson($item.result),
        #end
        #if($item.error)
        "error": $util.toJson($item.error)
        #end
      }#if($foreach.hasNext),#end
    #end
  ],
  "nextToken": $util.toJson($ctx.result.nextToken)
}
EOF
}

# Update Agent Job Status Resolver (Mutation)
resource "aws_appsync_resolver" "update_agent_job_status" {
  count       = var.agent_analytics.enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "updateAgentJobStatus"
  data_source = aws_appsync_datasource.agent_table[0].name

  request_template = <<EOF
#set($userId = $ctx.args.userId)
#set($expNames = {})
#set($expValues = {})

## Set status (required)
$util.qr($expNames.put("#status", "status"))
$util.qr($expValues.put(":status", $util.dynamodb.toDynamoDB($ctx.args.status)))
#set($updateExpression = "SET #status = :status")

## Set result (optional)
#if($ctx.args.result)
  $util.qr($expNames.put("#result", "result"))
  $util.qr($expValues.put(":result", $util.dynamodb.toDynamoDB($ctx.args.result)))
  #set($updateExpression = "$${updateExpression}, #result = :result")
#end

## Set completedAt to current timestamp when status is COMPLETED or FAILED
#if($ctx.args.status == "COMPLETED" || $ctx.args.status == "FAILED")
  $util.qr($expNames.put("#completedAt", "completedAt"))
  $util.qr($expValues.put(":completedAt", $util.dynamodb.toDynamoDB($util.time.nowISO8601())))
  #set($updateExpression = "$${updateExpression}, #completedAt = :completedAt")
#end

{
  "version": "2018-05-29",
  "operation": "UpdateItem",
  "key": {
    "PK": $util.dynamodb.toDynamoDBJson("agent#$${userId}"),
    "SK": $util.dynamodb.toDynamoDBJson($ctx.args.jobId)
  },
  "update": {
    "expression": "$updateExpression",
    "expressionNames": $utils.toJson($expNames),
    "expressionValues": $utils.toJson($expValues)
  }
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end

## Return false if no item was updated (item not found)
#if(!$ctx.result)
  false
#else
  true
#end
EOF
}

# Delete Agent Job Resolver (Mutation)
resource "aws_appsync_resolver" "delete_agent_job" {
  count       = var.agent_analytics.enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteAgentJob"
  data_source = aws_appsync_datasource.agent_table[0].name

  request_template = <<EOF
#set($userId = $context.identity.username)
#if(!$userId)
  #set($userId = $context.identity.sub)
#end
#if(!$userId)
  #set($userId = "anonymous")
#end
{
  "version": "2018-05-29",
  "operation": "DeleteItem",
  "key": {
    "PK": $util.dynamodb.toDynamoDBJson("agent#$${userId}"),
    "SK": $util.dynamodb.toDynamoDBJson($ctx.args.jobId)
  }
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#else
  true
#end
EOF
}

#
# Lambda Permissions for AppSync
#

# Note: Lambda permissions for agent functions are managed by the agent-analytics module
# to avoid conflicts with statement IDs