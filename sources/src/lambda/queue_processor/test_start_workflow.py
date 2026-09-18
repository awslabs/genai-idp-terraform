# SPDX-License-Identifier: MIT-0

"""start_workflow() names executions deterministically so duplicate triggers dedupe.

Without a name, Step Functions generated a random UUID per call, so an
at-least-once redelivery started a second execution racing the first and its late
failure overwrote the document's COMPLETED status.

Upstream: https://github.com/awslabs/genai-idp-terraform/pull/198
"""

import importlib.util
import os
import re
import sys
from unittest.mock import MagicMock, patch

import pytest

_INDEX_PATH = os.path.join(os.path.dirname(__file__), "index.py")
_MODULE_NAME = "queue_processor_index_start_workflow_test"


class _FakeExecutionAlreadyExists(Exception):
    """Stand-in for botocore's dynamically-generated SFN exception class."""


@pytest.fixture
def index_module(monkeypatch):
    """Import index with idp_common + boto3 mocked out."""
    env_vars = {
        "CONCURRENCY_TABLE": "test-concurrency",
        "STATE_MACHINE_ARN": "arn:aws:states:us-east-1:123456789012:stateMachine:t",
        "MAX_CONCURRENT": "5",
        "CONFIG_TABLE": "test-config-table",
        "WORKING_BUCKET": "test-working-bucket",
    }

    fake_docs_service = MagicMock()
    fake_docs_service.create_document_service = MagicMock(return_value=MagicMock())

    fake_xray_core = MagicMock()
    fake_xray_core.xray_recorder = MagicMock()
    fake_xray_core.patch_all = MagicMock()

    module_patches = {
        "idp_common": MagicMock(),
        "idp_common.models": MagicMock(),
        "idp_common.docs_service": fake_docs_service,
        "idp_common.config": MagicMock(),
        "aws_xray_sdk": MagicMock(),
        "aws_xray_sdk.core": fake_xray_core,
    }
    for name, mod in module_patches.items():
        monkeypatch.setitem(sys.modules, name, mod)

    with (
        patch.dict(os.environ, env_vars, clear=False),
        patch("boto3.resource") as mock_resource,
        patch("boto3.client") as mock_client,
    ):
        mock_resource.return_value.Table.return_value = MagicMock()
        mock_client.return_value = MagicMock()

        spec = importlib.util.spec_from_file_location(_MODULE_NAME, _INDEX_PATH)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        sys.modules[_MODULE_NAME] = module
        spec.loader.exec_module(module)

        module.sfn = MagicMock()
        module.sfn.exceptions.ExecutionAlreadyExists = _FakeExecutionAlreadyExists
        module.sfn.start_execution.return_value = {
            "executionArn": "arn:aws:states:us-east-1:1:execution:t:new"
        }
        module.concurrency_table = MagicMock()

        manager = MagicMock()
        manager.resolve_active_version.return_value = "default"
        manager.get_merged_configuration.return_value = MagicMock(use_bda=False)
        module.ConfigurationManager = MagicMock(return_value=manager)

        yield module
        sys.modules.pop(_MODULE_NAME, None)


class _Doc:
    def __init__(self, input_key="x0y00/brokerage_statement/invoice.pdf"):
        self.id = input_key
        self.input_key = input_key
        self.config_version = "default"
        self.status = None
        self.start_time = None
        self.workflow_execution_arn = ""

    def serialize_document(self, bucket, prefix, logger):
        return {"document_id": self.id, "s3_uri": f"s3://{bucket}/c/{self.id}/1.json"}

    def to_dict(self):
        return {"id": self.id}


