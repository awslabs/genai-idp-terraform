# Environment Setup Guide

This guide walks you through setting up different environments for the GenAI IDP Accelerator with Terraform.

The accelerator's root module consumes infrastructure you provide and configures
the processing stack through typed variable objects. It does not create the
input, output, and working S3 buckets or the VPC. The examples under `examples/`
show a complete surrounding setup (buckets, KMS key, Cognito, and optionally a
VPC) that you can copy per environment.

## Separating Environments

Give each environment its own state and a distinct `prefix`, and keep its inputs
in a separate `terraform.tfvars`:

```hcl
# dev.tfvars
prefix = "genai-idp-dev"
region = "us-east-1"

log_level          = "INFO"
log_retention_days = 7
tags = {
  Environment = "dev"
}
```

```hcl
# staging.tfvars
prefix = "genai-idp-staging"
region = "us-east-1"

log_level          = "INFO"
log_retention_days = 30
lambda_tracing_mode = "Active"
tags = {
  Environment = "staging"
}
```

For lower-cost non-production environments, leave the optional subsystems off
(`evaluation`, `reporting`, and the optional `api` features default off) and only
enable `web_ui` when you need the console.

## Required Inputs

Every deployment provides the buckets and encryption key the module operates on,
plus a `processor`:

```hcl
input_bucket_arn   = aws_s3_bucket.input.arn
output_bucket_arn  = aws_s3_bucket.output.arn
working_bucket_arn = aws_s3_bucket.working.arn

encryption_key_arn = aws_kms_key.idp.arn
enable_encryption  = true

processor = {
  type   = "bedrock-llm"
  config = yamldecode(file("config.yaml"))
}
```

See the [Terraform Modules](../terraform-modules/index.md) page for the full
`processor` selection model and the other configuration objects (`api`,
`web_ui`, `evaluation`, `reporting`).

## Network Configuration

The module does not create a VPC. To run inside your own VPC, pass existing
subnets and security groups; the Lambdas are then attached to them:

```hcl
vpc_subnet_ids         = ["subnet-...", "subnet-..."]
vpc_security_group_ids = ["sg-..."]
```

For a VPC-isolated posture (private API Gateway, S3 VPC endpoint, and ALB or
API Gateway Web UI hosting rather than CloudFront), start from the
`bedrock-llm-processor-vpc` example, which wires the VPC, endpoints, and the
`private_network` / `api` settings end to end.

## Storage and Data Protection

The buckets are yours to configure. Apply versioning, server-side encryption,
and lifecycle rules on the buckets you pass in as `input_bucket_arn`,
`output_bucket_arn`, and `working_bucket_arn`. Use `data_tracking_retention_days`
to control how long the tracking table retains document records, and rely on the
KMS key you supply via `encryption_key_arn` for encryption of the resources the
module manages.

## Monitoring and Logging

- `log_level` sets Lambda log verbosity; `log_retention_days` sets retention.
- `lambda_tracing_mode` (`Active` or `PassThrough`) controls X-Ray tracing.
- The monitoring module provisions CloudWatch dashboards and alarms for the
  processing stack; wire its alarm actions to your own SNS topic.

## Environment Promotion

A typical promotion flow:

```bash
# Plan and apply against the target environment's tfvars
terraform plan  -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

Validate the deployment by uploading a sample document to the input bucket and
confirming the Step Functions execution reaches SUCCEEDED and writes results to
the output bucket. Run the same check after promoting to each new environment.

## Backup and Recovery

- Enable versioning on the S3 bucket that stores Terraform state, and use a
  DynamoDB lock table (see [Best Practices](best-practices.md)).
- The tracking table is provisioned by the module; if you need point-in-time
  recovery or cross-region copies of the document buckets, configure those on the
  buckets you own.

---

Next: [Monitoring Setup](monitoring.md) | [Best Practices](best-practices.md)
