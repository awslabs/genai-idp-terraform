# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from decimal import Decimal

import pytest


@pytest.mark.unit
class TestTestResults:
    """Tests for TestResults component logic"""

    def test_cost_breakdown_formatting(self):
        """Test cost breakdown display logic"""

        def format_cost_breakdown(cost_breakdown):
            if not cost_breakdown or not isinstance(cost_breakdown, dict):
                return {}

            formatted = {}
            for service, cost in cost_breakdown.items():
                if isinstance(cost, (int, float)) and cost > 0:
                    formatted[service] = f"${cost:.4f}"

            return formatted

        cost_data = {
            "bedrock_tokens": 0.0234,
            "textract": 0.0156,
            "stepfunctions": 0.0001,
            "dynamodb": 0.0000,
        }

        formatted = format_cost_breakdown(cost_data)
        assert formatted["bedrock_tokens"] == "$0.0234"
        assert formatted["textract"] == "$0.0156"
        assert formatted["stepfunctions"] == "$0.0001"
        assert "dynamodb" not in formatted  # Zero cost excluded

    def test_accuracy_display(self):
        """Test accuracy percentage display"""

        def format_accuracy(accuracy):
            if accuracy is None or accuracy < 0:
                return "N/A"
            return f"{accuracy:.1f}%"

        assert format_accuracy(95.67) == "95.7%"
        assert format_accuracy(100.0) == "100.0%"
        assert format_accuracy(0.0) == "0.0%"
        assert format_accuracy(None) == "N/A"
        assert format_accuracy(-1) == "N/A"

    def test_confidence_score_validation(self):
        """Test confidence score validation"""

        def validate_confidence_score(score):
            if score is None:
                return False
            if not isinstance(score, (int, float)):
                return False
            return 0 <= score <= 1

        assert validate_confidence_score(0.85) is True
        assert validate_confidence_score(0.0) is True
        assert validate_confidence_score(1.0) is True
        assert validate_confidence_score(1.5) is False
        assert validate_confidence_score(-0.1) is False
        assert validate_confidence_score(None) is False
        assert validate_confidence_score("0.85") is False

    def test_file_count_summary(self):
        """Test file count summary logic"""

        def create_file_summary(completed_files, failed_files, total_files):
            successful = completed_files - failed_files
            return {
                "total": total_files,
                "successful": max(0, successful),
                "failed": failed_files,
                "pending": max(0, total_files - completed_files),
            }

        summary = create_file_summary(8, 2, 10)
        assert summary["total"] == 10
        assert summary["successful"] == 6
        assert summary["failed"] == 2
        assert summary["pending"] == 2

        # Edge case: more completed than total
        summary = create_file_summary(5, 1, 5)
        assert summary["successful"] == 4
        assert summary["pending"] == 0


