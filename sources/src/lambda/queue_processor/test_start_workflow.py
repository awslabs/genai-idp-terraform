"""Unit tests for queue_processor's deterministic execution naming and dedup handling."""

import importlib.util
import os
import re
import sys
from unittest.mock import MagicMock, patch

import pytest

_INDEX_PATH = os.path.join(os.path.dirname(__file__), "index.py")
_MODULE_NAME = "queue_processor_index_under_test_start_workflow"


@pytest.fixture
def index_module(monkeypatch):
    """Import index with idp_common + boto3 mocked out."""
    env_vars = {
        "CONCURRENCY_TABLE": "test-concurrency",
        "STATE_MACHINE_ARN": "arn:aws:states:us-east-1:123456789012:stateMachine:test",
        "MAX_CONCURRENT": "5",
    }

    fake_idp_common = MagicMock()
    fake_models = MagicMock()
    fake_models.Document = MagicMock()
    fake_models.Status = MagicMock()
    fake_docs_service = MagicMock()
    fake_docs_service.create_document_service = MagicMock(return_value=MagicMock())
    fake_config = MagicMock()

    fake_xray_core = MagicMock()
    fake_xray_core.xray_recorder = MagicMock()
    fake_xray_core.patch_all = MagicMock()

    module_patches = {
        "idp_common": fake_idp_common,
        "idp_common.models": fake_models,
        "idp_common.docs_service": fake_docs_service,
        "idp_common.config": fake_config,
        "aws_xray_sdk": MagicMock(),
        "aws_xray_sdk.core": fake_xray_core,
    }
    for name, mod in module_patches.items():
        monkeypatch.setitem(sys.modules, name, mod)

    with patch.dict(os.environ, env_vars, clear=False), \
         patch("boto3.resource") as mock_resource, \
         patch("boto3.client") as mock_client:
        mock_table = MagicMock()
        mock_resource.return_value.Table.return_value = mock_table
        mock_sfn = MagicMock()

        class FakeExecutionAlreadyExists(Exception):
            pass

        mock_sfn.exceptions.ExecutionAlreadyExists = FakeExecutionAlreadyExists
        mock_client.side_effect = lambda service, *a, **kw: mock_sfn if service == "stepfunctions" else MagicMock()

        spec = importlib.util.spec_from_file_location(_MODULE_NAME, _INDEX_PATH)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        sys.modules[_MODULE_NAME] = module
        spec.loader.exec_module(module)

        module.concurrency_table = mock_table
        module.sfn = mock_sfn
        yield module
        sys.modules.pop(_MODULE_NAME, None)


class TestDeterministicExecutionName:
    def test_same_key_produces_same_name(self, index_module):
        name1 = index_module._deterministic_execution_name("x0y00/brokerage_statement/invoice.pdf")
        name2 = index_module._deterministic_execution_name("x0y00/brokerage_statement/invoice.pdf")
        assert name1 == name2

    def test_different_keys_produce_different_names(self, index_module):
        name1 = index_module._deterministic_execution_name("x0y00/brokerage_statement/a.pdf")
        name2 = index_module._deterministic_execution_name("x0y00/brokerage_statement/b.pdf")
        assert name1 != name2

    def test_name_fits_step_functions_constraints(self, index_module):
        # Step Functions execution names: max 80 chars, restricted character set.
        name = index_module._deterministic_execution_name(
            "x0y00/brokerage_statement/a-very-long-filename-that-someone-might-actually-upload.pdf"
        )
        assert len(name) <= 80
        assert re.match(r"^[a-zA-Z0-9+!@.()=_'-]+$", name)


class TestStartWorkflowDedup:
    def test_duplicate_trigger_does_not_raise(self, index_module):
        """A second start_workflow call for the same document (duplicate trigger)
        should be treated as already-handled, not propagate an exception that would
        cause the caller to retry and potentially loop forever."""
        document = MagicMock()
        document.input_key = "x0y00/brokerage_statement/invoice.pdf"
        document.config_version = "default"
        document.workflow_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:test:existing"
        document.to_dict.return_value = {"input_key": document.input_key}

        index_module.sfn.start_execution.side_effect = index_module.sfn.exceptions.ExecutionAlreadyExists()
        os_environ_backup = index_module.os.environ.get("WORKING_BUCKET")
        index_module.os.environ["WORKING_BUCKET"] = ""

        result = index_module.start_workflow(document)

        assert result.get("alreadyStarted") is True
        # Confirm start_execution was called with a deterministic name derived from
        # input_key, not left to auto-generate.
        _, kwargs = index_module.sfn.start_execution.call_args
        assert kwargs["name"] == index_module._deterministic_execution_name(document.input_key)

    def test_normal_start_passes_deterministic_name(self, index_module):
        document = MagicMock()
        document.input_key = "x0y00/acats_in/transfer.pdf"
        document.config_version = "default"
        document.workflow_execution_arn = ""
        document.to_dict.return_value = {"input_key": document.input_key}

        index_module.sfn.start_execution.return_value = {"executionArn": "arn:aws:states:us-east-1:123456789012:execution:test:new"}
        index_module.os.environ["WORKING_BUCKET"] = ""

        result = index_module.start_workflow(document)

        _, kwargs = index_module.sfn.start_execution.call_args
        assert kwargs["name"] == index_module._deterministic_execution_name(document.input_key)
        assert result["executionArn"] == "arn:aws:states:us-east-1:123456789012:execution:test:new"
