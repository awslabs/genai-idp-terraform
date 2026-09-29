# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# `sources/` is a git submodule pinned to an upstream IDP release. A clone made
# without submodules leaves it empty, and the first failure is then an opaque
# archive_file error about a missing source_dir. This fails earlier and says why.
#
# A `check` block would only warn, and a warning is not guaranteed to be emitted
# once the plan has already errored, so the assertion is a precondition.

locals {
  # sources/VERSION ships in every upstream release, so it is a stable sentinel.
  sources_submodule_initialised = fileexists("${path.module}/sources/VERSION")
}

resource "terraform_data" "sources_submodule_guard" {
  input = local.sources_submodule_initialised

  lifecycle {
    precondition {
      condition     = local.sources_submodule_initialised
      error_message = <<-EOT
        The `sources/` submodule is not initialised, so there is no upstream code to deploy.

        `sources/` is a git submodule pinned to an upstream IDP release rather than a
        copy of it. Cloning without submodules leaves the directory empty, and every
        Lambda archive then fails on a missing source directory.

        Fix it with either:

            git submodule update --init

        or, when cloning fresh:

            git clone --recursive <repository-url>

        Consuming this repository as a Terraform module with a `git::` source needs no
        extra step, because Terraform initialises submodules recursively. Consuming it
        as a source archive, such as a registry tarball or a GitHub-generated zip, is
        not supported: archives cannot carry submodules and `sources/` will be empty.
      EOT
    }
  }
}
