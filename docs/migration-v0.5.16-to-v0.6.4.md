# Migrating from v0.5.16-tf.x to v0.6.4-tf.0

Upstream IDP v0.6.x is a large release: the web/API transport changed, several
hosting and configuration surfaces were reshaped, and some subsystems were
deleted outright. This guide covers the wrapper-side migration for each breaking
change, with the exact commands to run.

Read the whole section that applies to your deployment **before** running
`terraform apply`. Several of these changes destroy real infrastructure.

## New requirement: Terraform >= 1.7

The root module now declares `required_version = ">= 1.7.0"` (raised from
`>= 1.0`). This release ships `removed` blocks with a
`lifecycle { destroy = true }` argument, which Terraform only understands from
1.7 onward. In practice the floor was already 1.5, because the root module has
used `check {}` blocks for several releases.

```bash
terraform version   # must report >= 1.7.0
```

## Breaking changes in this release

| Change | Status |
| --- | --- |
| ALB Web UI hosting removed (`web_ui.hosting = "ALB"`) | documented below |
| API Gateway Web UI hosting (`web_ui.hosting = "APIGateway"`) | documented below |
| AppSync GraphQL transport replaced by API Gateway REST | TODO |
| `api.visibility` renamed to `api.api_gateway_visibility` | TODO |
| Configuration / feature-parity changes | TODO |

The TODO rows are filled in by the remaining sub-steps of this migration; they
are listed here so the shape of the release is visible up front.

---

## ALB Web UI hosting removed

### What changed and why

Upstream deleted ALB Web UI hosting in IDP v0.6.0. The `WebUIHosting=ALB`
parameter value, the `nested/alb-hosting/` stack, and every `ALB*` parameter are
gone from the upstream template, replaced by `WebUIHosting=APIGateway`. The
wrapper follows upstream, so in v0.6.4-tf.0:

- `modules/web-ui-alb/` is deleted.
- The root `module "web_ui_alb"`, `aws_s3_bucket_policy.web_ui_alb`, the
  `check "web_ui_alb_inputs"` validation, and the `web_ui_alb` output are gone.
- `web_ui.alb = { ... }` is no longer a valid input.
- `web_ui.hosting` now accepts only `"CloudFront"` and `"APIGateway"`. Passing
  `"ALB"` fails at plan time with a pointer back to this document.

If you never set `web_ui.hosting = "ALB"`, nothing here applies to you — the
shipped `removed` blocks are inert and your plan is unaffected.

### Which path applies to you

```bash
# Do you have ALB resources in state?
terraform state list | grep -E 'module\.web_ui_alb|aws_s3_bucket_policy\.web_ui_alb'
```

- No output → nothing to migrate. Upgrade normally.
- Output → pick the recommended path or the direct-upgrade path below.

### Recommended path: migrate before you upgrade (no state surgery)

Do this on your **current** (v0.5.16-tf.x) version, while `modules/web-ui-alb/`
still exists. Terraform destroys the ALB resources through the module source it
already has, which is the cleanest possible decommission — a plain
`count = 0` destroy, no `removed` blocks, no state edits.

1. Back up state first.

   ```bash
   terraform state pull > state-backup-pre-v0.6.4.json
   ```

2. In your root configuration, switch hosting to CloudFront and drop the `alb`
   block:

   ```hcl
   web_ui = {
     enabled = true
     hosting = "CloudFront"   # was "ALB"
     # alb = { ... }          # delete this block
   }
   ```

   If you would rather not run the Web UI at all in this environment, set
   `enabled = false` instead.

3. Plan and review. You should see the ALB stack being destroyed and, if you
   chose CloudFront, a distribution plus its bucket policy being created.

   ```bash
   terraform plan -out=tfplan-drop-alb
   terraform show tfplan-drop-alb | grep -E '^  # '   # review every address
   terraform apply tfplan-drop-alb
   ```

4. Point DNS away from the old ALB hostname. If you had a Route 53 alias or CNAME
   at `alb_dns_name`, update or delete it now.

