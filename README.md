# GenAI IDP Accelerator for Terraform

> [!WARNING]
> **This repository is deprecated and is no longer actively developed.**
> Terraform is now a first-class deployment option of the
> [GenAI IDP Accelerator](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws),
> shipped and tested with every release starting from **v0.6.15**.
>
> - New deployments: follow the [Terraform user guide](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform.md).
> - Existing deployments of this repository: follow the
>   [migration guide](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform-migration.md)
>   (`idp-cli terraform migrate-from-genai-idp-terraform`), which keeps your buckets, tables, KMS key and
>   Cognito users (including passwords).
> - Questions, bugs and feature requests belong in the
>   [successor repository's issues](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/issues).
>
> See [Deprecation & migration](#deprecation--migration) for the full rationale, migration summary and caveats.

A modular Terraform implementation of the GenAI **Intelligent Document Processing** (IDP) Accelerator, designed to transform unstructured documents into structured data at scale using AWS's latest AI/ML services.

## Overview

This project provides a Terraform-based implementation of the [GenAI **Intelligent Document Processing** Accelerator](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws), offering flexible deployment options and infrastructure-as-code management for **Intelligent Document Processing** workflows.

## Deprecation & migration

### Why this repository is deprecated

This repository existed to bring Terraform support to the GenAI IDP Accelerator before upstream offered
it: each upstream release was pinned as an immutable submodule under `sources/` and reimplemented as
Terraform modules on top — a "catch-up" model.

Since upstream **v0.6.15** (released 2026-11-13), the Accelerator generates a Terraform module from its
own CloudFormation templates and publishes it with every release. Every upstream pull request checks the
translation and compares a security scan of each Terraform resource with its CloudFormation source. A
separate catch-up repository is therefore no longer needed, and would only lag behind upstream.

Terraform support in upstream v0.6.15 is labelled **Experimental**: the module has been deployed end to
end and has passed upstream's integration suite, but it has had far less use than the CloudFormation
templates. The Terraform user guide lists
[how the translation is checked](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform.md#how-the-translation-is-checked)
and its
[current limitations](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform.md#differences-from-cloudformation-and-current-limitations).

### Status of this repository

- **No new features.** The last release is `0.6.9-tf.0`, wrapping upstream IDP v0.6.9.
- **No further upstream catch-up.** Upstream releases after v0.6.9 are not and will not be wrapped here.
- **Existing deployments keep working.** Nothing is withdrawn; the code at the last tag still deploys.
  There will be no fixes for upstream changes, however, so migration is the supported path forward.

<!-- TODO(owner decision): support policy — critical security fixes until YYYY-MM-DD / none; archive date -->

### Where to go instead

| What you need | Where |
|---|---|
| Deploy with Terraform (new deployments) | [Terraform user guide](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform.md) |
| Migrate an existing deployment of this repository | [Migration guide](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform-migration.md) |
| `idp-cli` reference (`--terraform`, `terraform migrate-from-genai-idp-terraform`) | [idp-cli docs](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/idp-cli.md) |
| How the Terraform is generated (translator, gates, overrides) | [Developer docs](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/terraform/README.md) |
| Overview and demo video | [Terraform overview](https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws/terraform/) |
| Issues, questions, feature requests | [Successor repository issues](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/issues) |

### Migration path (summary)

Upstream ships an in-place migration from this repository,
`idp-cli terraform migrate-from-genai-idp-terraform`. A new deployment of the upstream module adopts your
existing S3 buckets, DynamoDB tables, KMS key and Cognito user pool, so documents, results,
configuration, users and their passwords stay where they are. Everything else (functions, queues, the
state machine, the web UI, the knowledge base) is created afresh by the new deployment and destroyed with
the old one.

Upstream tests the migration end to end, as part of its release validation, from this repository's
`v0.6.9-tf.0` tag using the `examples/unified-processor` configuration. The other example configurations
have not been tried, so rehearse the migration in a non-production account first. If you run an older
release of this repository, upgrade to `v0.6.9-tf.0` before migrating; the
[0.6.4 to 0.6.9 notes](docs/migration-v0.6.4-to-v0.6.9.md) involve no state migration.

The [migration guide](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform-migration.md)
is the procedure. This summary only shows its shape, so take commands and flags from the guide.

**Before you start** you need Terraform 1.7 or later (or OpenTofu), `idp-cli` from the successor
repository, and the upstream module at **v0.6.15 or later**: an older module would replace the Cognito
user pool, deleting every user, and the migration refuses to apply it. You also need access to the old
deployment's directory and state, a maintenance window, and backups you can restore without either
Terraform state: an on-demand DynamoDB backup of each adopted table, a copy of any bucket data you cannot
afford to lose, and an export of any CloudWatch logs you need, since those are destroyed with the old
deployment.

Each phase is a dry run until you pass `--apply`, and each prints how to undo its own change:

| Phase | What it does |
|---|---|
| `plan` | Maps every resource in the old state to adopt, recreate or keep, and writes the `import` blocks. Changes nothing in AWS. |
| `check-retention` | Fails for each kept bucket holding objects older than the expiry rule the new module would put on it. |
| `freeze` | Disables the old deployment's upload rule, then reports the documents still in flight and can wait for them. |
| `fix-config` | Backs up your configuration rows and removes the revision counters that would let the first deploy overwrite them. |
| `adopt-user-pool` | Imports the user pool and aligns its schema in state, so the first apply does not fail. |
| `apply` | Plans, checks and applies the adoption. |
| `restore-config` | Restores any configuration profile the first deploy replaced. |
| `detach` | After you have verified the new deployment, removes everything the migration keeps from the old state. |
| `check-destroy` | Confirms the old deployment's destroy plan deletes nothing the migration kept, before you run it. |

In upstream's measured run the whole sequence took about 2 hours 45 minutes, including a wait of about an
hour that DynamoDB imposes (see the first caveat below).

### Known migration caveats

From upstream's [migration guide](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform-migration.md#hazards):

- **Two features are not handled yet.** If you enabled fine-tuning (`api.enable_finetuning`) or external
  identity provider federation (`idp_federation.enabled`, which creates a Cognito hosted-UI domain),
  `plan` refuses and writes nothing. Upstream's
  [side-by-side cutover](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/docs/terraform-migration.md#fallback-side-by-side-cutover)
  is the alternative; it keeps no resources and copies the data across instead.
- **Turn off the agent jobs table's time-to-live at least an hour before `apply`.** This repository's
  table expires rows on `expiresAfter`, and the new module uses `ExpiresAfter`. DynamoDB cannot move
  time-to-live to another attribute while it is on, and refuses a second change within about an hour of
  the first, so an `apply` run too soon fails part way through. `apply` prints the command and asks you
  to accept the change explicitly. Nothing else depends on the setting, so do this before the maintenance
  window. Rows written before the migration no longer expire.
- **Expiry rules apply to the objects you already have.** By default the new module expires objects
  after 365 days in the input, output, test-set and discovery buckets (`DataRetentionInDays`), after 30
  days in the working bucket (`LogRetentionDays`), and after a fixed 180 days in the access-log bucket.
  `check-retention` tells you what that would delete.
- **Never run `terraform apply` in the old deployment after `freeze`.** It would turn the upload rule
  back on and rewrite settings on resources the new deployment now owns. After `detach`, the old
  deployment may only be destroyed.
- **Usernames are case-sensitive** on the adopted user pool, including the admin username you pass to
  `plan`.
- **Finish or reject pending human reviews in the old web UI before `freeze`.** Whether the new
  deployment can complete a review the old one started has not been verified.
- **Some history does not carry over:** discovery jobs, test-set definitions (their documents stay in the
  adopted bucket), installed features, and the knowledge base index. The new knowledge base starts empty;
  re-sync it from the adopted output bucket.

From operating this repository:

- **Destroying the old deployment can reset the region's API Gateway account setting.** With `log_level`
  at `INFO` or `DEBUG` (the default is `INFO`), this repository manages `aws_api_gateway_account`, the
  per-region setting that names the CloudWatch role API Gateway logs with. The migration destroys it with
  the old deployment. With AWS provider v6 that always resets the setting, whichever deployment set it
  last; with v5 the setting can be left naming a role the same destroy deletes. Either way, CloudWatch
  logging stops for every REST API in that account and region that relies on the setting. After the
  destroy, check `aws apigateway get-account`. If `cloudwatchRoleArn` is missing or names a deleted role
  and anything in that region logs through it, set it again: running `terraform apply` once more in the
  new deployment does this when its `LogLevel` is `INFO` or `DEBUG` (upstream's default is `WARN`);
  otherwise point it at a role of your own.

### Acknowledgements

Thanks to **Grzegorz Ciupryk** and **Rafał Pawlaszek**, who built and maintained the bulk of this
implementation, and to everyone who filed issues, reported bugs and ran this in their own accounts — your
reports shaped every release here.

Thanks to **Bob Strahan** and the GenAI IDP Accelerator team for taking Terraform on as a first-class,
tested deployment option upstream, and for building a migration path off this repository rather than
leaving its users stranded.

## Experimental Status

This solution is in experimental stage. While it implements security best practices, conduct thorough testing and security review before production use.

## Versioning

This repository uses a dual-version scheme to track both the upstream IDP solution and the Terraform implementation:

- **`IDP_VERSION`**: Tracks the upstream [GenAI IDP Accelerator](https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws) version
- **`VERSION`**: Tracks this Terraform implementation using the format `{IDP_VERSION}-tf.{TERRAFORM_VERSION}`

### Current Version

The current release is **`0.6.9-tf.0`** (compatible with upstream IDP v0.6.9). See [`CHANGELOG.md`](CHANGELOG.md) for the full history and upgrade notes.

### Version Format Examples

| VERSION | Meaning |
|---------|---------|
| `0.3.18-tf.1` | IDP v0.3.18, initial Terraform release |
| `0.4.8-tf.0` | IDP v0.4.8, initial Terraform release |
| `0.4.16-tf.2` | IDP v0.4.16, sagemaker-udop fixes |
| `0.5.12-tf.0` | IDP v0.5.12, façade processors, feature-plugins, RBAC/federation/VPC, parity drop-ins |
| `0.5.16-tf.0` | IDP v0.5.16, opt-in local build path for Lambda layers, processor images, and the web UI (`var.build`) |
| `0.6.4-tf.0` | IDP v0.6.4, single `processor` variable, API Gateway REST transport replacing AppSync, models and pipeline features driven by the YAML config |
| `0.6.9-tf.0` | IDP v0.6.9 (current) |

The Terraform version (`tf.X`) resets to `0` when the upstream IDP version changes.

### Key Features

- **Modular Architecture**: Reusable Terraform modules for flexible composition
- **One Engine, Several Patterns**: a single unified processor, with optional façades for BDA, Bedrock LLM, and SageMaker UDOP classification
- **Serverless Design**: Built on AWS Lambda, Step Functions, and other serverless technologies
- **Security First**: KMS encryption, IAM least privilege, and VPC support with comprehensive security fixes
- **Comprehensive Monitoring**: Built-in CloudWatch dashboards and alerting
- **Web Interface**: Optional React-based UI for document management
- **Knowledge Base**: Query processed documents using natural language
- **Document Discovery**: Upload and analyze documents for pattern discovery
- **Chat with Documents**: Interactive Q&A with processed documents using foundation models
- **Enhanced Permissions**: Comprehensive IAM policies aligned with AWS security best practices

## Processing Patterns

All document processing runs on one engine, the **unified processor**. The three
pattern modules below are thin façades over it, each preconfiguring the engine for
a particular classification approach.

### Unified Processor (the main processor)

- **Best for**: most deployments, including all three patterns below
- **Processing**: the single Step Functions pipeline that every pattern executes
- **Setup**: fully automated; the document classes and extraction logic come from your YAML config
- **Customization**: the whole pipeline is config-driven, so one deployment can serve several document types
- **Use it directly** unless you specifically need a façade's preconfiguration. This
  is the example the CI pipeline deploys and validates on every change.

The three façades each instantiate `modules/processors/unified-processor` as their
engine and differ only in how documents get classified:

### Pattern 1: BDA Processor (Bedrock Data Automation)

- **Best for**: Standard document types with well-defined schemas
- **Processing**: Managed service with built-in document understanding
- **Setup**: Requires existing BDA project configuration
- **Customization**: Schema-based with predefined document classes
- **Recent Updates**: Enhanced permissions for DynamoDB, SSM Parameter Store, and Bedrock Data Automation APIs

### Pattern 2: Bedrock LLM Processor

- **Best for**: Custom document types requiring flexible extraction
- **Processing**: Multi-stage pipeline with foundation models (Claude, Nova)
- **Setup**: Fully automated deployment
- **Customization**: Complete control over classification and extraction logic

### Pattern 3: SageMaker UDOP Processor

- **Best for**: Specialized document processing with custom models
- **Processing**: Fine-tuned UDOP models for classification + Bedrock for extraction
- **Setup**: Requires trained UDOP model artifacts
- **Customization**: Custom model training and deployment

## Repository Structure

```
genai-idp-terraform/
├── modules/                           # Reusable Terraform modules
│   ├── processors/                    # Document processing
│   │   ├── unified-processor/        # The processing engine (main); the three below wrap it
│   │   ├── bda-processor/            # Façade, Pattern 1: Bedrock Data Automation
│   │   ├── bedrock-llm-processor/    # Façade, Pattern 2: Bedrock LLM Processing
│   │   └── sagemaker-udop-processor/ # Façade, Pattern 3: SageMaker UDOP Processing
│   ├── processing-environment/        # Core processing infrastructure
│   ├── processing-environment-api/    # REST API for status tracking
│   ├── web-ui/                       # React-based web interface
│   ├── knowledge-base/               # Vector database for RAG
│   └── [supporting modules]/         # Additional infrastructure components
├── examples/                         # Complete deployment examples
│   ├── unified-processor/           # Main example; deployed and validated by CI
│   ├── bda-processor/               # BDA processor deployment
│   ├── bedrock-llm-processor/       # Bedrock LLM processor deployment
│   ├── sagemaker-udop-processor/    # SageMaker UDOP processor deployment
│   └── [other examples]/           # Additional example configurations
└── sources/                         # Original CDK implementation (reference only)
```

## Recent Security Enhancements

Based on comprehensive security analysis and AWS best practices, the solution now includes:

### Enhanced IAM Permissions

- **DynamoDB**: Full CRUD operations for tracking and configuration tables
- **SSM Parameter Store**: Secure parameter management with GetParameter, PutParameter, and GetParametersByPath
- **Bedrock Data Automation**: Complete API access including GetDataAutomationProject, ListDataAutomationProjects, GetBlueprint, and GetBlueprintRecommendation
- **S3 Enhanced Permissions**: Full CRUD operations including DeleteObject and GetBucketLocation for comprehensive bucket management

### Conditional HITL (Human-in-the-Loop) Support

- **Modular HITL Policies**: Separate conditional policies for Human-in-the-Loop functionality
- **Optional BDA Metadata Table**: Configurable access to BDAMetadataTable based on deployment requirements
- **Environment Variable Consistency**: Standardized CONFIGURATION_TABLE_NAME across all Lambda functions

### Security Architecture Improvements

- **Least Privilege Access**: IAM policies follow principle of least privilege with specific resource ARNs
- **Conditional Resource Access**: HITL functionality deployed only when required using Terraform for_each patterns
- **Resource Separation**: Clear separation between core processing permissions and optional HITL permissions

## Prerequisites

Before deploying the solution, ensure you have:

### Required Tools

- **[Terraform](https://www.terraform.io/)**: Version 1.0 or later
- **[AWS CLI](https://aws.amazon.com/cli/)**: Configured with appropriate credentials
- **Container runtime (optional)**: [Docker](https://www.docker.com/), [Podman](https://podman.io/),
  or [Finch](https://runfinch.com/) is required **only if** you opt into local Lambda
  builds via `build.lambda_local = true`. By default the wrapper builds Lambda
  artifacts in AWS CodeBuild and the deploy host needs no container runtime.
  See [docs/content/deployment-guides/local-lambda-build.md](docs/content/deployment-guides/local-lambda-build.md).

### How this repository must be obtained

`sources/` is a git submodule pinned to an upstream IDP release tag. That decides
which consumption paths work:

| Path | Works | Notes |
|---|---|---|
| `git clone --recursive` | yes | or `git submodule update --init` after a plain clone |
| Terraform module with a `git::` source | yes | Terraform initialises submodules recursively, no extra step |
| Source archive: release zip, tarball, registry package | **no** | archives cannot carry a submodule, so `sources/` arrives empty |

The archive limitation is a property of git and of archive formats, not something
this repository can work around. Use a git clone or a `git::` module source.

### AWS Requirements

- **AWS Account**: With appropriate permissions for all services used
- **Bedrock Model Access**: automatic, but Anthropic models need a one-time use-case submission (see below)
- **Service Quotas**: Ensure adequate quotas for Lambda, Step Functions, etc.

### Bedrock Model Access

You no longer request access to each model. Since September 2025 Bedrock enables
all serverless foundation models automatically in every commercial Region, so the
old "Model access" checkbox flow is gone. See
[Request access to models](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html).

Two prerequisites still apply, and both are one-time:

- **Anthropic first-time use**: Anthropic requires use-case details once per
  account (or once at the organization's management account) before you invoke a
  Claude model. Submit them by opening any Anthropic model in the Bedrock console
  catalog, or by calling `PutUseCaseForModelAccess`. Access is granted immediately
  on submission. This example defaults to Claude, so it applies to a default
  deployment.
- **AWS Marketplace permissions**: the invoking role needs
  `aws-marketplace:Subscribe`, `aws-marketplace:Unsubscribe` and
  `aws-marketplace:ViewSubscriptions`. Bedrock subscribes to third-party models on
  first invocation, and without these the subscription fails and calls return
  `AccessDeniedException`.

On the very first invocation of a third-party model the subscription completes in
the background, usually within 15 minutes, so early calls can fail before it
settles. Neither step can be automated through Terraform.

## Quick Start

> ### Clone with submodules
>
> `sources/` is a **git submodule** pinned to the upstream IDP release this wrapper
> wraps, rather than a copy of it. A plain `git clone` leaves it empty and every
> Lambda build then fails.
>
> ```bash
> git clone --recursive https://github.com/awslabs/genai-idp-terraform.git
> ```
>
> Already cloned without it:
>
> ```bash
> git submodule update --init
> ```
>
> `terraform plan` fails early with a message naming this if the submodule is
> missing, so you will not be left guessing.

### 1. Choose Your Example

Start with the unified processor unless you need a façade's preconfiguration:

```bash
# The main processor: config-driven, covers most use cases (start here)
cd examples/unified-processor

# Façade for standard documents with an existing BDA project
cd examples/bda-processor

# Façade for Bedrock LLM classification
cd examples/bedrock-llm-processor

# Façade for specialized processing with custom UDOP models
cd examples/sagemaker-udop-processor
```

### 2. Configure Your Deployment

Copy and customize the example configuration:

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your specific values
nano terraform.tfvars
```

**Minimal configuration example**:

```hcl
# terraform.tfvars
region      = "us-east-1"
prefix      = "my-idp"
admin_email = "you@example.com"

tags = {
  Environment = "development"
  Project     = "document-processing"
}
```

### 3. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 4. Access Your Deployment

After deployment, Terraform will output important information:

```bash
# View deployment outputs
terraform output

# Example outputs:
# web_ui_url   = "https://d1234567890.cloudfront.net"
# input_bucket = "my-idp-input-documents-abc123"
# name_prefix  = "my-idp-ab12cd34"
```

## Usage Examples

### Upload and Process Documents

Once deployed, you can process documents in several ways:

#### 1. Web Interface (Recommended)

- Navigate to the `web_ui_url` from your Terraform outputs
- Upload documents through the drag-and-drop interface
- Monitor processing status in real-time
- View and download extraction results

#### 2. Direct S3 Upload

```bash
# Upload a document to trigger processing
aws s3 cp my-document.pdf s3://your-input-bucket/
```

#### 3. Programmatic Upload

```python
import boto3

s3 = boto3.client('s3')
s3.upload_file('local-document.pdf', 'your-input-bucket', 'documents/document.pdf')
```

### Monitor Processing

```bash
# Check Step Functions executions
aws stepfunctions list-executions --state-machine-arn <state-machine-arn>

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/your-prefix"
```

## Configuration Options

### Basic Configuration

```hcl
# terraform.tfvars
region      = "us-east-1"
prefix      = "my-idp"
admin_email = "you@example.com"

# Per-stage model IDs live in the YAML config, not in tfvars. Point this at a
# config from sources/config_library/unified/ or your own copy, and set the
# models inside it. Defaults to the lending package sample.
config_file_path = "../../sources/config_library/unified/lending-package-sample/config.yaml"

# Optional. The models your config references are granted automatically; list
# extras here only if something invokes a model the config does not name.
allowed_bedrock_model_ids = []

# Logging
log_level          = "INFO"
log_retention_days = 30

# Build strategy (CodeBuild by default; flip to local-build via tfvars)
# See docs/content/deployment-guides/local-lambda-build.md.
build = {
  lambda_local        = false      # set to true for host-side Docker builds
  lambda_architecture = "x86_64"   # or "arm64" for Graviton Lambdas
  container_runtime   = "auto"     # auto-detect docker/podman/finch
}
```

### Local Lambda Build

The default deploy path uses AWS CodeBuild to build Lambda layer zips and
processor container images. Set `build.lambda_local = true` to instead
build artifacts on the deploy host using Docker, Podman, or Finch. This
drops the per-apply CodeBuild cost and shortens iteration time from
minutes to seconds, at the cost of needing a container runtime on your
machine. The flag is non-breaking; defaults preserve the historical
behavior.

See [docs/content/deployment-guides/local-lambda-build.md](docs/content/deployment-guides/local-lambda-build.md)
for prerequisites, architecture selection, and migration guidance.

### Advanced Configuration

These are the toggles `examples/unified-processor` exposes. Pipeline behaviour
such as classification method, extraction limits and summarization comes from the
YAML config rather than from tfvars.

```hcl
# Subsystems, each default-off unless noted
create_knowledge_base       = true   # Bedrock Knowledge Base + OpenSearch Serverless
create_discovery            = true   # document discovery pipeline
chat_with_document_enabled  = true
enable_evaluation           = true   # also needs evaluation.enabled in the config
enable_agent_companion_chat = true
enable_agent_analytics      = true   # requires reporting
enable_mcp                  = true
enable_test_studio          = true
enable_finetuning           = true   # requires enable_test_studio

# Web UI (on by default). Set enabled = false to deploy the backend only.
web_ui = {
  enabled         = true
  logging_enabled = true
}

# Role-based access control (off by default)
rbac = {
  enabled = true
}

# Optional Bedrock guardrail applied to every model-invoking function
bedrock_guardrail_id_and_version = "your-guardrail-id:1"
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web UI        │    │    REST API      │    │  S3 Buckets     │
│  (CloudFront)   │◄──►│  (API Gateway)   │◄──►│  (Input/Output) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Step Functions Workflow                      │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   OCR           │ Classification  │      Extraction             │
│ (Textract)      │ (Bedrock/UDOP) │     (Bedrock)              │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Monitoring & Logging                       │
│              (CloudWatch Dashboards & Alarms)                  │
└─────────────────────────────────────────────────────────────────┘
```

## Security Features

### IAM Security Model

- **Least Privilege**: All IAM policies follow the principle of least privilege
- **Resource-Specific ARNs**: Policies reference specific resource ARNs rather than wildcards
- **Conditional Access**: HITL functionality requires explicit configuration to enable

### Data Protection

- **KMS Encryption**: All data encrypted at rest and in transit
- **VPC Support**: Optional VPC deployment for network isolation
- **Secure Parameter Management**: SSM Parameter Store for sensitive configuration

### Compliance & Monitoring

- **CloudWatch Integration**: Comprehensive logging and monitoring
- **AWS Config**: Resource compliance monitoring
- **CloudTrail**: API call auditing and tracking

## AWS Best Practices for Production

Before deploying this solution to production, consider implementing the following AWS best practices. These recommendations help ensure security, reliability, and cost optimization.

### Compute & Performance

- **Lambda Concurrent Execution Limits**: Configure reserved concurrency for each Lambda function to prevent runaway costs and protect downstream services. This solution currently has 43 Lambda functions without configured limits.
- **Lambda Dead Letter Queue (DLQ)**: Configure DLQ for Lambda functions to capture and analyze failed asynchronous invocations. This solution currently has 37 Lambda functions without configured DLQ.
- **Lambda VPC Configuration**: Configure Lambda functions inside a VPC when accessing private resources. This solution currently has 10 Lambda functions without VPC configuration. Note: Only required for functions accessing VPC resources.
- **Lambda Environment Variable Encryption**: Configure Lambda functions to encrypt environment variables using KMS customer-managed keys. This solution currently has 39 Lambda functions without environment variable encryption.
- **Lambda Code Signing**: Configure Lambda functions to validate code signatures to ensure code integrity. This solution currently has 46 Lambda functions without code-signing validation.
- *(Additional recommendations will be added here)*

### Security & Encryption

- **CodeBuild Encryption with CMK**: Configure CodeBuild projects to use customer-managed KMS keys for encrypting build artifacts, environment variables, and logs. This solution currently has 3 CodeBuild projects without CMK encryption.
- **CloudWatch Log Group Encryption**: Configure CloudWatch Log Groups to use KMS encryption for log data at rest. This solution currently has 7 CloudWatch Log Groups without KMS encryption.
- *(Additional recommendations will be added here)*

### Monitoring & Observability

- **CloudWatch Alarms**: Set up alarms for critical metrics and error rates
- **CloudWatch Log Retention**: Configure CloudWatch Log Groups with appropriate retention periods (minimum 1 year for production). This solution currently has 37 CloudWatch Log Groups without adequate retention.
- *(Additional recommendations will be added here)*

### Cost Optimization

- **Resource Tagging**: Implement comprehensive tagging strategy for cost allocation
- *(Additional recommendations will be added here)*

### Reliability & Resilience

- **Multi-AZ Deployment**: Deploy critical components across multiple availability zones
- **CloudFront Origin Failover**: Configure CloudFront with origin groups for automatic failover to secondary origins. This solution currently has 1 CloudFront distribution without origin failover.
- **CloudFront Geo Restriction**: Configure geo restrictions based on compliance and security requirements. This solution currently has 1 CloudFront distribution without geo restriction configured.
- *(Additional recommendations will be added here)*

For detailed guidance on implementing these best practices, see the [AWS Best Practices Documentation](docs/content/security/aws-best-practices.md).

## Documentation

### Comprehensive Documentation

This project includes comprehensive documentation built with Material for MkDocs, covering everything from getting started to advanced deployment scenarios.

#### Online Documentation

- **GitHub Pages**: [https://awslabs.github.io/genai-idp-terraform/](https://awslabs.github.io/genai-idp-terraform/)
- **Auto-deployed**: Updated automatically with each commit to main branch
- **Mobile-friendly**: Responsive design for all devices

#### Local Documentation

Run the documentation locally for development:

```bash
# Quick start (automated setup)
cd docs && ./serve.sh

# Manual setup
cd docs
pip install -r requirements.txt
mkdocs serve
```

Visit [http://127.0.0.1:8000](http://127.0.0.1:8000) to view the documentation.

#### Documentation Sections

- **[Getting Started](docs/content/getting-started/)**: Prerequisites, installation, and quick start
- **[Terraform Modules](docs/content/terraform-modules/)**: Detailed module documentation
- **[Examples](docs/content/examples/)**: Real-world implementation examples
- **[Deployment Guides](docs/content/deployment-guides/)**: Deployment best practices
- **[Security Guide](docs/content/security/)**: Security best practices and compliance
- **[FAQs](docs/content/faqs/)**: Common questions and troubleshooting
- **[Contributing](docs/content/contributing/)**: How to contribute to the project

#### Documentation Features

- **Live Examples**: All examples reference real, working Terraform configurations
- **Cost Estimates**: Detailed cost breakdowns for each deployment pattern
- **Architecture Diagrams**: Visual representations of system components
- **Step-by-step Guides**: Detailed instructions for every deployment scenario
- **Troubleshooting**: Common issues and their solutions
- **Best Practices**: Recommended configurations and security guidelines

## Examples and Use Cases

### Example 1: Financial Document Processing

```bash
cd examples/bedrock-llm-processor
# Configure for financial documents (invoices, statements, forms)
# Uses Claude 3 Sonnet for high accuracy
```

### Example 2: Legal Document Analysis

```bash
cd examples/bda-processor
# Configure for standard legal documents
# Uses BDA for consistent, schema-based processing
# Enhanced with comprehensive IAM permissions and HITL support
```

### Example 3: Custom Document Classification

```bash
cd examples/sagemaker-udop-processor
# Deploy with fine-tuned UDOP model
# Ideal for specialized document types
```

## Troubleshooting

### Common Issues

#### 1. Model Access Denied

```
Error: AccessDeniedException: You don't have access to the model
```

**Solution**: Enable model access in the Bedrock console (see Prerequisites)

#### 2. Insufficient Permissions

```
Error: User is not authorized to perform: bedrock:InvokeModel
```

**Solution**: Ensure your AWS credentials have the required permissions

#### 3. Resource Limits

```
Error: LimitExceededException: Rate exceeded
```

**Solution**: Adjust `max_processing_concurrency` in your configuration

#### 4. HITL Configuration Issues

```
Error: Access denied to BDA metadata table
```

**Solution**: Ensure `bda_metadata_table_arn` is correctly configured if using HITL functionality

### Getting Help

- **Module Documentation**: Each module has detailed README with troubleshooting
- **AWS Documentation**: Refer to service-specific AWS documentation
- **CloudWatch Logs**: Check function logs for detailed error information
- **Security Documentation**: Review security guide for IAM and permission issues
- **GitHub Issues**: Report bugs and request features

## Contributing

We welcome contributions! Each module includes detailed contributor documentation:

- **[Main Contributing Guide](CONTRIBUTING.md)**: Overall repository guidelines and workflow
- **[Unified Processor](modules/processors/unified-processor/README.md)**: the processing engine the façades wrap
- **[BDA Processor](modules/processors/bda-processor/README.md)**: Pattern 1 implementation guidance
- **[Bedrock LLM Processor](modules/processors/bedrock-llm-processor/README.md)**: Pattern 2 implementation guidance
- **[SageMaker UDOP Processor](modules/processors/sagemaker-udop-processor/README.md)**: Pattern 3 implementation guidance
- **[Processing Environment](modules/processing-environment/README.md)**: Core infrastructure guidance
- **[Web UI](modules/web-ui/README.md)**: Frontend development guidance

### Security Contributions

When contributing security-related changes:

- Follow AWS security best practices
- Use least privilege IAM policies
- Include comprehensive testing for permission changes
- Document security implications in pull requests

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Additional Resources

- **[AWS CDK Version](https://github.com/cdklabs/genai-idp)**: CDK implementation
- **[Terraform Documentation](https://www.terraform.io/docs)**: Terraform best practices
- **[AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)**: Bedrock service documentation
- **[Amazon Textract Documentation](https://docs.aws.amazon.com/textract/)**: OCR service documentation
- **[AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)**: Workflow orchestration
- **[AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)**: Security guidance and compliance
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.70.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.34.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_assets_bucket"></a> [assets\_bucket](#module\_assets\_bucket) | ./modules/assets-bucket | n/a |
| <a name="module_bda_processor"></a> [bda\_processor](#module\_bda\_processor) | ./modules/processors/bda-processor | n/a |
| <a name="module_bedrock_llm_processor"></a> [bedrock\_llm\_processor](#module\_bedrock\_llm\_processor) | ./modules/processors/bedrock-llm-processor | n/a |
| <a name="module_human_review"></a> [human\_review](#module\_human\_review) | ./modules/human-review | n/a |
| <a name="module_idp_agents_layer"></a> [idp\_agents\_layer](#module\_idp\_agents\_layer) | ./modules/idp-common-layer | n/a |
| <a name="module_idp_base_layer"></a> [idp\_base\_layer](#module\_idp\_base\_layer) | ./modules/idp-common-layer | n/a |
| <a name="module_idp_common_layer"></a> [idp\_common\_layer](#module\_idp\_common\_layer) | ./modules/idp-common-layer | n/a |
| <a name="module_idp_reporting_layer"></a> [idp\_reporting\_layer](#module\_idp\_reporting\_layer) | ./modules/idp-common-layer | n/a |
| <a name="module_processing_environment"></a> [processing\_environment](#module\_processing\_environment) | ./modules/processing-environment | n/a |
| <a name="module_processing_environment_api"></a> [processing\_environment\_api](#module\_processing\_environment\_api) | ./modules/processing-environment-api | n/a |
| <a name="module_processor_attachment"></a> [processor\_attachment](#module\_processor\_attachment) | ./modules/processor-attachment | n/a |
| <a name="module_reporting"></a> [reporting](#module\_reporting) | ./modules/reporting | n/a |
| <a name="module_sagemaker_udop_processor"></a> [sagemaker\_udop\_processor](#module\_sagemaker\_udop\_processor) | ./modules/processors/sagemaker-udop-processor | n/a |
| <a name="module_user_identity"></a> [user\_identity](#module\_user\_identity) | ./modules/user-identity | n/a |
| <a name="module_web_ui"></a> [web\_ui](#module\_web\_ui) | ./modules/web-ui | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role_policy.authenticated_user_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_analytics"></a> [agent\_analytics](#input\_agent\_analytics) | DEPRECATED: Use api.agent\_analytics instead. Configuration for agent analytics functionality | <pre>object({<br/>    enabled  = optional(bool, false)<br/>    model_id = optional(string, "us.anthropic.claude-3-5-sonnet-20241022-v2:0")<br/>  })</pre> | `null` | no |
| <a name="input_api"></a> [api](#input\_api) | Configuration for GraphQL API and all API-related features | <pre>object({<br/>    # Core API configuration<br/>    enabled = optional(bool, true)<br/><br/>    # Agent Analytics (GraphQL resolvers for agent functionality)<br/>    agent_analytics = optional(object({<br/>      enabled  = optional(bool, false)<br/>      model_id = optional(string, "us.anthropic.claude-3-5-sonnet-20241022-v2:0")<br/>    }), { enabled = false })<br/><br/>    # Discovery (Document discovery and classification workflow)<br/>    discovery = optional(object({<br/>      enabled = optional(bool, false)<br/>    }), { enabled = false })<br/><br/>    # Chat with Document (Document Q&A using Bedrock and Knowledge Base)<br/>    chat_with_document = optional(object({<br/>      enabled                  = optional(bool, false)<br/>      guardrail_id_and_version = optional(string, null)<br/>    }), { enabled = false })<br/><br/>    # Process Changes (Document editing and reprocessing)<br/>    process_changes = optional(object({<br/>      enabled = optional(bool, false)<br/>    }), { enabled = false })<br/><br/>    # Knowledge Base (external dependency for chat feature)<br/>    knowledge_base = optional(object({<br/>      enabled            = optional(bool, false)<br/>      knowledge_base_arn = optional(string)<br/>      model_id           = optional(string, "us.amazon.nova-pro-v1:0")<br/>      embedding_model_id = optional(string, "amazon.titan-embed-text-v1")<br/>    }), { enabled = false })<br/><br/>    # v0.4.8 feature flags<br/>    enable_agent_companion_chat = optional(bool, false)<br/>    enable_test_studio          = optional(bool, false)<br/>    enable_fcc_dataset          = optional(bool, false)<br/>    enable_error_analyzer       = optional(bool, false)<br/>    enable_mcp                  = optional(bool, false)<br/><br/>    # v0.4.16 feature flags<br/>    enable_hitl                     = optional(bool, true)<br/>    enable_capacity_planning        = optional(bool, false)<br/>    enable_omni_ai_dataset          = optional(bool, false)<br/>    enable_docplit_poly_seq_dataset = optional(bool, false)<br/>  })</pre> | <pre>{<br/>  "agent_analytics": {<br/>    "enabled": false<br/>  },<br/>  "chat_with_document": {<br/>    "enabled": false<br/>  },<br/>  "discovery": {<br/>    "enabled": false<br/>  },<br/>  "enabled": true,<br/>  "knowledge_base": {<br/>    "enabled": false<br/>  },<br/>  "process_changes": {<br/>    "enabled": false<br/>  }<br/>}</pre> | no |
| <a name="input_chat_with_document"></a> [chat\_with\_document](#input\_chat\_with\_document) | DEPRECATED: Use api.chat\_with\_document instead. Configuration for chat with document functionality | <pre>object({<br/>    enabled                  = optional(bool, false)<br/>    guardrail_id_and_version = optional(string, null)<br/>  })</pre> | `null` | no |
| <a name="input_core_table_capacity"></a> [core\_table\_capacity](#input\_core\_table\_capacity) | Billing mode and provisioned capacity for the three core DynamoDB tables<br/>(tracking, configuration, concurrency). Each table's settings are optional<br/>and default to on-demand (PAY\_PER\_REQUEST), so leaving this unset is a no-op.<br/>Set billing\_mode = "PROVISIONED" with tuned read\_capacity / write\_capacity<br/>for cost-predictable, steady high-volume workloads; read/write capacity is<br/>ignored under PAY\_PER\_REQUEST. Applies only to tables this deployment creates<br/>(inert for a table supplied via processing-environment's *\_table\_arn inputs). | <pre>object({<br/>    tracking = optional(object({<br/>      billing_mode   = optional(string, "PAY_PER_REQUEST")<br/>      read_capacity  = optional(number, 5)<br/>      write_capacity = optional(number, 5)<br/>    }), {})<br/>    configuration = optional(object({<br/>      billing_mode   = optional(string, "PAY_PER_REQUEST")<br/>      read_capacity  = optional(number, 5)<br/>      write_capacity = optional(number, 5)<br/>    }), {})<br/>    concurrency = optional(object({<br/>      billing_mode   = optional(string, "PAY_PER_REQUEST")<br/>      read_capacity  = optional(number, 5)<br/>      write_capacity = optional(number, 5)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_data_tracking_retention_days"></a> [data\_tracking\_retention\_days](#input\_data\_tracking\_retention\_days) | Document tracking data retention period in days | `number` | `365` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection for Cognito resources | `bool` | `true` | no |
| <a name="input_discovery"></a> [discovery](#input\_discovery) | DEPRECATED: Use api.discovery instead. Configuration for document discovery functionality | <pre>object({<br/>    enabled = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_enable_api"></a> [enable\_api](#input\_enable\_api) | DEPRECATED: Use api.enabled instead. Enable GraphQL API for programmatic access and notifications | `bool` | `null` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Whether encryption is enabled. Set to true when providing encryption\_key\_arn. This is needed to avoid Terraform plan-time unknown value issues. | `bool` | `true` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of the KMS key used for encrypting resources in the document processing workflow | `string` | n/a | yes |
| <a name="input_evaluation"></a> [evaluation](#input\_evaluation) | Configuration for document processing evaluation against baseline | <pre>object({<br/>    enabled             = optional(bool, false)<br/>    model_id            = optional(string, null)<br/>    baseline_bucket_arn = optional(string)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_force_rebuild_layers"></a> [force\_rebuild\_layers](#input\_force\_rebuild\_layers) | Force rebuild of Lambda layers regardless of requirements changes | `bool` | `false` | no |
| <a name="input_human_review"></a> [human\_review](#input\_human\_review) | Configuration for human review functionality in document processing. SageMaker A2I fields (user\_pool\_id, private\_workforce\_arn, workteam\_name) removed in v0.4.9 — HITL is now built into processing-environment-api. | <pre>object({<br/>    enabled                   = optional(bool, false)<br/>    enable_pattern2_hitl      = optional(bool, false)<br/>    hitl_confidence_threshold = optional(number, 80)<br/>  })</pre> | <pre>{<br/>  "enable_pattern2_hitl": false,<br/>  "enabled": false,<br/>  "hitl_confidence_threshold": 80<br/>}</pre> | no |
| <a name="input_input_bucket_arn"></a> [input\_bucket\_arn](#input\_input\_bucket\_arn) | ARN of the S3 bucket where source documents to be processed are stored | `string` | n/a | yes |
| <a name="input_knowledge_base"></a> [knowledge\_base](#input\_knowledge\_base) | DEPRECATED: Use api.knowledge\_base instead. Configuration for AWS Bedrock Knowledge Base functionality | <pre>object({<br/>    enabled            = optional(bool, false)<br/>    knowledge_base_arn = optional(string)<br/>    model_id           = optional(string, "us.amazon.nova-pro-v1:0")<br/>    embedding_model_id = optional(string, "amazon.titan-embed-text-v1")<br/>  })</pre> | `null` | no |
| <a name="input_lambda_tracing_mode"></a> [lambda\_tracing\_mode](#input\_lambda\_tracing\_mode) | X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough | `string` | `"Active"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda functions | `string` | `"INFO"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `7` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket where processed documents and extraction results will be stored | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for resource names | `string` | `"genai-idp"` | no |
| <a name="input_process_changes"></a> [process\_changes](#input\_process\_changes) | DEPRECATED: Use api.process\_changes instead. Configuration for document editing and reprocessing functionality | <pre>object({<br/>    enabled = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_reporting"></a> [reporting](#input\_reporting) | Configuration for reporting and analytics functionality | <pre>object({<br/>    enabled                     = optional(bool, false)<br/>    bucket_arn                  = optional(string)<br/>    database_name               = optional(string)<br/>    crawler_schedule            = optional(string, "daily")<br/>    enable_partition_projection = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "crawler_schedule": "daily",<br/>  "enable_partition_projection": true,<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_processor"></a> [processor](#input\_processor) | The document processor for this deployment. `type` selects the processor (bedrock-llm, bda, or sagemaker-udop); the other fields configure it, and which are required depends on `type`. | <pre>object({<br/>    type = string<br/>    project_arn = optional(string, null)<br/>    classification_endpoint_arn = optional(string, null)<br/>    ocr_max_workers             = optional(number, 20)<br/>    classification_max_workers  = optional(number, 20)<br/>    classification_model_id      = optional(string, null)<br/>    extraction_model_id          = optional(string, null)<br/>    assessment_model_id          = optional(string, null)<br/>    max_pages_for_classification = optional(string, "ALL")<br/>    enable_hitl                  = optional(bool, false)<br/>    enable_rule_validation = optional(bool, false)<br/>    summarization = optional(object({<br/>      enabled  = optional(bool, true)<br/>      model_id = optional(string, null)<br/>    }), { enabled = true, model_id = null })<br/>    config                    = any<br/>    additional_configurations = optional(any, {})<br/>    bda_project_arn           = optional(string, null)<br/>    enable_bda_ocr_backend    = optional(bool, false)<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_user_identity"></a> [user\_identity](#input\_user\_identity) | Configuration for external Cognito User Identity resources. If provided, the module will use this instead of creating its own user identity resources. | <pre>object({<br/>    user_pool_arn          = string<br/>    user_pool_client_id    = optional(string)<br/>    identity_pool_id       = optional(string)<br/>    authenticated_role_arn = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs for Lambda functions (optional) | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for Lambda functions to run in (optional) | `list(string)` | `[]` | no |
| <a name="input_web_ui"></a> [web\_ui](#input\_web\_ui) | Web UI configuration object | <pre>object({<br/>    enabled                    = optional(bool, true)<br/>    create_infrastructure      = optional(bool, true)<br/>    bucket_name                = optional(string, null)<br/>    cloudfront_distribution_id = optional(string, null)<br/>    logging_enabled            = optional(bool, true)<br/>    logging_bucket_arn         = optional(string, null)<br/>    enable_signup              = optional(string, "")<br/>    display_name               = optional(string, null)<br/>  })</pre> | <pre>{<br/>  "bucket_name": null,<br/>  "cloudfront_distribution_id": null,<br/>  "create_infrastructure": true,<br/>  "display_name": null,<br/>  "enable_signup": "",<br/>  "enabled": true,<br/>  "logging_bucket_arn": null,<br/>  "logging_enabled": true<br/>}</pre> | no |
| <a name="input_working_bucket_arn"></a> [working\_bucket\_arn](#input\_working\_bucket\_arn) | ARN of the S3 bucket for temporary working files during document processing | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_analytics"></a> [agent\_analytics](#output\_agent\_analytics) | Agent analytics resources (if enabled) |
| <a name="output_api"></a> [api](#output\_api) | API resources (if enabled) |
| <a name="output_assets_bucket"></a> [assets\_bucket](#output\_assets\_bucket) | Shared assets bucket information |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix used for all resources |
| <a name="output_processing_environment"></a> [processing\_environment](#output\_processing\_environment) | Processing environment resources |
| <a name="output_processor"></a> [processor](#output\_processor) | Document processor details |
| <a name="output_processor_type"></a> [processor\_type](#output\_processor\_type) | Type of document processor used |
| <a name="output_user_identity"></a> [user\_identity](#output\_user\_identity) | User identity resources |
| <a name="output_web_ui"></a> [web\_ui](#output\_web\_ui) | Web UI resources (if enabled) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
