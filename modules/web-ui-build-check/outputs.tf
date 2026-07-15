# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

output "available" {
  description = "True when Node.js >= 18 was detected on the host."
  value       = data.external.probe.result.available == "true"
}

output "version" {
  description = "Detected Node.js version (semver string), or empty if not found."
  value       = data.external.probe.result.version
}
