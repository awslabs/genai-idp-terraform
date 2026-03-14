# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# DynamoDB-based Resolvers
# Lambda-based resolvers have been moved to their respective lambda_*.tf files

# Create Document Resolver
resource "aws_appsync_resolver" "create_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "createDocument"
  data_source = aws_appsync_datasource.tracking_table.name

  request_template = <<EOF
#set( $PK = "doc#$${ctx.args.input.ObjectKey}" )
  
#set( $shardsInDay = 6 )
#set( $shardDivider = 24 / $shardsInDay )
#set( $Integer = 0 )
#set( $now = $ctx.args.input.QueuedTime )
#set( $date = $now.substring(0, 10) )
#set( $hourString = $now.substring(11, 13) )
#set( $hour = $Integer.parseInt($hourString) )
#set( $hourShard = $hour / $shardDivider )
#set( $shardPad = $date.format("%02d", $hourShard) )
#set( $listPk = "list#$${date}#s#$${shardPad}" )
#set( $listSk = "ts#$${now}#id#$${ctx.args.input.ObjectKey}" )
  
{
  "version" : "2018-05-29",
  "operation" : "TransactWriteItems",
  "transactItems": [
    {
      "table": "${local.tracking_table_name}",
      "operation": "PutItem",
      "key" : {
        "PK": $util.dynamodb.toDynamoDBJson($PK),
        "SK": $util.dynamodb.toDynamoDBJson("none"),
      },
      "attributeValues": $util.dynamodb.toMapValuesJson($ctx.args.input),
    },
    {
      "table": "${local.tracking_table_name}",
      "operation": "PutItem",
      "key" : {
        "PK": $util.dynamodb.toDynamoDBJson($listPk),
        "SK": $util.dynamodb.toDynamoDBJson($listSk),
      },
      "attributeValues": {
        "ObjectKey": $util.dynamodb.toDynamoDBJson($ctx.args.input.ObjectKey),
        "QueuedTime": $util.dynamodb.toDynamoDBJson($ctx.args.input.QueuedTime),
        "ExpiresAfter": $util.dynamodb.toDynamoDBJson($ctx.args.input.ExpiresAfter),
      },
    },
  ],
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson({"ObjectKey": $ctx.args.input.ObjectKey})
EOF
}

# Update Document Resolver
resource "aws_appsync_resolver" "update_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "updateDocument"
  data_source = aws_appsync_datasource.tracking_table.name

  request_template = <<EOF
#set( $PK = "doc#$${ctx.args.input.ObjectKey}" )
#set( $expNames = {} )
#set( $expValues = {} )
#set( $expSet = {} )
## Iterate through each argument with values and update expression variables **
#foreach( $entry in $ctx.args.input.entrySet() )
    ## skip empty values **
    #if( !$util.isNullOrBlank($entry.value)  )
        $util.qr( $expSet.put("#$${entry.key}", ":$${entry.key}") )
        $util.qr( $expNames.put("#$${entry.key}", "$${entry.key}") )
        $util.qr( $expValues.put(":$${entry.key}", $util.dynamodb.toDynamoDB($entry.value)) )
    #end
#end
## Start building the update expression, starting with attributes we're going to SET **
#set( $expression = "" )
#if( !$${expSet.isEmpty()} )
    #set( $expression = "SET" )
    #foreach( $entry in $expSet.entrySet() )
        #set( $expression = "$${expression} $${entry.key} = $${entry.value}" )
        #if ( $foreach.hasNext )
            #set( $expression = "$${expression}," )
        #end
    #end
#end
{
    "version" : "2018-05-29",
    "operation" : "UpdateItem",
    "key" : {
      "PK": $util.dynamodb.toDynamoDBJson($PK),
      "SK": $util.dynamodb.toDynamoDBJson("none"),
    },
    "update" : {
        "expression": "$expression"
        #if( !$${expNames.isEmpty()} )
        , "expressionNames": $utils.toJson($expNames)
        #end
        #if( !$${expValues.isEmpty()} )
        , "expressionValues": $utils.toJson($expValues)
        #end
    }
}
EOF

  response_template = "$util.toJson($ctx.result)"
}

