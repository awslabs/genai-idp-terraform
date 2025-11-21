# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Bedrock Data Automation Resources
# This file contains the BDA Blueprint and Project resources that define
# the document processing schema and configuration for homeowners insurance applications.

# Create Bedrock Blueprint for document processing
resource "awscc_bedrock_blueprint" "homeowners_insurance_blueprint" {
  blueprint_name = "${var.prefix}-homeowners-insurance-blueprint-${random_string.suffix.result}"
  type           = "DOCUMENT"

  schema = jsonencode({
    "$schema"   = "http://json-schema.org/draft-07/schema#"
    description = "This is a Homeowners Insurance Application form."
    class       = "Homeowners-Insurance-Application"
    type        = "object"
    definitions = {
      PRIMARY_APPLICANT = {
        type = "object"
        properties = {
          Name = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The name of the primary applicant"
          }
          "Date of Birth" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The date of birth of the primary applicant"
          }
          Gender = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The gender of the primary applicant"
          }
          "Marital Status" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The marital status of the primary applicant"
          }
          "Education Level" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The education level of the primary applicant"
          }
          "Existing Esurance Policy" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The existing Esurance policy number of the primary applicant"
          }
          "Drivers License Number" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The drivers license number of the primary applicant"
          }
          "DL State" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The state that issued the drivers license of the primary applicant"
          }
          "Currently Insured Auto" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The current auto insurance company of the primary applicant"
          }
          "Length of Time with Current Auto Carrier" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The length of time the primary applicant has been with their current auto insurance carrier"
          }
          "Length of Time with Prior Auto Carrier" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The length of time the primary applicant was with their prior auto insurance carrier"
          }
          "Years with Prior Property Company" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of years the primary applicant was with their prior property insurance company"
          }
          "Type of Current Property Policy" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The type of current property insurance policy the primary applicant has"
          }
        }
      }
      CO_APPLICANT = {
        type = "object"
        properties = {
          Name = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The name of the co-applicant"
          }
          "Date of Birth" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The date of birth of the co-applicant"
          }
          Gender = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The gender of the co-applicant"
          }
          "Marital Status" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The marital status of the co-applicant"
          }
          "Education Level" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The education level of the co-applicant"
          }
          "Relationship to Primary Applicant" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The relationship of the co-applicant to the primary applicant"
          }
          "Drivers License Number" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The drivers license number of the co-applicant"
          }
          "DL State" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The state that issued the drivers license of the co-applicant"
          }
          "Currently Insured- Auto" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The current auto insurance company of the co-applicant"
          }
          "Length of Time with Current Auto Carrier" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The length of time the co-applicant has been with their current auto insurance carrier"
          }
          "Length of Time with Prior Auto Carrier" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The length of time the co-applicant was with their prior auto insurance carrier"
          }
        }
      }
      AUTO_CLAIMS_ACCIDENTS_VIOLATIONS = {
        type = "object"
        properties = {
          "Number of Auto Accidents" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of auto accidents for all applicants"
          }
          "At-Fault" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of at-fault auto accidents for all applicants"
          }
          "Not-at-Fault" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of not-at-fault auto accidents for all applicants"
          }
          "Number of Violations" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of violations for all applicants"
          }
          Major = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of major violations for all applicants"
          }
          Minor = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of minor violations for all applicants"
          }
          "Number of Comp Claims" = {
            type          = "string"
            inferenceType = "explicit"
            instruction   = "The number of comprehensive claims for all applicants"
          }
        }
      }
    }
    properties = {
      "Named Insured(s) and Mailing Address" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The name and mailing address of the named insured(s)"
      }
      "Insurance Company" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The name and address of the insurance company"
      }
      "Primary Email" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The primary email address of the insured"
      }
      "Primary Phone #" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The primary phone number of the insured"
      }
      "Alternate Phone #" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The alternate phone number of the insured"
      }
      "Insured Property" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The address of the insured property"
      }
      "Primary Applicant Information" = {
        "$ref" = "#/definitions/PRIMARY_APPLICANT"
      }
      "Co-Applicant Information" = {
        "$ref" = "#/definitions/CO_APPLICANT"
      }
      "Policy Number" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The policy number"
      }
      "Purchase Date and Time" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The date and time the policy was purchased"
      }
      "Effective Date" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The effective date of the policy"
      }
      "Expiration Date" = {
        type          = "string"
        inferenceType = "explicit"
        instruction   = "The expiration date of the policy"
      }
      "Auto Claims, Accidents, and Violations" = {
        "$ref" = "#/definitions/AUTO_CLAIMS_ACCIDENTS_VIOLATIONS"
      }
    }
  })

  tags = [
    for key, value in var.tags : {
      key   = key
      value = value
    }
  ]
}

# Create Bedrock Data Automation Project
resource "awscc_bedrock_data_automation_project" "bda_project" {
  project_name        = "${var.prefix}-bda-project-${random_string.suffix.result}"
  project_description = "GenAI IDP Sample project for processing lending package documents"

  standard_output_configuration = {
    document = {
      extraction = {
        granularity = {
          types = ["PAGE", "ELEMENT"]
        }
        bounding_box = {
          state = "DISABLED"
        }
      }
      generative_field = {
        state = "DISABLED"
      }
      output_format = {
        text_format = {
          types = ["MARKDOWN"]
        }
        additional_file_format = {
          state = "DISABLED"
        }
      }
    }
    image = {
      extraction = {
        category = {
          state = "ENABLED"
          types = ["TEXT_DETECTION"]
        }
        bounding_box = {
          state = "ENABLED"
        }
      }
      generative_field = {
        state = "ENABLED"
        types = ["IMAGE_SUMMARY"]
      }
    }
    video = {
      extraction = {
        category = {
          state = "ENABLED"
          types = ["TEXT_DETECTION"]
        }
        bounding_box = {
          state = "ENABLED"
        }
      }
      generative_field = {
        state = "ENABLED"
        types = ["VIDEO_SUMMARY"]
      }
    }
    audio = {
      extraction = {
        category = {
          state = "ENABLED"
          types = ["TRANSCRIPT"]
        }
      }
      generative_field = {
        state = "DISABLED"
      }
    }
  }

  custom_output_configuration = {
    blueprints = [{
      blueprint_arn = awscc_bedrock_blueprint.homeowners_insurance_blueprint.blueprint_arn
    }]
  }

  override_configuration = {
    document = {
      splitter = {
        state = "ENABLED"
      }
    }
  }

  tags = [
    for key, value in var.tags : {
      key   = key
      value = value
    }
  ]
}
