# Local Web UI Build

When `build.ui_local = true`, the Terraform wrapper builds the React/Vite web UI
on your deploy host instead of using AWS CodeBuild. This reduces UI deploy time
from 3–5 minutes to ~15 seconds.

## Prerequisites

| Requirement | Minimum version | How to check |
|---|---|---|
| Node.js | 18+ | `node --version` |
| npm | (bundled with Node.js) | `npm --version` |
| AWS CLI | 2.x | `aws --version` |
| AWS credentials | configured | `aws sts get-caller-identity` |

### Installing Node.js

=== "macOS"

    ```bash
    # Option 1: nvm (recommended)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    nvm install 22

    # Option 2: fnm
    brew install fnm && fnm install 22

    # Option 3: Homebrew
    brew install node@22
    ```

=== "Linux"

    ```bash
    # Option 1: nvm (recommended)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    nvm install 22

    # Option 2: NodeSource
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
    ```

=== "Windows"

    ```powershell
    # Option 1: fnm
    winget install Schniz.fnm
    fnm install 22

    # Option 2: nvm-windows
    # Download from https://github.com/coreybutler/nvm-windows/releases
    nvm install 22
    nvm use 22
    ```

## Enabling Local UI Build

Set `ui_local = true` in your `build` block:

```hcl
build = {
  lambda_local        = true   # optional: also build Lambda layers locally
  lambda_architecture = "x86_64"
  container_runtime   = "auto"
  ui_local            = true   # build web UI locally
}
```

If Node.js is missing or below version 18, `terraform plan` will fail with
install instructions (via a `check {}` block).

## What Happens During Apply

When `ui_local = true` and `web_ui.enabled = true`:

1. **`npm ci`** — installs locked dependencies from `sources/src/ui/package-lock.json`.
2. **`npm run build`** — runs the Vite production build, outputting to `sources/src/ui/build/`.
3. **`aws s3 sync`** — uploads the build output to the web-app S3 bucket (with `--delete`).
4. **`aws cloudfront create-invalidation`** — invalidates `/*` on the CloudFront distribution.

The VITE_* environment variables (Cognito pool IDs, API URL, region, etc.) are
injected automatically from your Terraform configuration — no manual `.env` file needed.

## What Gets Removed

With `ui_local = true`, these resources drop to `count = 0`:

- `aws_codebuild_project.ui_build`
- CodeBuild IAM role and policy
- CodeBuild trigger Lambda function, its IAM role/policy, and log group
- `aws_lambda_invocation.trigger_ui_codebuild`
- `aws_s3_object.react_app_source` (the source zip upload)

These resources are **preserved** (shared across both modes):

- S3 bucket for web app assets
- CloudFront distribution + OAC
- WAF Web ACL
- SSM Parameter for web UI settings

## Switching Between Modes

You can safely flip `ui_local` between `true` and `false`:

- **`false` → `true`**: CodeBuild resources are destroyed; local build runs on next apply.
- **`true` → `false`**: CodeBuild resources are recreated; remote build triggers on next apply.

The web app bucket and CloudFront distribution are not affected by mode switches.

## Troubleshooting

### `npm ci` fails

Ensure you have network access to the npm registry. If behind a corporate proxy,
configure npm:

```bash
npm config set proxy http://proxy.example.com:8080
npm config set https-proxy http://proxy.example.com:8080
```

### Build produces empty output

Check that Node.js >= 18 is installed and the Vite config at
`sources/src/ui/vite.config.js` is valid.

### S3 sync fails

Verify your AWS credentials have `s3:PutObject`, `s3:DeleteObject`, and
`s3:ListBucket` permissions on the web-app bucket.

### CloudFront invalidation fails

Verify your AWS credentials have `cloudfront:CreateInvalidation` permission.
This step is non-fatal — the content will eventually propagate via TTL expiry.
