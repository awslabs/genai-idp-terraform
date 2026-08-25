# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Deployment-scoped BDA OCR project (IDP v0.6 `ocr.backend: bda`).
#
# The `bda` OCR backend runs a Bedrock Data Automation *standard-output SYNC*
# project as a pure OCR engine, in place of Textract. Upstream provisions that
# project with a `Custom::BDAOCRProject` CloudFormation custom resource
# (patterns/unified/template.yaml) so each stack owns its own project instead of
# sharing one account-global project.
#
# The Terraform equivalent is a manager Lambda plus an
# `aws_lambda_invocation` with `lifecycle_scope = "CRUD"`, which is the closest
# analogue of a custom resource: the provider invokes the function on create and
# update AND on destroy, so the project is torn down with the deployment rather
# than orphaned.
#
# DIVERGENCE FROM UPSTREAM (deliberate): upstream creates the project
# unconditionally; here it is gated behind `var.enable_bda_ocr_backend`, default
# false. Bedrock Data Automation is not available in every region, and an
# unconditional control-plane create would fail `apply` for every deployment in
# those regions — including the majority that never select the `bda` backend.
# With the flag off, `BDA_OCR_PROJECT_ARN` is empty, which is exactly the state
# upstream documents for regions without BDA: the `bda` backend then errors
# clearly instead of silently misbehaving.

data "archive_file" "bda_ocr_project" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../../src/lambda/bda-ocr-project"
  output_path = "${path.module}/bda_ocr_project_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "bda_ocr_project" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  name = "${local.name_prefix}-bda-ocr-project-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bda_ocr_project_basic" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  role       = aws_iam_role.bda_ocr_project[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "bda_ocr_project_vpc" {
  count = var.enable_bda_ocr_backend && length(local.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.bda_ocr_project[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "bda_ocr_project" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  name = "${local.name_prefix}-bda-ocr-project-policy"
  role = aws_iam_role.bda_ocr_project[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Control-plane management of the deployment-scoped BDA OCR project.
        # Data-plane InvokeDataAutomation belongs to the OCR function, not here.
        {
          Effect = "Allow"
          Action = [
            "bedrock:CreateDataAutomationProject",
            "bedrock:GetDataAutomationProject",
            "bedrock:UpdateDataAutomationProject",
            "bedrock:DeleteDataAutomationProject",
          ]
          Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:data-automation-project/*"
        },
        # ListDataAutomationProjects is a collection operation with no
        # resource-level scoping; the manager uses it to find the project by name.
        {
          Effect   = "Allow"
          Action   = ["bedrock:ListDataAutomationProjects"]
          Resource = "*"
        },
      ],
      var.encryption_key_arn != null ? [{
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = var.encryption_key_arn
      }] : []
    )
  })
}

resource "aws_lambda_function" "bda_ocr_project" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  architectures = [var.lambda_architecture]
  function_name = "${local.name_prefix}-bda-ocr-project"
  role          = aws_iam_role.bda_ocr_project[0].arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  description   = "Manages the deployment-scoped BDA OCR standard-output project"
  # Must exceed the ~120s the library waits for the project to reach COMPLETED.
  timeout     = 300
  memory_size = 128

  filename         = data.archive_file.bda_ocr_project[0].output_path
  source_code_hash = data.archive_file.bda_ocr_project[0].output_base64sha256

  # The manager calls idp_common.bda.bda_ocr, which arrives via the layer.
  layers = [var.idp_common_layer_arn != null ? var.idp_common_layer_arn : var.base_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL = local.log_level
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "bda_ocr_project" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.bda_ocr_project[0].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = local.common_tags
}

# Guard the same IAM eventual-consistency window the rest of the module guards:
# the first invocation happens immediately after the role policy is written, and
# bedrock:ListDataAutomationProjects would otherwise fail with AccessDenied.
resource "time_sleep" "wait_for_bda_ocr_project_iam" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  depends_on = [
    aws_iam_role_policy.bda_ocr_project,
    aws_iam_role_policy_attachment.bda_ocr_project_basic,
    aws_cloudwatch_log_group.bda_ocr_project,
  ]

  create_duration = "30s"
}

resource "aws_lambda_invocation" "bda_ocr_project" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  function_name = aws_lambda_function.bda_ocr_project[0].function_name

  # CRUD (not the default CREATE_ONLY) so the provider also invokes the manager
  # on destroy, with tf.action = "delete". That is what makes this behave like
  # upstream's custom resource instead of leaking a project per deployment.
  lifecycle_scope = "CRUD"

  input = jsonencode({
    # Scopes the project name to this deployment: <name_prefix>_OCR_StdOutput.
    StackName = local.name_prefix
    # Bump to force a re-run after changing the project's standard-output or
    # modality-routing configuration.
    ConfigVersion = "1"
  })

  depends_on = [time_sleep.wait_for_bda_ocr_project_iam]
}

# Data-plane grant for the OCR function: SYNC InvokeDataAutomation against the
# deployment-scoped standard-output project plus the standard data-automation
# profile. Attached as its own policy, gated on the flag, so the OCR role carries
# no BDA permissions at all unless the backend is actually provisioned.
#
# Note this is the SYNC action (`bedrock:InvokeDataAutomation`), distinct from the
# ASYNC `bedrock:InvokeDataAutomationAsync` that the BDA *processing* branch uses
# in iam_bda.tf. The profile is granted in both this region and any region (the
# cross-region profile ARN), matching upstream.
resource "aws_iam_role_policy" "ocr_lambda_bda_ocr" {
  count = var.enable_bda_ocr_backend ? 1 : 0

  name = "${local.name_prefix}-ocr-lambda-bda-ocr-policy"
  role = aws_iam_role.ocr_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["bedrock:InvokeDataAutomation"]
      Resource = [
        "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:data-automation-project/*",
        "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:data-automation-profile/*.data-automation-v1",
        "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:data-automation-profile/*.data-automation-v1",
      ]
    }]
  })
}

locals {
  # ARN of the deployment-scoped BDA OCR project, or "" when the backend is off.
  # The OCR function receives this as BDA_OCR_PROJECT_ARN; empty means the `bda`
  # backend is unavailable and errors clearly if a config version selects it.
  bda_ocr_project_arn = var.enable_bda_ocr_backend ? try(
    jsondecode(jsondecode(aws_lambda_invocation.bda_ocr_project[0].result).body).projectArn,
    ""
  ) : ""
}
