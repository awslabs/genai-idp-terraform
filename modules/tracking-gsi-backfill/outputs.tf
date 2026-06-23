# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "state_machine_arn" {
  description = "ARN of the GSI backfill Step Functions state machine. The operator starts the backfill explicitly, e.g. `aws stepfunctions start-execution --state-machine-arn <this> --input '{\"tableName\":\"<tracking_table_name>\",\"totalSegments\":10}'`. Applying this module never auto-starts a run."
  value       = aws_sfn_state_machine.backfill.arn
}

output "worker_function_arn" {
  description = "ARN of the GSI backfill worker Lambda function"
  value       = aws_lambda_function.backfill_worker.arn
}

output "worker_function_name" {
  description = "Name of the GSI backfill worker Lambda function"
  value       = aws_lambda_function.backfill_worker.function_name
}

output "worker_role_arn" {
  description = "ARN of the GSI backfill worker Lambda execution role"
  value       = aws_iam_role.backfill_worker.arn
}
