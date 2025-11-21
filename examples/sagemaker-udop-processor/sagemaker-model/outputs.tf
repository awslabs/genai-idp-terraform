# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "model_data_bucket" {
  description = "S3 bucket name containing the trained model"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "model_data_key" {
  description = "S3 object key for the trained model"
  value       = local.model_path
}

output "model_data_uri" {
  description = "Full S3 URI for the trained model"
  value       = "s3://${aws_s3_bucket.data_bucket.bucket}/${local.model_path}"
  depends_on  = [time_sleep.model_upload_wait]
}

output "training_job_name" {
  description = "Name of the SageMaker training job"
  value       = local.job_name
}

output "data_bucket_name" {
  description = "Name of the S3 bucket containing training data"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "training_status" {
  description = "Status of the training job completion"
  value = {
    status   = local.training_job_status.status
    message  = local.training_job_status.message
    attempts = local.training_job_status.attempts
    complete = local.training_complete
  }
}

output "lambda_functions" {
  description = "Lambda function details"
  value = {
    generate_demo_data = {
      function_name = module.generate_demo_data_lambda.lambda_function_name
      function_arn  = module.generate_demo_data_lambda.lambda_function_arn
    }
    sagemaker_train = {
      function_name = module.sagemaker_train_lambda.lambda_function_name
      function_arn  = module.sagemaker_train_lambda.lambda_function_arn
    }
    is_complete = {
      function_name = module.sagemaker_train_is_complete_lambda.lambda_function_name
      function_arn  = module.sagemaker_train_is_complete_lambda.lambda_function_arn
    }
  }
}

output "ecr_repositories" {
  description = "ECR repository details"
  value = {
    generate_demo_data = {
      repository_url = aws_ecr_repository.generate_demo_data.repository_url
      registry_id    = aws_ecr_repository.generate_demo_data.registry_id
    }
    sagemaker_train = {
      repository_url = aws_ecr_repository.sagemaker_train.repository_url
      registry_id    = aws_ecr_repository.sagemaker_train.registry_id
    }
  }
}
