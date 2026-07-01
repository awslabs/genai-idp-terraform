# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_version = ">= 1.5"

  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
  }
}
