# Migration Guide: v0.3.18-tf.1 → v0.4.8-tf.0

This guide covers the four breaking changes introduced in v0.4.8-tf.0 and the steps required to migrate existing deployments.

---

## Before You Begin

1. Back up your Terraform state: `terraform state pull > state-backup.json`
2. Review the full CHANGELOG for all new variables and features
3. Run `terraform plan` after each migration step to verify expected changes

---

## Breaking Change 1: Configuration Format (JSON Schema Draft 2020-12)

### What Changed

The upstream IDP now uses JSON Schema Draft 2020-12 for extraction field schemas. The `idp_common_pkg` library auto-migrates existing YAML configs at runtime.

### Impact

No HCL changes required. Your existing `config.yaml` files continue to work. The runtime library handles migration transparently.

### Optional: Explicit Migration

To migrate configs explicitly (recommended for production):

```bash
# From the CloudFormation repo at v0.4.8
python -m idp_common.config.migrate --input config.yaml --output config-v2.yaml
```

See `docs/json-schema-migration.md` in the upstream repo for the full schema reference.

---

## Breaking Change 2: Evaluation Moved from EventBridge to Step Functions

### What Changed

Evaluation is now triggered as a `EvaluateDocument` state in the Step Functions workflow, not via an EventBridge rule. The evaluation Lambda ARN is passed directly into the state machine definition via `templatefile()`.

### Migration Steps

**Step 1**: If you have existing EventBridge rules for evaluation, remove them from your state before upgrading:

```bash
# List any evaluation-related EventBridge rules
terraform state list | grep cloudwatch_event_rule

# Remove them from state (they will be deleted on next apply)
terraform state rm aws_cloudwatch_event_rule.evaluation_trigger
terraform state rm aws_cloudwatch_event_target.evaluation_target
```

**Step 2**: Add `evaluation_baseline_bucket_arn` to your processor module call if you want evaluation enabled:

```hcl
module "bedrock_llm_processor" {
  source = "../../modules/processors/bedrock-llm-processor"
  # ...
  evaluation_baseline_bucket_arn = aws_s3_bucket.evaluation_baseline.arn
}
```

**Step 3**: For Pattern 3 (SageMaker UDOP), the evaluation Lambda is always created. If you previously had no evaluation configured, a no-op Lambda will be created — this is expected and harmless.

---

## Breaking Change 3: Pattern 1 and Pattern 3 Lambda → Docker Image Deployment

### What Changed

`bda-processor` and `sagemaker-udop-processor` Lambda functions are now deployed as Docker images via ECR + CodeBuild, matching the Pattern 2 approach introduced in v0.3.20.

### Impact

- First `terraform apply` after upgrade will create an ECR repository and trigger a CodeBuild build
- The CodeBuild build takes approximately 10–15 minutes on first run
- Subsequent applies only rebuild when Lambda source code changes

### Migration Steps

**Step 1**: Ensure your AWS account has sufficient ECR quota (default: 10,000 repositories per region).

**Step 2**: The CodeBuild project requires Docker-in-Docker (`privileged_mode = true`). If your account has SCP restrictions on privileged CodeBuild, request an exception before upgrading.

**Step 3**: Apply the upgrade. Terraform will:

1. Create the ECR repository
2. Create the CodeBuild project
3. Trigger an initial build via `null_resource`
4. Wait for the image to be available
5. Update the Lambda function to use the new image URI

**Step 4** (optional): Add `enable_ecr_image_scanning = true` to enable ECR vulnerability scanning:

```hcl
module "bda_processor" {
  source = "../../modules/processors/bda-processor"
  # ...
  enable_ecr_image_scanning = true  # default: true
}
```

---

## Breaking Change 4: Web UI Environment Variables (VITE_* prefix)

### What Changed

All `REACT_APP_*` CodeBuild environment variables have been renamed to `VITE_*` to match the Vite 7 build system. `VITE_CLOUDFRONT_DOMAIN` has been added.

### Impact

If you have custom buildspec overrides or CI/CD pipelines that reference `REACT_APP_*` variables, update them before upgrading.

### Migration Steps

**Step 1**: Search your codebase for any `REACT_APP_` references:

```bash
grep -r "REACT_APP_" .
```

**Step 2**: Replace with the corresponding `VITE_` variable:

| Old Variable | New Variable |
|-------------|-------------|
| `REACT_APP_API_ENDPOINT` | `VITE_API_ENDPOINT` |
| `REACT_APP_USER_POOL_ID` | `VITE_USER_POOL_ID` |
| `REACT_APP_USER_POOL_CLIENT_ID` | `VITE_USER_POOL_CLIENT_ID` |
| `REACT_APP_REGION` | `VITE_REGION` |
| *(new)* | `VITE_CLOUDFRONT_DOMAIN` |

**Step 3**: The CodeBuild image has been updated to `amazonlinux2-x86_64-standard:5.0` (Node 22.x). If you have pinned the image version in a custom buildspec, update it.

---

## New Optional Features

After completing the migration, you can opt into new features by adding variables to your module calls:

### Agent Companion Chat (enabled by default)

```hcl
module "processing_environment_api" {
  # ...
  enable_agent_companion_chat = true  # default
}
```

### Test Studio (enabled by default)

```hcl
module "processing_environment_api" {
  # ...
  enable_test_studio  = true   # default
  enable_fcc_dataset  = false  # opt-in: deploy sample FCC dataset
}
```

### Error Analyzer (enabled by default)

```hcl
module "processing_environment_api" {
  # ...
  enable_error_analyzer = true  # default
  state_machine_arn     = module.bedrock_llm_processor.state_machine_arn
}
```

### MCP Integration (opt-in, disabled by default)

```hcl
module "processing_environment_api" {
  # ...
  enable_mcp   = true  # requires explicit opt-in
  user_pool_id = module.user_identity.user_pool_id
}
```

### Agentic Extraction for Pattern 2 (opt-in)

```hcl
module "bedrock_llm_processor" {
  # ...
  enable_agentic_extraction = true
}
```

### Section Splitting for Pattern 2

```hcl
module "bedrock_llm_processor" {
  # ...
  section_splitting_strategy = "page"  # or "llm_determined"
}
```

---

## Rollback

If you need to roll back to v0.3.18-tf.1:

1. Restore your state backup: `terraform state push state-backup.json`
2. Check out the v0.3.18-tf.1 tag in the Terraform repo
3. Run `terraform plan` to verify the rollback plan
4. Run `terraform apply` — note that ECR repositories and CodeBuild projects created during the upgrade will be destroyed

> **Warning**: Rolling back after evaluation data has been written to the new Step Functions workflow may result in data loss. Back up your DynamoDB tracking table before rolling back.
