# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Knowledge Base Resources
 *
 * This file contains all AWS Bedrock Knowledge Base resources for document querying functionality.
 * The knowledge base enables natural language queries against processed documents using vector search.
 * 
 * Based on AWS samples implementation:
 * https://github.com/aws-samples/bedrock-custom-model-knowledge-base-terraform
 */

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for current AWS partition
data "aws_partition" "current" {}

#
# OpenSearch Serverless Resources using native AWS provider
#

resource "aws_opensearchserverless_access_policy" "knowledge_base_data_policy" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-data-policy"
  type  = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource = [
            "index/${var.prefix}-kb-collection/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:UpdateIndex",
            "aoss:WriteDocument"
          ]
        },
        {
          ResourceType = "collection"
          Resource = [
            "collection/${var.prefix}-kb-collection"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DescribeCollectionItems",
            "aoss:UpdateCollectionItems"
          ]
        }
      ],
      Principal = [
        aws_iam_role.knowledge_base_role[0].arn,
        data.aws_caller_identity.current.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_security_policy" "knowledge_base_encryption" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-encryption"
  type  = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.prefix}-kb-collection"
        ]
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "knowledge_base_network" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-network"
  type  = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${var.prefix}-kb-collection"
          ]
        },
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${var.prefix}-kb-collection"
          ]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_collection" "knowledge_base_collection" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-collection"
  type  = "VECTORSEARCH"

  tags = {
    Name = "${var.prefix}-kb-collection"
  }

  depends_on = [
    aws_opensearchserverless_access_policy.knowledge_base_data_policy,
    aws_opensearchserverless_security_policy.knowledge_base_encryption,
    aws_opensearchserverless_security_policy.knowledge_base_network
  ]
}

# Wait before creating the index to ensure collection is ready
resource "time_sleep" "wait_before_index_creation" {
  count           = local.knowledge_base_enabled ? 1 : 0
  depends_on      = [aws_opensearchserverless_collection.knowledge_base_collection]
  create_duration = "60s"
}

# OpenSearch index for vector search
resource "opensearch_index" "knowledge_base_index" {
  count                          = local.knowledge_base_enabled ? 1 : 0
  name                           = "${var.prefix}-kb-index"
  number_of_shards               = "2"
  number_of_replicas             = "0"
  index_knn                      = true
  index_knn_algo_param_ef_search = "512"
  mappings = jsonencode({
    properties = {
      "bedrock-knowledge-base-default-vector" = {
        type      = "knn_vector"
        dimension = 1024
        method = {
          name   = "hnsw"
          engine = "faiss"
          parameters = {
            m               = 16
            ef_construction = 512
          }
          space_type = "l2"
        }
      }
      "AMAZON_BEDROCK_METADATA" = {
        type  = "text"
        index = "false"
      }
      "AMAZON_BEDROCK_TEXT_CHUNK" = {
        type  = "text"
        index = "true"
      }
    }
  })
  force_destroy = true
  depends_on    = [time_sleep.wait_before_index_creation]
}

#
# IAM Resources for Knowledge Base
#

# IAM role for Bedrock Knowledge Base
resource "aws_iam_role" "knowledge_base_role" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Bedrock to access OpenSearch Serverless
resource "aws_iam_role_policy" "knowledge_base_opensearch_policy" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-opensearch-policy"
  role  = aws_iam_role.knowledge_base_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "aoss:*"
        ]
        Effect = "Allow"
        Resource = [
          aws_opensearchserverless_collection.knowledge_base_collection[0].arn
        ]
      }
    ]
  })
}

# IAM policy for Bedrock to access S3
resource "aws_iam_role_policy" "knowledge_base_s3_policy" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-s3-policy"
  role  = aws_iam_role.knowledge_base_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.output_bucket.arn,
          "${aws_s3_bucket.output_bucket.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for Bedrock to access foundation models
