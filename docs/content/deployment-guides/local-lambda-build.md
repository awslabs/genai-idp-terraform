# Local Lambda Build

The default deploy path builds Lambda layer zips and processor container
images using AWS CodeBuild. That works well in CI and for hermetic
deploys but adds 5–15 minutes to every `terraform apply` and costs
real money in CodeBuild minutes. When you're iterating on Lambda
code locally, the round-trip is painful.

The `build` variable lets you opt into building those artifacts on
your machine instead, using Docker, Podman, or Finch.

```hcl
build = {
  lambda_local        = true           # build locally
  lambda_architecture = "x86_64"       # or "arm64"
  container_runtime   = "auto"         # auto-detect docker/podman/finch
}
```

With `lambda_local = true`:

- All `aws_codebuild_project` resources, the CodeBuild trigger Lambdas,
  their IAM roles, log groups, and the buildspec source S3 objects
  collapse to `count = 0`. No CodeBuild infrastructure is provisioned.
- Lambda layer zips are built inside the AWS SAM build image
  (`public.ecr.aws/sam/build-python3.12:latest-<arch>`) on your host.
- Processor container images (BDA and SageMaker UDOP) are built and
  pushed to ECR via `docker buildx build --push`.

The build flag is **non-breaking**. The default is `lambda_local = false`,
which preserves the historical CodeBuild path bit-for-bit.

## When to use which path

| Situation | Recommended setting |
|---|---|
| Daily Lambda dev loop on a workstation | `lambda_local = true` |
| Production / CI deploy | `lambda_local = false` (CodeBuild default) |
| Air-gapped or proxied environment without Docker | `lambda_local = false` |
| Compliance auditor wants hermetic AWS-managed builds | `lambda_local = false` |
| You want arm64 Lambdas | `lambda_architecture = "arm64"` (works on either path) |

The architecture flag is honored by both paths — flipping to arm64 on the
CodeBuild path switches the CodeBuild image to
`aws/codebuild/amazonlinux2-aarch64-standard:3.0` and tags the layer with
`compatible_architectures = ["arm64"]`.

## Prerequisites

You need exactly one container runtime on your deploy host. The wrapper
auto-detects in this order: Docker → Podman → Finch. Set
`build.container_runtime` to a specific name (`"docker"`, `"podman"`,
`"finch"`) to force the choice and disable fallback.

### macOS

```bash
# Docker Desktop (most common)
# https://docs.docker.com/desktop/install/mac-install/

# Podman (alternative)
brew install podman
podman machine init
podman machine start

# Finch (AWS-supported alternative)
brew install --cask finch
finch vm init
finch vm start
```

### Linux

```bash
# Docker Engine
# https://docs.docker.com/engine/install/

# Podman
sudo dnf install -y podman          # Fedora / RHEL
sudo apt install -y podman          # Debian / Ubuntu

# Enable a rootless Docker-compatible socket
systemctl --user enable --now podman.socket
```

### Windows

```powershell
# Docker Desktop:  https://docs.docker.com/desktop/install/windows-install/
# Podman Desktop:  https://podman-desktop.io/downloads
# Finch:           https://runfinch.com (preview)
```

If no runtime is detected and `lambda_local = true`, plan fails with a
clear error from `modules/build-runtime-check`'s `check {}` block,
including install hints for each platform.

## Architecture selection

Set `build.lambda_architecture` to `"arm64"` if your Lambdas should run
on Graviton. Graviton Lambdas are ~20% cheaper at the same memory size
and often faster on memory-bound workloads.

### Cross-architecture builds

If your deploy host is x86_64 but you want arm64 Lambdas (or vice
versa), the docker daemon needs `buildx` and a working QEMU emulator.

- **macOS Docker Desktop**: ships both, no setup needed.
- **Linux**: `sudo apt install qemu-user-static binfmt-support`, then
  `docker run --privileged tonistiigi/binfmt --install all` once per
  boot.
- **Podman/Finch**: similar to Docker on Linux; check their docs.

If buildx complains "exec format error" during the local-build path,
QEMU emulation isn't set up.

## Migration plan

Switching an existing deployment from `lambda_local = false` to `true`
(or back) requires no `terraform state` surgery. The plan will:

- **Destroy** every `aws_codebuild_project`, CodeBuild trigger Lambda,
  CodeBuild IAM role, CodeBuild CloudWatch log group, and buildspec
  source S3 object created by the CodeBuild path.
- **Create** the equivalent local-build resources (`null_resource`
  builders, no IAM).
- **Replace** every `aws_lambda_layer_version`, because the S3 object
  key changes between paths.
- **Update in place** every `aws_lambda_function` that references those
  layers — only the layer ARN changes, the function itself is preserved.
- **Preserve** every `aws_ecr_repository` for processor images — same
  resource address in both paths.

Lambda hot-swaps layer references on the next cold start, so layer
replacement is zero-downtime.

If you have CloudWatch alarms or other observability tied to specific
CodeBuild project names, those alarms will break when you flip the
flag. Document this as part of your migration plan.

To roll back, flip the flag the other way. The reverse plan will
re-create CodeBuild infrastructure and replace layers back to the
CodeBuild-produced artifacts.

## Troubleshooting

### "No usable container runtime detected"

The host doesn't have Docker, Podman, or Finch running. Install one
and try again. If it's installed but not running, start the daemon
(macOS Docker Desktop: open the app; Podman: `podman machine start`;
Finch: `finch vm start`).

### `docker login` failed with `denied: User ... is not authorized to perform: ecr:GetAuthorizationToken`

The deploy host's AWS credentials need ECR access. The local-build
path's `null_resource.ecr_login` does:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <ecr-url>
```

Make sure your active profile / role has `ecr:GetAuthorizationToken`,
`ecr:BatchCheckLayerAvailability`, `ecr:PutImage`,
`ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`,
`ecr:CompleteLayerUpload`.

### `exec format error` during `docker buildx build`

You're cross-building (host arch ≠ Lambda arch) without QEMU emulation
set up. See "Cross-architecture builds" above.

### Layer build inside the SAM container fails on Pillow

The local-build script copies `libjpeg`, `libpng`, `libz`, `libtiff`,
`libfreetype`, `liblcms2`, `libwebp` into the layer when it sees
`Pillow` or `PIL` in `requirements.txt`. If Pillow still fails to
import at Lambda runtime, your `requirements.txt` is likely pinning a
version that doesn't have an `aarch64` or `x86_64` wheel; either pin to
a version with wheels for both, or remove the pin.

### Layer hash differs between machines

The SAM build image gives you the same Python interpreter and pip
version across hosts, so installed-package contents are identical.
What can differ is zip metadata (file mtimes, directory order) which
changes the zip's bytes but not its behaviour. If you need byte-for-byte
reproducibility, normalize that out yourself before comparing —
hashing `python/` instead of the zip is the easy answer.

### CodeBuild infrastructure didn't fully disappear after switching

`aws_codebuild_project` and friends should all be destroyed on the
first apply after `lambda_local = true`. If something lingers, run
`terraform plan` and inspect — most likely the resource was renamed
upstream and isn't tracked under the same address anymore. The
`build_mode` output on each layer/processor module will report which
path is actually active.
