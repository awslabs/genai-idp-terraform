# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    # kreuzwerker/docker is declared with configuration_aliases so the
    # caller (root config) configures the provider once -- with the
    # correct host/auth sourced from build-runtime-check -- and passes it
    # explicitly via `providers = { docker = docker.lambda_local }` on
    # the module call. That keeps lambda_local = false consumers free of
    # any docker provider configuration concerns.
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}
