# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


import pytest


@pytest.mark.unit
class TestTestRunnerModal:
    """Basic validation tests for TestRunnerModal component logic"""

    def test_input_validation(self):
        """Test input validation logic"""

        # Simulate the validation logic from TestRunnerModal
        def validate_inputs(test_set_name, file_pattern):
            if not test_set_name.strip() or not file_pattern.strip():
                return "Both test set name and file pattern are required"
            return None

        # Test valid inputs
        assert validate_inputs("test-lending", "lending_package.*") is None

        # Test invalid inputs
        assert (
            validate_inputs("", "pattern")
            == "Both test set name and file pattern are required"
        )
        assert (
            validate_inputs("name", "")
            == "Both test set name and file pattern are required"
        )
        assert (
            validate_inputs("  ", "pattern")
            == "Both test set name and file pattern are required"
        )

    def test_test_run_response_validation(self):
        """Test response validation logic"""

        # Simulate the response validation from TestRunnerModal
        def validate_response(result):
            if not result or not result.get("testRunId"):
                return "Failed to start test run - no test ID returned"
            return None

        # Test valid response
        valid_response = {"testRunId": "test-123", "status": "RUNNING"}
        assert validate_response(valid_response) is None

        # Test invalid responses
        assert (
            validate_response(None) == "Failed to start test run - no test ID returned"
        )
        assert validate_response({}) == "Failed to start test run - no test ID returned"
        assert (
            validate_response({"status": "RUNNING"})
            == "Failed to start test run - no test ID returned"
        )

    def test_status_color_mapping(self):
        """Test status color mapping logic"""

        # Simulate the status color logic from TestRunnerStatus
        def get_status_color(status):
            colors = {
                "RUNNING": "blue",
                "COMPLETE": "green",
                "PARTIAL_COMPLETE": "yellow",
                "FAILED": "red",
            }
            return colors.get(status, "grey")

        assert get_status_color("RUNNING") == "blue"
        assert get_status_color("COMPLETE") == "green"
        assert get_status_color("PARTIAL_COMPLETE") == "yellow"
        assert get_status_color("FAILED") == "red"
        assert get_status_color("UNKNOWN") == "grey"

    def test_completion_detection(self):
        """Test completion detection logic"""

        # Simulate the completion detection from TestRunnerStatus
        def is_test_complete(status_data):
            if not status_data:
                return False

            completed_files = status_data.get("completedFiles", 0)
            total_files = status_data.get("filesCount", 0)
            current_status = status_data.get("status", "")

            is_complete = completed_files == total_files and total_files > 0
            is_still_running = current_status == "RUNNING"

            return is_complete and is_still_running

        # Test completion scenarios
        running_complete = {"completedFiles": 5, "filesCount": 5, "status": "RUNNING"}
        assert is_test_complete(running_complete) is True

        # Test incomplete scenarios
        running_incomplete = {"completedFiles": 3, "filesCount": 5, "status": "RUNNING"}
        assert is_test_complete(running_incomplete) is False

        already_complete = {"completedFiles": 5, "filesCount": 5, "status": "COMPLETE"}
        assert is_test_complete(already_complete) is False

        no_files = {"completedFiles": 0, "filesCount": 0, "status": "RUNNING"}
        assert is_test_complete(no_files) is False
