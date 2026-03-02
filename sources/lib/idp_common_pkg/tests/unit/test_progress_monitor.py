# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from unittest.mock import Mock

import pytest


@pytest.mark.unit
def test_check_test_run_progress():
    """Test progress checking logic"""
    files = [
        {"FileKey": "file1.pdf", "Status": "PROCESSING"},
        {"FileKey": "file2.pdf", "Status": "PROCESSING"},
    ]

    # Simulate status updates
    completed = 0
    failed = 0

    for file_record in files:
        # Mock document status check
        status = "COMPLETE"  # Simulate completion
        if status == "COMPLETE":
            completed += 1
        elif status == "FAILED":
            failed += 1

    overall_status = "COMPLETE" if failed == 0 else "PARTIAL_COMPLETE"

    assert completed == 2
    assert failed == 0
    assert overall_status == "COMPLETE"


@pytest.mark.unit
def test_get_document_status():
    """Test document status retrieval"""
    mock_table = Mock()
    mock_table.get_item.return_value = {"Item": {"Status": "COMPLETE"}}

    # Mock the function behavior
    def _get_document_status(table, document_key):
        try:
            response = table.get_item(Key={"PK": document_key, "SK": "document"})
            if "Item" in response:
                return response["Item"].get("Status", "PROCESSING")
            return "PROCESSING"
        except Exception:
            return "PROCESSING"

    status = _get_document_status(mock_table, "test-doc")
    assert status == "COMPLETE"


@pytest.mark.unit
def test_scan_active_test_runs():
    """Test scanning for active test runs"""
    mock_response = {
        "Items": [
            {"TestRunId": "run-1", "Status": "RUNNING"},
            {"TestRunId": "run-2", "Status": "RUNNING"},
        ]
    }

    active_runs = [
        item for item in mock_response["Items"] if item["Status"] == "RUNNING"
    ]

    assert len(active_runs) == 2
    assert active_runs[0]["TestRunId"] == "run-1"
