# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import pytest


@pytest.mark.unit
def test_list_to_dict_conversion():
    """Test conversion of list to dict for comparison functions"""
    # Simulate the data structure conversion used in comparison functions
    results_list = [
        {"testRunId": "test1", "overallAccuracy": 85, "totalCost": 1.50},
        {"testRunId": "test2", "overallAccuracy": 90, "totalCost": 2.00},
    ]

    # Convert list to dict with testRunId as key
    results_dict = {result["testRunId"]: result for result in results_list}

    assert len(results_dict) == 2
    assert "test1" in results_dict
    assert "test2" in results_dict
    assert results_dict["test1"]["overallAccuracy"] == 85
    assert results_dict["test2"]["totalCost"] == 2.00


@pytest.mark.unit
def test_metrics_comparison_structure():
    """Test metrics comparison data structure"""
    results_dict = {
        "test1": {"overallAccuracy": 85, "averageConfidence": 75, "totalCost": 1.50},
        "test2": {"overallAccuracy": 90, "averageConfidence": 80, "totalCost": 2.00},
    }

    # Simulate _build_metrics_comparison logic
    metrics = [
        {
            "metric": "Overall Accuracy",
            "values": {
                k: f"{v.get('overallAccuracy', 0)}%" for k, v in results_dict.items()
            },
        },
        {
            "metric": "Average Confidence",
            "values": {
                k: f"{v.get('averageConfidence', 0)}%" for k, v in results_dict.items()
            },
        },
        {
            "metric": "Total Cost",
            "values": {k: f"${v.get('totalCost', 0)}" for k, v in results_dict.items()},
        },
    ]

    assert len(metrics) == 3
    assert metrics[0]["metric"] == "Overall Accuracy"
    assert metrics[0]["values"]["test1"] == "85%"
    assert metrics[2]["values"]["test2"] == "$2.0"
