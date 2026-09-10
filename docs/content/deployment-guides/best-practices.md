# Best Practices

This guide covers recommended practices for deploying and operating the GenAI IDP Accelerator with Terraform.

The accelerator's root module consumes infrastructure you provide (S3 buckets, a
KMS key, and optionally VPC subnets and security groups) and configures the
processing stack through a set of typed variable objects (`processor`, `api`,
`web_ui`, `evaluation`, `reporting`, and others). It does not create the input,
output, and working buckets or the VPC for you. The examples under `examples/`
show a complete surrounding setup you can copy.

## Deployment Best Practices

### Environment Management

Keep separate Terraform workspaces or state keys per environment, and use a
distinct `prefix` per deployment so resource names do not collide:

```hcl
prefix = "genai-idp-dev"
region = "us-east-1"

log_level          = "INFO"
log_retention_days = 7
tags = {
  Environment = "dev"
  Project     = "genai-idp-accelerator"
}
```

For lower-cost non-production deployments, disable the optional subsystems you do
not need (they default off unless noted): keep `evaluation`, `reporting`, and the
optional `api` features off, and only enable `web_ui` when you need the console.

### State Management

Use a remote state backend with locking:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-<your-suffix>"
    key            = "idp-accelerator/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Security Best Practices

### Encryption

Provide a KMS key and set `enable_encryption` so the module encrypts the
resources it manages:

```hcl
encryption_key_arn = aws_kms_key.idp.arn
enable_encryption  = true
```

`enable_encryption` is a separate boolean (rather than deriving from
`encryption_key_arn != null`) so the value is known at plan time and does not
cause count/for_each unknown-value errors.

### Data Protection

- Enable versioning and server-side encryption on the S3 buckets you pass in as
  `input_bucket_arn`, `output_bucket_arn`, and `working_bucket_arn`.
- Set `data_tracking_retention_days` to control how long tracking data is kept.
- Use `deletion_protection = true` (the default) to protect Cognito resources.

### Private Networking

The module does not create a VPC. To run the Lambdas inside your own VPC, pass
existing subnets and security groups, and use `private_network` for a
VPC-isolated API and Web UI posture:

```hcl
vpc_subnet_ids         = ["subnet-...", "subnet-..."]
vpc_security_group_ids = ["sg-..."]
```

See the `bedrock-llm-processor-vpc` example for a complete VPC-isolated
deployment (private API Gateway, S3 VPC endpoint, ALB or API Gateway Web UI
hosting).

## Performance Best Practices

- Tune per-step model choices with the `processor` model overrides
  (`classification_model_id`, `extraction_model_id`, `assessment_model_id`) to
  balance latency, cost, and accuracy.
- Adjust worker concurrency where the processor exposes it (for example the
  SageMaker UDOP processor's `ocr_max_workers` / `classification_max_workers`).
- Set `lambda_tracing_mode` to `Active` to trace with X-Ray while tuning, and
  back to `PassThrough` for steady state if you prefer.
- Prefer AWS CodeBuild for layer builds (the default). For faster local
  iteration, the `build` object supports building layers and the Web UI locally
  (see the local-build deployment guides).

## Monitoring Best Practices

- Use `log_level` and `log_retention_days` to control Lambda log verbosity and
  retention.
- The monitoring module provisions CloudWatch dashboards and alarms for the
  processing stack. Review its alarms after each release and wire alarm actions
  to your own SNS topic.

## Operational Best Practices

### Deployment Process

1. Run `terraform plan` and review the changes.
2. Test in a non-production account first.
3. Monitor the Step Functions executions and CloudWatch metrics after apply.

### Configuration Management

Processing behaviour (document classes, prompts, models, rule validation) is
driven by the config passed on `processor.config` and seeded into the
configuration table. The seeder preserves operator edits made in the Web UI: it
stamps a provenance marker per seeded version and only re-seeds a row that still
matches what Terraform last wrote. To reassert Terraform's config over an
operator-edited row, delete that version's `TerraformSeed#<version>` marker item
and re-apply.

## Testing Best Practices

```bash
# Validate and format
terraform validate
terraform fmt -check

# Security scanning
tfsec .
```

The repository's `Makefile` wraps these with the project's exclusions
(`make validate`, `make lint`, `make security`).

## Troubleshooting

- **Permission errors**: check the IAM roles the module creates and the
  policies on the buckets and KMS key you passed in.
- **Service quotas**: check Bedrock model access and Lambda concurrency limits;
  request increases where needed.
- **State issues**: use `terraform plan` to detect drift; handle state lock
  conflicts before retrying.

### Debugging

```bash
export TF_LOG=DEBUG
terraform apply
```

---

For more detailed information, see:

- [Environment Setup](environment-setup.md)
- [Monitoring Guide](monitoring.md)
- [Troubleshooting Guide](troubleshooting.md)
