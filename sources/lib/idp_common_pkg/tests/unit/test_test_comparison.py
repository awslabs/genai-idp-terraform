# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import pytest


@pytest.mark.unit
class TestTestComparison:
    """Tests for TestComparison component logic"""

    def test_test_run_selection_validation(self):
        """Test validation for test run selection"""

        def validate_selection(selected_runs):
            if not selected_runs or len(selected_runs) < 2:
                return "Please select at least 2 test runs to compare"
            if len(selected_runs) > 5:
                return "Cannot compare more than 5 test runs at once"
            return None

        assert validate_selection([]) == "Please select at least 2 test runs to compare"
        assert (
            validate_selection(["test-1"])
            == "Please select at least 2 test runs to compare"
        )
        assert validate_selection(["test-1", "test-2"]) is None
        assert validate_selection(["test-1", "test-2", "test-3"]) is None

        many_runs = [f"test-{i}" for i in range(6)]
        assert (
            validate_selection(many_runs)
            == "Cannot compare more than 5 test runs at once"
        )

    def test_metrics_comparison_calculation(self):
        """Test metrics comparison calculation"""

        def calculate_metric_changes(baseline_value, current_value):
            if baseline_value == 0:
                return {"change": "N/A", "percentage": "N/A"}

            change = current_value - baseline_value
            percentage = (change / baseline_value) * 100

            return {"change": round(change, 4), "percentage": round(percentage, 2)}

        # Improvement
        result = calculate_metric_changes(0.85, 0.92)
        assert result["change"] == 0.07
        assert result["percentage"] == 8.24

        # Decline
        result = calculate_metric_changes(0.95, 0.88)
        assert result["change"] == -0.07
        assert result["percentage"] == -7.37

        # No change
        result = calculate_metric_changes(0.90, 0.90)
        assert result["change"] == 0.0
        assert result["percentage"] == 0.0

        # Division by zero
        result = calculate_metric_changes(0, 0.85)
        assert result["change"] == "N/A"
        assert result["percentage"] == "N/A"

    def test_cost_comparison_logic(self):
        """Test cost comparison logic"""

        def compare_costs(costs):
            if not costs or len(costs) < 2:
                return {}

            baseline_cost = costs[0]["totalCost"]
            comparisons = []

            for i, cost_data in enumerate(costs[1:], 1):
                current_cost = cost_data["totalCost"]
                difference = current_cost - baseline_cost
                percentage = (
                    (difference / baseline_cost * 100) if baseline_cost > 0 else 0
                )

                comparisons.append(
                    {
                        "testRunId": cost_data["testRunId"],
                        "cost": current_cost,
                        "difference": round(difference, 4),
                        "percentage": round(percentage, 2),
                    }
                )

            return {
                "baseline": {"testRunId": costs[0]["testRunId"], "cost": baseline_cost},
                "comparisons": comparisons,
            }

        cost_data = [
            {"testRunId": "test-1", "totalCost": 0.1000},
            {"testRunId": "test-2", "totalCost": 0.1200},
            {"testRunId": "test-3", "totalCost": 0.0800},
        ]

        result = compare_costs(cost_data)
        assert result["baseline"]["testRunId"] == "test-1"
        assert result["baseline"]["cost"] == 0.1000

        assert len(result["comparisons"]) == 2
        assert result["comparisons"][0]["testRunId"] == "test-2"
        assert result["comparisons"][0]["difference"] == 0.0200
        assert result["comparisons"][0]["percentage"] == 20.0

        assert result["comparisons"][1]["testRunId"] == "test-3"
        assert result["comparisons"][1]["difference"] == -0.0200
        assert result["comparisons"][1]["percentage"] == -20.0

    def test_config_difference_detection(self):
        """Test configuration difference detection"""

        def find_config_differences(config1, config2):
            differences = []

            # Simple flat comparison
            all_keys = set(config1.keys()) | set(config2.keys())

            for key in all_keys:
                val1 = config1.get(key)
                val2 = config2.get(key)

                if val1 != val2:
                    differences.append({"key": key, "value1": val1, "value2": val2})

            return differences

        config1 = {"model": "claude-3", "temperature": 0.1, "max_tokens": 1000}
        config2 = {"model": "claude-3", "temperature": 0.2, "max_tokens": 1500}

        diffs = find_config_differences(config1, config2)
        assert len(diffs) == 2

        temp_diff = next(d for d in diffs if d["key"] == "temperature")
        assert temp_diff["value1"] == 0.1
        assert temp_diff["value2"] == 0.2

        token_diff = next(d for d in diffs if d["key"] == "max_tokens")
        assert token_diff["value1"] == 1000
        assert token_diff["value2"] == 1500