5. Upgrade the module reference to `0.6.4-tf.0`, run `terraform init -upgrade`,
   and plan. The ALB is already gone, so this plan contains no ALB changes.

### Direct-upgrade path: let the shipped `removed` blocks destroy the ALB

If you upgrade straight to v0.6.4-tf.0 without the intermediate apply, the
module directory is no longer present — so Terraform cannot plan the destroy from
the module source. The root file `removed-v0-6-4.tf` handles this: it declares

```hcl
removed {
  from = module.web_ui_alb
  lifecycle { destroy = true }
}

removed {
  from = aws_s3_bucket_policy.web_ui_alb
  lifecycle { destroy = true }
}
```

`destroy = true` means the real infrastructure is **decommissioned**, not merely
dropped from state.

1. Confirm Terraform >= 1.7 and back up state.

   ```bash
   terraform version
   terraform state pull > state-backup-pre-v0.6.4.json
   ```

2. Remove `web_ui.alb = { ... }` from your configuration and set
   `web_ui.hosting` to `"CloudFront"` (or `"APIGateway"` once that mode is
   wired). Leaving `"ALB"` in place fails validation:

   ```
   web_ui.hosting = "ALB" was removed in v0.6.4 (upstream deleted ALB hosting).
   Use "APIGateway" for a VPC-capable private posture, or "CloudFront".
   See docs/migration-v0.5.16-to-v0.6.4.md.
   ```

3. `terraform init -upgrade`, then plan and **read the destroy list**.

   ```bash
   terraform plan -out=tfplan-v0.6.4
   terraform show tfplan-v0.6.4 | grep -E '^  # '
   ```

   Expect roughly this shape (exact names depend on your `prefix`):

   ```
   # module.genai_idp_accelerator.aws_s3_bucket_policy.web_ui_alb[0] will be destroyed
   #   (because aws_s3_bucket_policy.web_ui_alb is not in configuration)
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_lb.this will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_lb_listener.https will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_lb_listener_rule.root will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_lb_listener_rule.catch_all will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_lb_target_group.s3 will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_lb_target_group_attachment.s3["..."] will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_security_group.alb will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_security_group.endpoint will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_security_group_ingress_rule.alb_from_cidrs["..."] will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_security_group_ingress_rule.endpoint_from_alb will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_security_group_ingress_rule.endpoint_from_lambda[0] will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_security_group_egress_rule.alb_to_endpoint will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_security_group_egress_rule.endpoint_to_alb will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_security_group_egress_rule.lambda_to_endpoint[0] will be destroyed
   # module.genai_idp_accelerator.module.web_ui_alb[0].aws_vpc_endpoint.s3 will be destroyed
   ```

   Verify that **only** `web_ui_alb` addresses appear in the destroy list. If any
   stateful resource (DynamoDB table, S3 bucket, Cognito pool) shows up, stop and
   investigate before applying.

4. Apply, then clean up DNS pointing at the old ALB hostname.

   ```bash
   terraform apply tfplan-v0.6.4
   ```

### Option: forget the ALB instead of destroying it

If you want to keep the load balancer — to reuse it for something else, or to
retire it on your own schedule — do **not** let `destroy = true` run. Either:

- Edit your local copy of `removed-v0-6-4.tf` and change `destroy = true` to
  `destroy = false` in both blocks before planning. Terraform then drops the
  resources from state and leaves the infrastructure in place.
- Or drop them from state directly, before the upgrade plan:

  ```bash
  terraform state rm 'module.web_ui_alb'
  terraform state rm 'aws_s3_bucket_policy.web_ui_alb[0]'
  ```

Either way, the ALB, target group, listener, security group, and S3 interface VPC
endpoint become unmanaged: Terraform stops tracking them and you are responsible
for their lifecycle and cost from that point on.

### Rollback

Both paths destroy infrastructure, so rollback means re-creating it rather than
reverting state. To revert:

1. Restore the pre-upgrade module version and configuration (including the `alb`
   block).
