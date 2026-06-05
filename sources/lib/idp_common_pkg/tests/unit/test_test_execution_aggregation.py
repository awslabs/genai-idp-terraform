# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for test_execution_aggregation_function Lambda.
"""

import json
import os
import sys
from unittest.mock import MagicMock, patch

import pytest

# Add the function path to sys.path
FUNCTION_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "../../../../patterns/unified/src/test_execution_aggregation_function",
    )
)


def import_test_module():
    """Import the test_execution_aggregation index module."""
    if FUNCTION_PATH not in sys.path:
        sys.path.insert(0, FUNCTION_PATH)

    # Remove any cached index module
    if "index" in sys.modules:
        del sys.modules["index"]

    import index

    return index


@pytest.fixture
def mock_env():
    """Mock environment variables."""
    with patch.dict(
        os.environ, {"TRACKING_TABLE": "test-tracking-table", "LOG_LEVEL": "INFO"}
    ):
        yield


@pytest.fixture
def lambda_context():
    """Mock Lambda context."""
    context = MagicMock()
    context.function_name = "test-function"
    context.invoked_function_arn = (
        "arn:aws:lambda:us-west-2:123456789012:function:test-function"
    )
    return context


@pytest.fixture
def mock_dynamodb_table():
    """Mock DynamoDB table."""
    table = MagicMock()
    table.scan.return_value = {
        "Items": [
            {
                "PK": "doc#test-run-123#doc1.pdf",
                "ObjectKey": "doc1.pdf",
                "EvaluationStatus": "COMPLETED",
                "EvaluationReportUri": "s3://bucket/doc1.pdf/evaluation/report.md",
            },
            {
                "PK": "doc#test-run-123#doc2.pdf",
                "ObjectKey": "doc2.pdf",
                "EvaluationStatus": "COMPLETED",
                "EvaluationReportUri": "s3://bucket/doc2.pdf/evaluation/report.md",
            },
        ]
    }
    return table


@pytest.fixture
def mock_s3_results():
    """Mock S3 evaluation results."""
    return {
        "overall_metrics": {"weighted_overall_score": 0.95},
        "section_results": [
            {
                "section_id": "1",
                "stickler_comparison_result": {
                    "tp": 10,
                    "fp": 1,
                    "tn": 5,
                    "fn": 2,
                },
            }
        ],
    }


@pytest.mark.unit
class TestHandler:
    """Tests for Lambda handler function."""

    def test_handler_success(self, mock_env, lambda_context):
        """Test successful handler execution."""
        index = import_test_module()

        event = {"test_run_id": "test-run-123"}

        with patch.object(index, "aggregate_test_run_with_stickler") as mock_aggregate:
            mock_aggregate.return_value = {
                "overall_accuracy": 0.85,
                "document_count": 2,
            }

            response = index.handler(event, lambda_context)

            assert response["statusCode"] == 200
            body = json.loads(response["body"])
            assert body["overall_accuracy"] == 0.85
            assert body["document_count"] == 2
            mock_aggregate.assert_called_once_with(
                "test-run-123", "test-tracking-table"
            )

    def test_handler_missing_test_run_id(self, mock_env, lambda_context):
        """Test handler with missing test_run_id."""
        index = import_test_module()

        event = {}

        response = index.handler(event, lambda_context)

        assert response["statusCode"] == 500
        body = json.loads(response["body"])
        assert "error" in body
        assert "test_run_id" in body["error"]

    def test_handler_aggregation_error(self, mock_env, lambda_context):
        """Test handler when aggregation fails."""
        index = import_test_module()

        event = {"test_run_id": "test-run-123"}

        with patch.object(index, "aggregate_test_run_with_stickler") as mock_aggregate:
            mock_aggregate.side_effect = Exception("DynamoDB error")

            response = index.handler(event, lambda_context)

            assert response["statusCode"] == 500
            body = json.loads(response["body"])
            assert "error" in body
            assert "DynamoDB error" in body["error"]


@pytest.mark.unit
class TestAggregation:
    """Tests for aggregation logic."""

    def test_load_comparison_results(
        self, mock_env, mock_dynamodb_table, mock_s3_results
    ):
        """Test loading comparison results from DynamoDB and S3."""
        index = import_test_module()

        with patch.object(index, "dynamodb") as mock_dynamodb:
            mock_dynamodb.Table.return_value = mock_dynamodb_table
            with patch.object(index, "_load_s3_json") as mock_load_s3:
                mock_load_s3.return_value = mock_s3_results

                results, scores = index._load_comparison_results(
                    "test-run-123", "test-table"
                )

                assert len(results) == 2  # Two documents with stickler results
                assert len(scores) == 2  # Two weighted scores
                assert "doc1.pdf" in scores
                assert "doc2.pdf" in scores
                assert scores["doc1.pdf"] == 0.95

    def test_load_comparison_results_skips_incomplete(self, mock_env):
        """Test that incomplete evaluations are skipped."""
        index = import_test_module()

        incomplete_table = MagicMock()
        incomplete_table.scan.return_value = {
            "Items": [
                {
                    "PK": "doc#test-run-123#doc1.pdf",
                    "ObjectKey": "doc1.pdf",
                    "EvaluationStatus": "RUNNING",  # Not completed
                    "EvaluationReportUri": "s3://bucket/doc1.pdf/evaluation/report.md",
                }
            ]
        }

        with patch.object(index, "dynamodb") as mock_dynamodb:
            mock_dynamodb.Table.return_value = incomplete_table

            results, scores = index._load_comparison_results(
                "test-run-123", "test-table"
            )

            assert len(results) == 0
            assert len(scores) == 0

    def test_empty_metrics(self, mock_env):
        """Test empty metrics structure."""
        index = import_test_module()

        metrics = index._empty_metrics()

        assert metrics["overall_accuracy"] is None
        assert metrics["weighted_overall_scores"] == {}
        assert metrics["average_confidence"] is None
        assert metrics["document_count"] == 0
        assert "accuracy_breakdown" in metrics

    def test_calculate_false_alarm_rate(self, mock_env):
        """Test false alarm rate calculation."""
        index = import_test_module()

        # FP / (FP + TN)
        metrics = {"fp": 2, "tn": 8}
        rate = index._calculate_false_alarm_rate(metrics)
        assert rate == 0.2  # 2 / (2 + 8)

        # Zero denominator
        metrics = {"fp": 0, "tn": 0}
        rate = index._calculate_false_alarm_rate(metrics)
        assert rate is None

    def test_calculate_false_discovery_rate(self, mock_env):
        """Test false discovery rate calculation."""
        index = import_test_module()

        # FP / (FP + TP)
        metrics = {"fp": 3, "tp": 7}
        rate = index._calculate_false_discovery_rate(metrics)
        assert rate == 0.3  # 3 / (3 + 7)

        # Zero denominator
        metrics = {"fp": 0, "tp": 0}
        rate = index._calculate_false_discovery_rate(metrics)
        assert rate is None

    def test_load_s3_json(self, mock_env):
        """Test loading JSON from S3."""
        index = import_test_module()

        mock_response = {"Body": MagicMock()}
        mock_response["Body"].read.return_value = b'{"key": "value"}'

        with patch.object(index, "s3_client") as mock_s3:
            mock_s3.get_object.return_value = mock_response

            result = index._load_s3_json("s3://test-bucket/test-key.json")

            assert result == {"key": "value"}
            mock_s3.get_object.assert_called_once_with(
                Bucket="test-bucket", Key="test-key.json"
            )

    def test_load_s3_json_invalid_uri(self, mock_env):
        """Test loading JSON with invalid S3 URI."""
        index = import_test_module()

        with pytest.raises(ValueError, match="Invalid S3 URI"):
            index._load_s3_json("http://example.com/file.json")