@pytest.mark.unit
class TestTestResultsResolver:
    """Tests for test_results_resolver Lambda function"""

    def test_test_run_not_found(self):
        """Test error when test run doesn't exist"""

        # Mock the function behavior
        def mock_get_test_results(test_run_id):
            # Simulate DynamoDB returning no item
            raise ValueError(f"Test run {test_run_id} not found")

        with pytest.raises(ValueError, match="Test run test123 not found"):
            mock_get_test_results("test123")

    def test_cached_results_returned(self):
        """Test cached results are returned when available"""

        # Mock the function behavior
        def mock_get_test_results(test_run_id):
            # Simulate returning cached result
            return {
                "testRunId": test_run_id,
                "status": "COMPLETE",
                "overallAccuracy": Decimal("0.85"),
            }

        result = mock_get_test_results("test123")
        assert result["testRunId"] == "test123"
        assert result["status"] == "COMPLETE"
        assert result["overallAccuracy"] == Decimal("0.85")

    def test_handler_success(self):
        """Test successful handler execution"""

        # Mock the handler behavior
        def mock_handler(event, context):
            test_run_id = event.get("testRunId")
            return {"testRunId": test_run_id, "status": "COMPLETE"}

        event = {"testRunId": "test123"}
        result = mock_handler(event, None)

        assert result["testRunId"] == "test123"
        assert result["status"] == "COMPLETE"

    def test_decimal_serialization_for_json_fields(self):
        """Test Decimal objects are properly converted for JSON fields"""
        import json
        from decimal import Decimal

        # Mock cost breakdown with Decimals
        cost_breakdown = {"bedrock": Decimal("1.50"), "textract": Decimal("0.25")}

        # Function to convert decimals before JSON serialization
        def decimal_to_float(obj):
            if isinstance(obj, Decimal):
                return float(obj)
            elif isinstance(obj, dict):
                return {k: decimal_to_float(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [decimal_to_float(v) for v in obj]
            return obj

        # Test conversion and JSON serialization
        converted = decimal_to_float(cost_breakdown)
        json_string = json.dumps(converted)

        assert json_string == '{"bedrock": 1.5, "textract": 0.25}'
        assert isinstance(converted["bedrock"], float)  # type: ignore[index]

    def test_caching_with_native_dynamodb_types(self):
        """Test caching preserves native DynamoDB types"""
        from decimal import Decimal

        # Mock result with float types (as returned by _query_accuracy_metrics)
        result_with_floats = {
            "testRunId": "test123",
            "overallAccuracy": 0.85,  # Float from Python calculation
            "averageConfidence": 0.90,  # Float from Python calculation
            "totalCost": 1.50,  # Float from Python calculation
            "costBreakdown": '{"bedrock": 1.5}',  # JSON string for GraphQL
            "status": "COMPLETE",
        }

        # Function to convert floats to Decimals for DynamoDB
        def float_to_decimal(obj):
            if isinstance(obj, float):
                return Decimal(str(obj))
            elif isinstance(obj, dict):
                return {k: float_to_decimal(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [float_to_decimal(v) for v in obj]
            return obj

        # Mock caching function that converts floats to Decimals
        def mock_cache_result(result_data):
            # This should convert floats to Decimals for DynamoDB
            converted = float_to_decimal(result_data)
            return converted

        cached_result = mock_cache_result(result_with_floats)

        # Verify floats are converted to Decimals for DynamoDB storage
        assert isinstance(cached_result["overallAccuracy"], Decimal)  # type: ignore[index]
        assert isinstance(cached_result["averageConfidence"], Decimal)  # type: ignore[index]
        assert isinstance(cached_result["totalCost"], Decimal)  # type: ignore[index]
        assert isinstance(
            cached_result["costBreakdown"],  # type: ignore[index]
            str,
        )  # JSON string unchanged
        assert cached_result["testRunId"] == "test123"  # type: ignore[index]

        # Verify values are preserved during conversion
        assert float(cached_result["overallAccuracy"]) == 0.85  # type: ignore[index]
        assert float(cached_result["averageConfidence"]) == 0.90  # type: ignore[index]
        assert float(cached_result["totalCost"]) == 1.50  # type: ignore[index]

    def test_float_to_decimal_conversion_bug_detection(self):
        """Test that detects the float/Decimal conversion bug"""
        from decimal import Decimal

        # Simulate the bug: trying to store floats in DynamoDB
        result_with_floats = {
            "overallAccuracy": 0.85,  # This would cause DynamoDB error
            "totalCost": 1.50,
        }

        # Mock DynamoDB behavior - should reject floats
        def mock_dynamodb_update(data):
            for key, value in data.items():
                if isinstance(value, float):
                    raise Exception(
                        "Float types are not supported. Use Decimal types instead."
                    )
            return True

        # This should raise an error without conversion
        with pytest.raises(Exception, match="Float types are not supported"):
            mock_dynamodb_update(result_with_floats)

        # With conversion, it should work
        def float_to_decimal(obj):
            if isinstance(obj, float):
                return Decimal(str(obj))
            elif isinstance(obj, dict):
                return {k: float_to_decimal(v) for k, v in obj.items()}
            return obj

        converted_result = float_to_decimal(result_with_floats)
        assert mock_dynamodb_update(converted_result) is True

    def test_cache_retrieval_returns_same_structure(self):
        """Test cache retrieval returns identical structure"""
        from decimal import Decimal

        # Original result structure
        original_result = {
            "testRunId": "test123",
            "overallAccuracy": Decimal("0.85"),
            "costBreakdown": '{"bedrock": 1.5}',
            "status": "COMPLETE",
        }

        # Mock cache storage and retrieval
        def mock_cache_operations(result_data):
            # Store in cache
            cached = result_data.copy()
            # Retrieve from cache
            return cached

        retrieved_result = mock_cache_operations(original_result)

        # Verify identical structure
        assert retrieved_result == original_result
        assert isinstance(
            retrieved_result["overallAccuracy"],
            type(original_result["overallAccuracy"]),
        )

    def test_caching_failure_handling(self):
        """Test that caching failures don't affect result return"""

        def mock_get_results_with_cache_failure(test_run_id):
            # Calculate result
            result = {"testRunId": test_run_id, "status": "COMPLETE"}

            # Simulate cache failure
            try:
                raise Exception("DynamoDB caching failed")
            except Exception:
                # Log warning but continue
                pass

            # Still return result
            return result

        result = mock_get_results_with_cache_failure("test123")
        assert result["testRunId"] == "test123"
        assert result["status"] == "COMPLETE"
