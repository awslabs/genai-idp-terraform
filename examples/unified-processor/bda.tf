# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Optional BDA project, created only when create_bda_project = true, so this
# example is self-contained on a clean account (no pre-existing project needed).
# When false, pass an existing project via var.bda_project_arn instead.
resource "awscc_bedrock_data_automation_project" "bda_project" {
  count = var.create_bda_project ? 1 : 0

  project_name        = "${local.name_prefix}-bda-project"
  project_description = "Unified processor example: BDA project linked to the bda config version"

  standard_output_configuration = {
    document = {
      extraction = {
        granularity  = { types = ["PAGE", "ELEMENT"] }
        bounding_box = { state = "DISABLED" }
      }
      generative_field = { state = "DISABLED" }
      output_format = {
        text_format            = { types = ["MARKDOWN"] }
        additional_file_format = { state = "DISABLED" }
      }
    }
  }
}
