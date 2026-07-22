# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

output "runtime" {
  description = "Detected container runtime: docker, podman, finch, or none."
  value       = data.external.probe.result.runtime
}

output "docker_host" {
  description = "Value to feed kreuzwerker/docker provider's `host`. Empty string means use the provider default (platform docker socket); unix://path values point at podman/finch sockets."
  value       = data.external.probe.result.docker_host
}

output "available" {
  description = "True when at least one runtime was found. Mirrors the check {} assertion."
  value       = data.external.probe.result.runtime != "none"
}
