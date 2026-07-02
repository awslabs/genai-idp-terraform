# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Error Analyzer — removed upstream at v0.5.12.
#
# The standalone `error_analyzer` / `error_analyzer_resolver` Lambdas no longer
# exist in the upstream snapshot. The capability moved into the agents framework
# (`idp_common/agents/error_analyzer/`), surfaced through the generic agent
# resolvers (see `agent-analytics/`), so no dedicated wrapper resources remain.
#
# `var.enable_error_analyzer` is retained as a deprecated no-op (see
# variables.tf) so existing consumer tfvars continue to plan without error.