# Get Document Resolver
resource "aws_appsync_resolver" "get_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getDocument"
  data_source = aws_appsync_datasource.tracking_table.name

  request_template = <<EOF
#set( $PK = "doc#$${context.arguments.ObjectKey}" )
{
  "version": "2018-05-29",
  "operation": "GetItem",
  "key" : {
    "PK": $util.dynamodb.toDynamoDBJson($PK),
    "SK": $util.dynamodb.toDynamoDBJson("none"),
  }
}
EOF

  response_template = "$util.toJson($ctx.result)"
}

# List Documents Resolver
resource "aws_appsync_resolver" "list_documents" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listDocuments"
  data_source = aws_appsync_datasource.tracking_table.name

  request_template = <<EOF
{
    "version": "2018-05-29",
    "operation": "Scan",
    "filter": {
        #if($context.arguments.startDateTime && $context.arguments.endDateTime)
            "expression": "InitialEventTime BETWEEN :startDateTime AND :endDateTime",
            "expressionValues": {
                ":startDateTime": { "S": "$context.arguments.startDateTime" },
                ":endDateTime": { "S": "$context.arguments.endDateTime" }
            }
        #elseif($context.arguments.startDateTime)
            "expression": "InitialEventTime >= :startDateTime",
            "expressionValues": {
                ":startDateTime": { "S": "$context.arguments.startDateTime" }
            }
        #elseif($context.arguments.endDateTime)
            "expression": "InitialEventTime <= :endDateTime",
            "expressionValues": {
                ":endDateTime": { "S": "$context.arguments.endDateTime" }
            }
        #end
    },
    #if($context.prev.result)
        "nextToken": "$context.prev.result.nextToken",
    #end
    "limit": 50,
    "consistentRead": false,
    "select": "ALL_ATTRIBUTES"
}
EOF

  response_template = <<EOF
{
    "Documents": $util.toJson($ctx.result.items),
    "nextToken": $util.toJson($ctx.result.nextToken)
}
EOF
}

# List Documents by Date and Hour Resolver
resource "aws_appsync_resolver" "list_documents_date_hour" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listDocumentsDateHour"
  data_source = aws_appsync_datasource.tracking_table.name

  request_template = <<EOF
#set( $shardsInDay = 6 )
#set( $shardDivider = 24 / $shardsInDay )
#set( $Integer = 0 )
#set( $now = $util.time.nowISO8601() )
#set( $hourNow = $Integer.parseInt($now.substring(11, 13)) )
#set( $date = $util.defaultIfNullOrBlank($ctx.args.date, $now.substring(0, 10)) )
#set( $hour = $util.defaultIfNull($ctx.args.hour, $hourNow) )
#if( $hour < 0 || $hour > 23 )
  $util.error("Invalid hour parameter - value should be between 0 and 23")
#end
#set( $hourPad = $date.format("%02d", $hour) )
#set( $hourShard = $hour / $shardDivider )
#set( $shardPad = $date.format("%02d", $hourShard) )

#set( $PK = "list#$${date}#s#$${shardPad}" )
#set( $skPrefix = "ts#$${date}T$${hourPad}" )

{
  "version" : "2018-05-29",
  "operation" : "Query",
  "query" : {
    "expression": "PK = :PK and begins_with(SK, :prefix)",
    "expressionValues": {
      ":PK": $util.dynamodb.toDynamoDBJson($PK),
      ":prefix": $util.dynamodb.toDynamoDBJson($skPrefix),
    },
  },
}
EOF

  response_template = <<EOF
{
    "Documents": $util.toJson($ctx.result.items),
    "nextToken": $util.toJson($ctx.result.nextToken)
}
EOF
}

# List Documents by Date and Shard Resolver
resource "aws_appsync_resolver" "list_documents_date_shard" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listDocumentsDateShard"
  data_source = aws_appsync_datasource.tracking_table.name

  request_template = <<EOF