resource "aws_iam_role_policy" "knowledge_base_bedrock_policy" {
  #checkov:skip=CKV_AWS_355:Bedrock ListFoundationModels and GetFoundationModel require wildcard resource to list all available models
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-bedrock-policy"
  role  = aws_iam_role.knowledge_base_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}::foundation-model/${local.knowledge_base_embedding_model_id}"
        ]
      },
      {
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Wait for IAM consistency
resource "time_sleep" "iam_consistency_delay" {
  count           = local.knowledge_base_enabled ? 1 : 0
  create_duration = "120s"
  depends_on = [
    aws_iam_role_policy.knowledge_base_opensearch_policy,
    aws_iam_role_policy.knowledge_base_s3_policy,
    aws_iam_role_policy.knowledge_base_bedrock_policy
  ]
}

#
# Bedrock Knowledge Base Resources using native AWS provider
#

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "knowledge_base" {
  count    = local.knowledge_base_enabled ? 1 : 0
  name     = "${var.prefix}-knowledge-base"
  role_arn = aws_iam_role.knowledge_base_role[0].arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}::foundation-model/${local.knowledge_base_embedding_model_id}"
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.knowledge_base_collection[0].arn
      vector_index_name = opensearch_index.knowledge_base_index[0].name
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  depends_on = [
    time_sleep.iam_consistency_delay,
    opensearch_index.knowledge_base_index
  ]
}

# Bedrock Data Source
resource "aws_bedrockagent_data_source" "knowledge_base_data_source" {
  count             = local.knowledge_base_enabled ? 1 : 0
  knowledge_base_id = aws_bedrockagent_knowledge_base.knowledge_base[0].id
  name              = "${var.prefix}-kb-data-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.output_bucket.arn
    }
  }
}

#
# Lambda Function for Knowledge Base Ingestion
#

# Archive for knowledge base ingestion Lambda function
data "archive_file" "knowledge_base_ingestion_zip" {
  count       = local.knowledge_base_enabled ? 1 : 0
  type        = "zip"
  output_path = "./knowledge_base_ingestion.zip"
  source {
    content  = <<EOF
const { BedrockAgentClient, StartIngestionJobCommand } = require("@aws-sdk/client-bedrock-agent");

const client = new BedrockAgentClient({ region: process.env.AWS_REGION });

exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  
  const input = {
    knowledgeBaseId: process.env.KNOWLEDGE_BASE_ID,
    dataSourceId: process.env.DATA_SOURCE_ID,
    clientToken: context.awsRequestId,
  };
  
  const command = new StartIngestionJobCommand(input);
  
  try {
    const response = await client.send(command);
    console.log('Ingestion job started:', response.ingestionJob);
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        ingestionJob: response.ingestionJob,
      }),
    };
  } catch (error) {
    console.error('Error starting ingestion job:', error);
    throw error;
  }
};
EOF
    filename = "index.js"
  }
}

# IAM role for knowledge base ingestion Lambda
resource "aws_iam_role" "knowledge_base_ingestion_role" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-ingestion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for knowledge base ingestion Lambda
resource "aws_iam_role_policy" "knowledge_base_ingestion_policy" {
  count = local.knowledge_base_enabled ? 1 : 0
  name  = "${var.prefix}-kb-ingestion-policy"
  role  = aws_iam_role.knowledge_base_ingestion_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob",
          "bedrock:ListIngestionJobs"
        ]
        Resource = [
          aws_bedrockagent_knowledge_base.knowledge_base[0].arn,
          "${aws_bedrockagent_knowledge_base.knowledge_base[0].arn}/*"
        ]
      }
    ]
  })
}

# Lambda function for knowledge base ingestion
resource "aws_lambda_function" "knowledge_base_ingestion" {
  count            = local.knowledge_base_enabled ? 1 : 0
  filename         = data.archive_file.knowledge_base_ingestion_zip[0].output_path
  function_name    = "${var.prefix}-kb-ingestion"
  role             = aws_iam_role.knowledge_base_ingestion_role[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.knowledge_base_ingestion_zip[0].output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 900

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.knowledge_base[0].id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.knowledge_base_data_source[0].data_source_id
    }
  }

  tracing_config {
    mode = "Active"
  }
}

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "allow_s3_invoke" {
  count         = local.knowledge_base_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.knowledge_base_ingestion[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.output_bucket.arn
}

# S3 bucket notification to trigger ingestion
resource "aws_s3_bucket_notification" "output_bucket_notification" {
  count  = local.knowledge_base_enabled ? 1 : 0
  bucket = aws_s3_bucket.output_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.knowledge_base_ingestion[0].arn
    events              = ["s3:ObjectCreated:Put"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