2. `terraform apply` — the `web-ui-alb` module re-creates the ALB, target group,
   listener, security group, and S3 VPC endpoint. The ALB DNS name and hosted
   zone ID will be new, so DNS records must be repointed.
3. `state-backup-pre-v0.6.4.json` is a reference for the previous resource ids;
   do not push it back with `terraform state push` unless the real resources
   still exist with those exact ids.

---

## API Gateway Web UI hosting

### What it is

`web_ui.hosting = "APIGateway"` is the replacement for the removed ALB mode. The
React SPA is served as an **S3 proxy on the same API Gateway REST API** that
carries the `/op/{field}` data transport:

```
GET /            -> s3://<web-app-bucket>/index.html   (SPA shell)
GET /{proxy+}     -> s3://<web-app-bucket>/{proxy}      (assets)
POST /op/{field}  -> dispatcher Lambda                  (data transport)
```

Because the UI and the API share one REST API and one stage, the UI
**inherits the API's network posture for free**:

- `api.api_gateway_visibility = "PRIVATE"` makes the UI reachable only through
  the `execute-api` interface VPC endpoint — a VPC-only Web UI with no
  CloudFront, no ALB, no ACM certificate, and no S3 VPC endpoint.
- `api.waf_allowed_ipv4_ranges` attaches the same WAFv2 WebACL to the stage that
  protects the API, so the IP allow-list covers the UI too.

The SPA is reached at the REST API base URL (the `api_base_url` output, which
ends in `/api`). CloudFront hosting remains the default and is unchanged.

### Switching to it

```hcl
web_ui = {
  enabled = true
  hosting = "APIGateway"   # was "CloudFront" or the removed "ALB"
}

api = {
  enabled = true           # REQUIRED — the SPA is served BY the REST API

  # Optional: VPC-only UI + API.
  # api_gateway_visibility      = "PRIVATE"
  # api_gateway_vpc_endpoint_id = "vpce-0123456789abcdef0"
}
```

`web_ui.hosting = "APIGateway"` with `api.enabled = false` is rejected by the
`web_ui_apigateway_hosting_requires_api` check — there would be no REST API to
serve the SPA from.

### The UI is built with a different base path

API Gateway serves the SPA under the stage prefix `/api`, so the UI is built with
Vite `base = /api/` in this mode (`VITE_UI_BASE_PATH`, mirroring upstream). Asset
URLs are emitted as `/api/assets/...` and resolve through the `{proxy+}` route.
Flipping `web_ui.hosting` changes that value, which changes the build hash and
triggers a UI rebuild automatically — no manual step.

Deep links work without a rewrite-to-`index.html` fallback because the SPA uses
`HashRouter`: client-side routes live in the URL fragment (`/api/#/...`), so they
never reach the server as distinct paths. A genuinely missing asset key correctly
returns 404.

### ⚠️ Switching from CloudFront replaces the web-app bucket

In APIGateway mode the web-app bucket name is derived at the **root** module
(`<prefix>-webapp-<root-generated-suffix>`) instead of from a suffix generated
inside the `web-ui` module. The API module needs the bucket name up front to build
the S3-proxy integration URIs, and taking it from the `web-ui` module output would
create a dependency cycle (`web-ui` already depends on the API module for its
endpoint URLs).

Consequence: **moving an existing CloudFront deployment to APIGateway hosting
plans a replacement of the web-app S3 bucket.**

This is safe. The bucket holds only the compiled static UI assets, which the
build step republishes on the same apply. Nothing user-authored lives there —
documents, configuration, evaluation baselines, and reporting data are all in
other buckets and are untouched.

Review the plan before applying and confirm the only bucket being replaced is the
web-app bucket:

```bash
terraform plan -out=tfplan-apigw-hosting
terraform show tfplan-apigw-hosting | grep -E 'aws_s3_bucket\.' 
```

Deployments that stay on CloudFront are unaffected: with no
`bucket_name_override` the module keeps its original internal suffix, so there is
no bucket churn.
