# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SageMaker Classifier for UDOP Processor Example
# This file creates a SageMaker endpoint with a document classification model
# This is an example implementation - users should customize this for their specific models

# Local values for the classifier
locals {
  classifier_name_prefix = "${local.name_prefix}-classifier"

  # Use the trained model from the sagemaker-model module
  model_data_uri = module.sagemaker_model.model_data_uri

  classifier_tags = merge(var.tags, {
    Component = "SagemakerClassifier"
  })
}

# IAM Role for SageMaker Model
resource "aws_iam_role" "sagemaker_model_role" {
  name = "${local.classifier_name_prefix}-model-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = local.classifier_tags
}

# IAM Policy for SageMaker Model
resource "aws_iam_role_policy" "sagemaker_model_policy" {
  name = "${local.classifier_name_prefix}-model-policy"
  role = aws_iam_role.sagemaker_model_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.output_bucket.arn}/*",
          "arn:${data.aws_partition.current.partition}:s3:::${module.sagemaker_model.data_bucket_name}",
          "arn:${data.aws_partition.current.partition}:s3:::${module.sagemaker_model.data_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"
      }
    ]
  })
}

# Attach the SageMaker execution role policy
resource "aws_iam_role_policy_attachment" "sagemaker_model_execution_role" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSageMakerFullAccess"
  role       = aws_iam_role.sagemaker_model_role.name
}

# Add KMS permissions if KMS key is provided
resource "aws_iam_role_policy" "sagemaker_model_kms_policy" {
  name = "${local.classifier_name_prefix}-model-kms-policy"
  role = aws_iam_role.sagemaker_model_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.encryption_key.arn
      }
    ]
  })
}

# SageMaker Model
resource "aws_sagemaker_model" "udop_model" {
  name               = "${local.classifier_name_prefix}-model"
  execution_role_arn = aws_iam_role.sagemaker_model_role.arn

  primary_container {
    # Using PyTorch inference container for UDOP model
    image          = "763104351884.dkr.ecr.${data.aws_region.current.id}.amazonaws.com/pytorch-inference:2.1.0-gpu-py310"
    model_data_url = local.model_data_uri

    environment = {
      SAGEMAKER_PROGRAM             = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY    = "/opt/ml/model/code"
      SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
      SAGEMAKER_REGION              = data.aws_region.current.id
    }
  }

  tags = local.classifier_tags
}

# SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "udop_endpoint_config" {
  name = "${local.classifier_name_prefix}-endpoint-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.udop_model.name
    initial_instance_count = var.classifier_min_instance_count
    instance_type          = var.classifier_instance_type
    initial_variant_weight = 1.0
  }

  tags = local.classifier_tags
}

# SageMaker Endpoint
resource "aws_sagemaker_endpoint" "udop_endpoint" {
  name                 = "${local.classifier_name_prefix}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.udop_endpoint_config.name

  tags = local.classifier_tags
}

# Application Auto Scaling Target
resource "aws_appautoscaling_target" "sagemaker_target" {
  max_capacity       = var.classifier_max_instance_count
  min_capacity       = var.classifier_min_instance_count
  resource_id        = "endpoint/${aws_sagemaker_endpoint.udop_endpoint.name}/variant/AllTraffic"
  scalable_dimension = "sagemaker:variant:DesiredInstanceCount"
  service_namespace  = "sagemaker"

  depends_on = [aws_sagemaker_endpoint.udop_endpoint]
}

# Application Auto Scaling Policy
resource "aws_appautoscaling_policy" "sagemaker_scaling_policy" {
  name               = "${local.classifier_name_prefix}-endpoint-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sagemaker_target.resource_id
  scalable_dimension = aws_appautoscaling_target.sagemaker_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.sagemaker_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.classifier_target_invocations_per_instance_per_minute / 60.0 # Convert to per second

    predefined_metric_specification {
      predefined_metric_type = "SageMakerVariantInvocationsPerInstance"
    }

    scale_in_cooldown  = var.classifier_scale_in_cooldown_seconds
    scale_out_cooldown = var.classifier_scale_out_cooldown_seconds
  }
}

# Outputs for the classifier
output "classifier_endpoint_name" {
  description = "Name of the SageMaker classifier endpoint"
  value       = aws_sagemaker_endpoint.udop_endpoint.name
}

output "classifier_endpoint_arn" {
  description = "ARN of the SageMaker classifier endpoint"
  value       = aws_sagemaker_endpoint.udop_endpoint.arn
}

output "classifier_model_name" {
  description = "Name of the SageMaker classifier model"
  value       = aws_sagemaker_model.udop_model.name
}

output "classifier_model_arn" {
  description = "ARN of the SageMaker classifier model"
  value       = aws_sagemaker_model.udop_model.arn
}
