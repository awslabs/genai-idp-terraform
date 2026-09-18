# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  # 1.7+ is required for the `removed` block with a `lifecycle { destroy = ... }`
  # argument, used by removed-v0-6-4.tf to decommission the deleted ALB hosting
  # stack on a direct upgrade (see docs/migration-v0.5.16-to-v0.6.4.md). The
  # effective floor was already 1.5 because this module uses `check` blocks.
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.us-east-1]
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.70.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
