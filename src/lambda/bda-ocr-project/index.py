# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Deployment-scoped BDA OCR project manager for the Terraform implementation.
#
# IDP v0.6 added a `bda` OCR backend that runs a Bedrock Data Automation
# *standard-output SYNC* project as a pure OCR engine. Upstream provisions that
# project with a CloudFormation custom resource
# (`Custom::BDAOCRProject`, sources/src/lambda/bda_ocr_project), created on
# stack create and deleted on stack delete, so that multiple stacks in one
# account no longer share a single account-global project.
#
# This is the Terraform equivalent. Two deliberate differences from upstream's
# Lambda:
#
#   1. It speaks `aws_lambda_invocation`'s `lifecycle_scope = "CRUD"` protocol
#      (`event["tf"]["action"]` is "create" / "update" / "delete") instead of
#      the CloudFormation custom-resource protocol, so it needs no `cfnresponse`
#      and no presigned response URL.
#
#   2. It CALLS the canonical library (`idp_common.bda.bda_ocr`) rather than
#      inlining the project configuration logic. Upstream duplicates that logic
#      because SAM's makefile builder runs against an isolated copy of the
#      function's CodeUri and cannot reach `lib/` at build time — a constraint
#      this wrapper does not have, since `idp_common` arrives via the base
#      Lambda layer. Upstream's own docstring names the library module as the
#      canonical, unit-tested source and carries a drift guard against its
#      inlined copy, so calling it directly is strictly the safer side of that
#      duplication.

import json
import logging
import os
from typing import Any, Dict

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def _resolve_action(event: Dict[str, Any]) -> str:
    """
    Determine the lifecycle action for this invocation.

    `aws_lambda_invocation` with `lifecycle_scope = "CRUD"` merges a `tf` key
    into the payload carrying `action` ("create" | "update" | "delete"). An
    explicit top-level `Action` wins, so the function stays callable by hand
    (e.g. `aws lambda invoke`) for recovery.
    """
    explicit = event.get("Action")
    if explicit:
        return str(explicit).lower()
    return str(event.get("tf", {}).get("action", "create")).lower()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Manage the deployment-scoped BDA OCR standard-output project.

    Input:
      * ``StackName`` (required) — the deployment's name prefix. The project is
        named ``<sanitized-stack-name>_OCR_StdOutput``, which is what scopes it
        to this deployment.
      * ``ConfigVersion`` (optional) — bump to force a re-run after changing the
        project's standard-output or modality-routing configuration. Only
        meaningful as an input-hash change; it is not otherwise interpreted.
      * ``Action`` / ``tf.action`` — see ``_resolve_action``.

    Returns ``{"statusCode": 200, "body": "{\\"projectArn\\": ...}"}``. On
    ``create``/``update`` ``projectArn`` is the found-or-created project; on
    ``delete`` it is the deleted project ARN, or null when there was nothing to
    delete.

    A create/update failure is raised, so a broken OCR backend surfaces at apply
    time rather than as confusing empty-text OCR results later. A delete failure
    is swallowed: `delete_ocr_project_by_name` is best-effort by design and a
    leftover project must never block `terraform destroy`.
    """
    logger.info("BDA OCR project event: %s", json.dumps(event, default=str))

    action = _resolve_action(event)
    stack_name = event.get("StackName")
    if not stack_name:
        raise ValueError("StackName is required to derive the OCR project name.")

    from idp_common.bda.bda_ocr import (
        delete_ocr_project_by_name,
        find_or_create_ocr_project,
        sanitize_ocr_project_name,
    )

    project_name = sanitize_ocr_project_name(stack_name)
    region = os.environ.get("AWS_REGION")

    if action == "delete":
        try:
            deleted_arn = delete_ocr_project_by_name(project_name, region=region)
        except Exception as exc:  # pragma: no cover - best-effort teardown
            logger.warning(
                "Failed to delete BDA OCR project %s; leaving it in place so "
                "destroy can proceed. Error: %s",
                project_name,
                exc,
            )
            deleted_arn = None
        return {
            "statusCode": 200,
            "body": json.dumps(
                {"action": action, "projectName": project_name, "projectArn": deleted_arn}
            ),
        }

    # create / update: idempotent find-or-create. Also repairs a project left
    # over from an earlier build that is missing the jpeg/png -> DOCUMENT
    # modality-routing override, which otherwise silently breaks OCR (page
    # images misroute to IMAGE and yield empty text).
    project_arn = find_or_create_ocr_project(project_name, region=region)
    logger.info("BDA OCR project ready: %s", project_arn)

    return {
        "statusCode": 200,
        "body": json.dumps(
            {"action": action, "projectName": project_name, "projectArn": project_arn}
        ),
    }
