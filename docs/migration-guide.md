# Migration Guide: v0.4.8-tf.0 → v0.4.16-tf.1

This guide covers the two breaking changes introduced in v0.4.16-tf.1.

---

## Breaking Change 1: SageMaker A2I Removed from `human-review` Module

### What changed

All SageMaker A2I resources have been removed from `modules/human-review/`:

- `aws_sagemaker_flow_definition`
- `aws_sagemaker_human_task_ui`
- `create_a2i_resources` Lambda function and IAM role
- `get-workforce-url` Lambda function and IAM role
- Associated SSM parameters and null_resource triggers

The `enable_hitl` and `private_workteam_arn` input variables are also removed from `human-review`.

HITL is now built into `processing-environment-api` as a single `complete_section_review` Lambda
that handles `claimReview`, `releaseReview`, `skipAllSectionsReview`, and `completeSectionReview`
via fieldName dispatch. It is controlled by `enable_hitl` in `processing-environment-api`
(default: `true`).

### Migration steps

**Step 1: Remove A2I state before upgrading**

Before running `terraform apply` with the new version, remove the A2I resources from Terraform
state. Replace `<module_path>` with your actual module address (e.g. `module.human_review[0]`):

```bash
terraform state rm '<module_path>.module.human_review[0].aws_sagemaker_flow_definition.hitl'
terraform state rm '<module_path>.module.human_review[0].aws_sagemaker_human_task_ui.hitl'
terraform state rm '<module_path>.module.human_review[0].aws_lambda_function.create_a2i_resources'
terraform state rm '<module_path>.module.human_review[0].aws_lambda_function.get_workforce_url'
terraform state rm '<module_path>.module.human_review[0].aws_iam_role.create_a2i_resources'
terraform state rm '<module_path>.module.human_review[0].aws_iam_role.get_workforce_url'
```

> **Note**: The actual SageMaker A2I resources in AWS will NOT be deleted by these state rm
> commands — they are simply removed from Terraform management. Delete them manually via the
> AWS Console or CLI if desired.

**Step 2: Remove `enable_hitl` and `private_workteam_arn` from `human-review` module calls**

If you pass `enable_hitl` or `private_workteam_arn` to the `human-review` module directly,
remove those arguments. Passing them will now cause `terraform validate` to fail.

**Step 3: Configure HITL in `processing-environment-api`**

HITL is enabled by default (`enable_hitl = true`). To disable it:

```hcl
module "processing_environment_api" {
  # ...
  enable_hitl = false
}
```

Or via the root module's `api` variable:

```hcl
api = {
  enable_hitl = false
  # ...
}
```

---

## Breaking Change 2: `base_layer_arn` Required Input Variable

### What changed

All processor modules and `processing-environment-api` now require a `base_layer_arn` input
variable. This ARN points to the shared base Lambda layer built by `processing-environment`.

### Migration steps

**If using the root module** (recommended): No action required. The root module automatically
wires `module.processing_environment.base_layer_arn` to all downstream modules.

**If calling processor modules directly**, add `base_layer_arn` to each module call:

```hcl
module "bedrock_llm_processor" {
  source = "path/to/modules/processors/bedrock-llm-processor"

  # Add this line — get the value from your processing-environment module output
  base_layer_arn = module.processing_environment.base_layer_arn

  # ... other variables
}

module "processing_environment_api" {
  source = "path/to/modules/processing-environment-api"

  # Add this line
  base_layer_arn = module.processing_environment.base_layer_arn

  # ... other variables
}
```

The `base_layer_arn` variable has a `null` default, so omitting it will not cause a validation
error — but Lambda functions will run without the shared layer, which may cause import errors
at runtime. It is strongly recommended to always provide this value.

---

## New Optional Features

The following new features are opt-in (disabled by default) and require no migration action:

| Feature | Variable | Default |
|---------|----------|---------|
| Capacity planning | `api.enable_capacity_planning` | `false` |
| OmniAI OCR Benchmark dataset | `api.enable_omni_ai_dataset` | `false` |
| DocSplit RVL-CDIP-NMP dataset | `api.enable_docplit_poly_seq_dataset` | `false` |
| Rule validation (Pattern 2) | `bedrock_llm_processor.enable_rule_validation` | `false` |
| Lambda hook inference (Pattern 2) | `bedrock_llm_processor.lambda_hook_*` | `""` |
| BDA sync | `api.bda_project_arn` | `""` |

HITL is enabled by default (`api.enable_hitl = true`) — see Breaking Change 1 above.

---

## Pattern 3 Deprecation

The SageMaker UDOP processor (Pattern 3) is deprecated as of v0.4.16 and will be removed in
v0.5.0. A `check` block in the module emits a deprecation warning on every `terraform plan`
and `terraform apply`.

To migrate from Pattern 3:
- **Pattern 1 (BDA)**: Use `modules/processors/bda-processor/` for standard document types
- **Pattern 2 (Bedrock LLM)**: Use `modules/processors/bedrock-llm-processor/` for custom extraction