@pytest.mark.unit
class TestDeterministicExecutionName:
    def test_same_key_produces_same_name(self, index_module):
        key = "x0y00/brokerage_statement/invoice.pdf"
        assert index_module._deterministic_execution_name(
            key
        ) == index_module._deterministic_execution_name(key)

    def test_different_keys_produce_different_names(self, index_module):
        assert index_module._deterministic_execution_name(
            "x0y00/brokerage_statement/a.pdf"
        ) != index_module._deterministic_execution_name(
            "x0y00/brokerage_statement/b.pdf"
        )

    def test_name_fits_step_functions_constraints(self, index_module):
        """Max 80 chars, restricted charset, and no '/', so a raw S3 key won't do."""
        name = index_module._deterministic_execution_name(
            "x0y00/brokerage_statement/a-very-long-filename-someone-might-upload.pdf"
        )
        assert len(name) <= 80
        assert re.match(r"^[a-zA-Z0-9+!@.()=_'-]+$", name)

    def test_name_survives_keys_that_break_uri_parsing(self, index_module):
        """A filename with '#'/'?' must still yield a usable, stable name."""
        key = "x0y00/brokerage_invoice/E&J 0224 INV# ENJ-208-2-2024.pdf"
        name = index_module._deterministic_execution_name(key)
        assert name == index_module._deterministic_execution_name(key)
        assert len(name) <= 80
        assert re.match(r"^[a-zA-Z0-9+!@.()=_'-]+$", name)


@pytest.mark.unit
class TestStartWorkflowDedup:
    def test_normal_start_passes_deterministic_name(self, index_module):
        doc = _Doc("x0y00/acats_in/transfer.pdf")

        result = index_module.start_workflow(doc)

        kwargs = index_module.sfn.start_execution.call_args.kwargs
        assert kwargs["name"] == index_module._deterministic_execution_name(doc.input_key)
        assert result["executionArn"] == "arn:aws:states:us-east-1:1:execution:t:new"
        assert result.get("alreadyStarted") is None

    def test_duplicate_trigger_does_not_raise(self, index_module):
        """A duplicate trigger must be reported as already-handled, not raised;
        raising would make the caller retry and eventually DLQ the message."""
        doc = _Doc()
        doc.workflow_execution_arn = "arn:aws:states:us-east-1:1:execution:t:existing"
        index_module.sfn.start_execution.side_effect = _FakeExecutionAlreadyExists()

        result = index_module.start_workflow(doc)

        assert result["alreadyStarted"] is True
        kwargs = index_module.sfn.start_execution.call_args.kwargs
        assert kwargs["name"] == index_module._deterministic_execution_name(doc.input_key)

    def test_a_real_failure_still_raises(self, index_module):
        """Only ExecutionAlreadyExists is swallowed; anything else must propagate
        so the message is retried."""
        index_module.sfn.start_execution.side_effect = RuntimeError("throttled")

        with pytest.raises(RuntimeError):
            index_module.start_workflow(_Doc())


@pytest.mark.unit
class TestProcessMessageDedupAccounting:
    """A deduplicated duplicate produces no execution, so workflow_tracker never
    fires for it. process_message has to settle the accounting itself."""

    def _run(self, index_module, doc):
        index_module.Document = MagicMock()
        index_module.Document.load_document.return_value = doc
        index_module.Status = MagicMock()
        index_module.document_service = MagicMock()
        # A fresh document: not previously aborted.
        index_module.document_service.get_document.return_value = None
        index_module.update_counter = MagicMock(return_value=True)
        index_module.check_circuit_breaker = MagicMock(return_value=(True, "CLOSED"))

        record = {"body": "{}", "messageId": "m1", "receiptHandle": "r1"}
        return index_module.process_message(record)

    def test_duplicate_releases_the_concurrency_slot(self, index_module):
        doc = _Doc()
        index_module.sfn.start_execution.side_effect = _FakeExecutionAlreadyExists()

        success, _ = self._run(index_module, doc)

        assert success is True  # message acked, no infinite redelivery
        # Incremented once to take the slot, decremented once to give it back.
        calls = index_module.update_counter.call_args_list
        assert [c.kwargs.get("increment") for c in calls] == [True, False]

    def test_duplicate_does_not_overwrite_the_tracking_status(self, index_module):
        """start_workflow sets status=RUNNING in memory; persisting that would
        clobber a COMPLETED row written by the execution that actually ran."""
        doc = _Doc()
        index_module.sfn.start_execution.side_effect = _FakeExecutionAlreadyExists()

        self._run(index_module, doc)

        index_module.document_service.update_document.assert_not_called()

    def test_normal_start_still_writes_status_and_keeps_the_slot(self, index_module):
        doc = _Doc()

        success, _ = self._run(index_module, doc)

        assert success is True
        index_module.document_service.update_document.assert_called_once()
        calls = index_module.update_counter.call_args_list
        assert [c.kwargs.get("increment") for c in calls] == [True]