#set( $shardsInDay = 6 )
#set( $shardDivider = 24 / $shardsInDay )
#set( $Integer = 0 )
#set( $now = $util.time.nowISO8601() )
#set( $hourNow = $Integer.parseInt($now.substring(11, 13)) )
#set( $shardNow = $hourNow / $shardDivider )
#set( $date = $util.defaultIfNullOrBlank($ctx.args.date, $now.substring(0, 10)) )
#set( $shard = $util.defaultIfNull($ctx.args.shard, $shardNow) )
#if( $shard >= $shardsInDay )
  $util.error("Invalid shard parameter value - must positive and less than $${shardsInDay}")
#end
#set( $hourShard = $hour / $shardDivider )
#set( $shardPad = $date.format("%02d", $shard) )

#set( $PK = "list#$${date}#s#$${shardPad}" )

{
  "version" : "2018-05-29",
  "operation" : "Query",
  "query" : {
    "expression": "PK = :PK",
    "expressionValues": {
      ":PK": $util.dynamodb.toDynamoDBJson($PK),
    }
  }
}
EOF

  response_template = <<EOF
{
    "Documents": $util.toJson($ctx.result.items),
    "nextToken": $util.toJson($ctx.result.nextToken)
}
EOF
}

# =============================================================================
# DOCUMENT MANAGEMENT RESOLVERS (Lambda-backed)
# =============================================================================

# Upload Document Resolver
resource "aws_appsync_resolver" "upload_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "uploadDocument"
  data_source = aws_appsync_datasource.upload_resolver.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# Delete Document Resolver
resource "aws_appsync_resolver" "delete_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteDocument"
  data_source = aws_appsync_datasource.delete_document_resolver.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# Reprocess Document Resolver
resource "aws_appsync_resolver" "reprocess_document" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "reprocessDocument"
  data_source = aws_appsync_datasource.reprocess_document_resolver.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# Get File Contents Resolver
resource "aws_appsync_resolver" "get_file_contents" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getFileContents"
  data_source = aws_appsync_datasource.get_file_contents_resolver.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# =============================================================================
# CONFIGURATION RESOLVERS (Lambda-backed via configuration_resolver)
# All routed through a single Lambda that dispatches on fieldName
# =============================================================================

resource "aws_appsync_resolver" "get_configuration" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getConfiguration"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "update_configuration" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "updateConfiguration"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "get_config_versions" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getConfigVersions"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "get_config_version" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getConfigVersion"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "set_active_version" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "setActiveVersion"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "delete_config_version" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "deleteConfigVersion"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "get_pricing" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getPricing"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "update_pricing" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "updatePricing"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "restore_default_pricing" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "restoreDefaultPricing"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "list_configuration_library" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "listConfigurationLibrary"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

resource "aws_appsync_resolver" "get_configuration_library_file" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getConfigurationLibraryFile"
  data_source = aws_appsync_datasource.configuration.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# =============================================================================
# STEP FUNCTIONS RESOLVER (Lambda-backed)
# =============================================================================

resource "aws_appsync_resolver" "get_step_function_execution" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "getStepFunctionExecution"
  data_source = aws_appsync_datasource.get_stepfunction_execution_resolver.name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# =============================================================================
# KNOWLEDGE BASE RESOLVER (Lambda-backed, conditional)
# =============================================================================

resource "aws_appsync_resolver" "query_knowledge_base" {
  for_each    = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "queryKnowledgeBase"
  data_source = aws_appsync_datasource.query_knowledge_base_resolver["enabled"].name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}

# =============================================================================
# EVALUATION / BASELINE RESOLVER (Lambda-backed, conditional)
# =============================================================================

resource "aws_appsync_resolver" "copy_to_baseline" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "copyToBaseline"
  data_source = aws_appsync_datasource.copy_to_baseline_resolver["enabled"].name

  request_template  = "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}"
  response_template = "$util.toJson($context.result)"
}
