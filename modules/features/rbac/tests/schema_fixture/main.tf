# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Test-only fixture for the RBAC schema-directive invariant. The production RBAC
# module does NOT read the GraphQL schema (the `@aws_auth` directives already
# ship in the read-only v0.5.12 snapshot, so RBAC injects no SDL). This fixture
# exists solely so the `schema_and_scoping.tftest.hcl` run can load the shipped
# schema and assert the directive invariant statically against it, without adding
# a schema read to the real module.
#
# It reads the read-only schema verbatim and exposes it as an output; all
# `regexall(...)` invariant checks live in the test file so the assertions are
# visible there. No providers/resources, so the fixture needs no AWS provider.
#
# Path: this fixture lives at
#   modules/features/rbac/tests/schema_fixture/
# so reaching the vendored snapshot is five levels up:
#   schema_fixture -> tests -> rbac -> features -> modules -> <repo root>
locals {
  schema_path = "${path.module}/../../../../../sources/nested/api-resolvers/src/api/schema.graphql"
}

output "schema" {
  description = "Raw contents of the shipped (read-only) AppSync GraphQL schema."
  value       = file(local.schema_path)
}
