# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import pytest


@pytest.mark.unit
class TestTestResultsList:
    """Tests for TestResultsList component logic"""

    def test_status_badge_color_mapping(self):
        """Test status badge color logic"""

        def get_status_variant(status):
            status_variants = {
                "RUNNING": "info",
                "COMPLETE": "success",
                "PARTIAL_COMPLETE": "warning",
                "FAILED": "error",
            }
            return status_variants.get(status, "info")

        assert get_status_variant("RUNNING") == "info"
        assert get_status_variant("COMPLETE") == "success"
        assert get_status_variant("PARTIAL_COMPLETE") == "warning"
        assert get_status_variant("FAILED") == "error"
        assert get_status_variant("UNKNOWN") == "info"

    def test_test_run_sorting(self):
        """Test test run sorting by creation date"""
        test_runs = [
            {"testRunId": "test-1", "createdAt": "2024-01-01T10:00:00Z"},
            {"testRunId": "test-2", "createdAt": "2024-01-01T12:00:00Z"},
            {"testRunId": "test-3", "createdAt": "2024-01-01T08:00:00Z"},
        ]

        # Sort by createdAt descending (newest first)
        sorted_runs = sorted(test_runs, key=lambda x: x["createdAt"], reverse=True)

        assert sorted_runs[0]["testRunId"] == "test-2"  # 12:00 (newest)
        assert sorted_runs[1]["testRunId"] == "test-1"  # 10:00
        assert sorted_runs[2]["testRunId"] == "test-3"  # 08:00 (oldest)

    def test_progress_calculation(self):
        """Test progress percentage calculation"""

        def calculate_progress_percentage(completed_files, total_files):
            if total_files == 0:
                return 0
            return round((completed_files / total_files) * 100)

        assert calculate_progress_percentage(0, 5) == 0
        assert calculate_progress_percentage(2, 5) == 40
        assert calculate_progress_percentage(5, 5) == 100
        assert calculate_progress_percentage(3, 7) == 43  # rounded
        assert calculate_progress_percentage(0, 0) == 0

    def test_test_run_filtering(self):
        """Test filtering test runs by status"""
        test_runs = [
            {"testRunId": "test-1", "status": "RUNNING"},
            {"testRunId": "test-2", "status": "COMPLETE"},
            {"testRunId": "test-3", "status": "FAILED"},
            {"testRunId": "test-4", "status": "COMPLETE"},
        ]

        def filter_by_status(runs, status):
            return [run for run in runs if run["status"] == status]

        running_tests = filter_by_status(test_runs, "RUNNING")
        assert len(running_tests) == 1
        assert running_tests[0]["testRunId"] == "test-1"

        complete_tests = filter_by_status(test_runs, "COMPLETE")
        assert len(complete_tests) == 2
        assert complete_tests[0]["testRunId"] == "test-2"
        assert complete_tests[1]["testRunId"] == "test-4"
