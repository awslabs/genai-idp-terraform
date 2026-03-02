# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import pytest


@pytest.mark.unit
def test_comparison_button_logic():
    """Test comparison button visibility logic"""
    # Simulate button visibility conditions

    # No items selected
    selected_items = []
    show_button = len(selected_items) > 1
    assert show_button is False

    # One item selected
    selected_items = [{"testRunId": "test1"}]
    show_button = len(selected_items) > 1
    assert show_button is False

    # Multiple items selected
    selected_items = [{"testRunId": "test1"}, {"testRunId": "test2"}]
    show_button = len(selected_items) > 1
    assert show_button is True


@pytest.mark.unit
def test_test_run_ids_extraction():
    """Test extraction of test run IDs for comparison"""
    selected_items = [
        {"testRunId": "test1", "status": "COMPLETE"},
        {"testRunId": "test2", "status": "COMPLETE"},
        {"testRunId": "test3", "status": "COMPLETE"},
    ]

    test_run_ids = [item["testRunId"] for item in selected_items]

    assert len(test_run_ids) == 3
    assert test_run_ids == ["test1", "test2", "test3"]
