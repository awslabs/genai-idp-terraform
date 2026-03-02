# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the Stickler-based evaluation service.

These tests focus on the public API and Stickler integration functionality.
"""

import warnings
from unittest.mock import MagicMock, patch

import pytest
from idp_common.evaluation.models import (
    AttributeEvaluationResult,
    SectionEvaluationResult,
)
from idp_common.evaluation.service import EvaluationService
from idp_common.models import Document, Section, Status


@pytest.fixture(autouse=True)
def suppress_datetime_warning():
    """Fixture to suppress the datetime.utcnow() deprecation warning from botocore."""
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="datetime.datetime.utcnow\\(\\) is deprecated",
            category=DeprecationWarning,
        )
        yield


@pytest.mark.unit
class TestSticklerEvaluationService:
    """Tests for the Stickler-based EvaluationService class."""

    @pytest.fixture
    def mock_config(self):
        """Fixture providing a mock configuration with evaluation extensions."""
        return {
            "classes": [
                {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "$id": "invoice",
                    "x-aws-idp-document-type": "Invoice",
                    "x-aws-idp-evaluation-model-name": "Invoice",
                    "x-aws-idp-evaluation-match-threshold": 0.8,
                    "type": "object",
                    "description": "An invoice document",
                    "properties": {
                        "invoice_number": {
                            "type": "string",
                            "description": "The invoice number",
                            "x-aws-idp-evaluation-method": "EXACT",
                            "x-aws-idp-evaluation-weight": 3.0,
                        },
                        "invoice_date": {
                            "type": "string",
                            "description": "The invoice date",
                            "x-aws-idp-evaluation-method": "FUZZY",
                            "x-aws-idp-evaluation-threshold": 0.9,
                            "x-aws-idp-evaluation-weight": 1.5,
                        },
                        "total_amount": {
                            "type": "number",
                            "description": "The total amount",
                            "x-aws-idp-evaluation-method": "NUMERIC_EXACT",
                            "x-aws-idp-evaluation-threshold": 0.01,
                            "x-aws-idp-evaluation-weight": 2.0,
                        },
                    },
                }
            ],
            "evaluation": {
                "llm_method": {
                    "model": "anthropic.claude-3-sonnet-20240229-v1:0",
                    "temperature": 0.0,
                    "top_k": 5,
                }
            },
        }

    @pytest.fixture
    def service(self, mock_config):
        """Fixture providing an EvaluationService instance."""
        return EvaluationService(region="us-west-2", config=mock_config, max_workers=5)

    @pytest.fixture
    def sample_document(self):
        """Fixture providing a sample document with sections."""
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            input_bucket="input-bucket",
            output_bucket="output-bucket",
            status=Status.EXTRACTING,
        )

        # Add sections
        doc.sections.append(
            Section(
                section_id="1",
                classification="Invoice",
                page_ids=["1", "2"],
                extraction_result_uri="s3://input-bucket/test-document.pdf/sections/1/result.json",
            )
        )

        return doc

    def test_init(self, mock_config):
        """Test initialization with configuration."""
        service = EvaluationService(
            region="us-west-2", config=mock_config, max_workers=5
        )

        assert service.region == "us-west-2"
        assert service.max_workers == 5
        assert len(service.stickler_models) == 1
        assert "invoice" in service.stickler_models

    def test_stickler_model_creation(self, service):
        """Test that Stickler models are created correctly."""
        # Get Stickler model for invoice class
        model_class = service._get_stickler_model("Invoice")

        assert model_class is not None
        assert model_class.__name__ == "Invoice"

        # Test caching
        model_class_2 = service._get_stickler_model("Invoice")
        assert model_class is model_class_2  # Same instance from cache

    def test_stickler_model_not_found(self, service):
        """Test error when Stickler model not found for class."""
        with pytest.raises(ValueError, match="No schema configuration"):
            service._get_stickler_model("UnknownClass")

    @patch("idp_common.s3.get_json_content")
    def test_prepare_stickler_data(self, mock_get_json_content, service):
        """Test preparing data for Stickler."""
        # Test with inference_result wrapper
        mock_get_json_content.return_value = {
            "inference_result": {"invoice_number": "INV-123", "total_amount": 100.00},
            "explainability_info": [{"invoice_number": {"confidence": 0.95}}],
        }

        extraction_data, confidence_scores = service._prepare_stickler_data(
            "s3://bucket/path"
        )

        assert extraction_data == {"invoice_number": "INV-123", "total_amount": 100.00}
        assert "invoice_number" in confidence_scores

    def test_get_nested_value(self, service):
        """Test getting nested values from Stickler model instances."""
        # Create a mock object with nested attributes
        mock_obj = MagicMock()
        mock_obj.invoice_number = "INV-123"
        mock_obj.address = MagicMock()
        mock_obj.address.city = "Seattle"

        # Test simple attribute
        value = service._get_nested_value(mock_obj, "invoice_number")
        assert value == "INV-123"

        # Test nested attribute
        value = service._get_nested_value(mock_obj, "address.city")
        assert value == "Seattle"

        # Test with real dict (not MagicMock which always returns values)
        dict_obj = {"invoice_number": "INV-123", "address": {"city": "Seattle"}}

        # Test non-existent attribute with dict
        value = service._get_nested_value(dict_obj, "nonexistent")
        assert value is None

    def test_generate_reason(self, service):
        """Test reason generation."""
        # Test exact match
        reason = service._generate_reason("field", "val", "val", 1.0, True, "Exact")
        assert "Exact match" in reason

        # Test partial match
        reason = service._generate_reason("field", "val1", "val2", 0.85, True, "Fuzzy")
        assert "above threshold" in reason

        # Test no match
        reason = service._generate_reason("field", "val1", "val2", 0.5, False, "Exact")
        assert "do not match" in reason

        # Test both empty
        reason = service._generate_reason("field", None, None, 1.0, True, "Exact")
        assert "empty" in reason.lower()

    @patch("idp_common.s3.write_content")
    @patch("idp_common.evaluation.service.EvaluationService._process_section")
    def test_evaluate_document_api(
        self, mock_process_section, mock_write_content, service, sample_document
    ):
        """Test the public evaluate_document API."""
        # Create expected document
        expected_document = sample_document

        # Configure mock for _process_section
        section_result = SectionEvaluationResult(
            section_id="1",
            document_class="Invoice",
            attributes=[
                AttributeEvaluationResult(
                    name="invoice_number",
                    expected="INV-123",
                    actual="INV-123",
                    matched=True,
                    score=1.0,
                    evaluation_method="STICKLER",
                    weight=3.0,
                )
            ],
            metrics={"precision": 1.0, "recall": 1.0, "f1_score": 1.0},
        )

        mock_process_section.return_value = (
            section_result,
            {"tp": 1, "fp": 0, "fn": 0, "tn": 0, "fp1": 0, "fp2": 0},
        )

        # Patch calculate_metrics
        with patch("idp_common.evaluation.metrics.calculate_metrics") as mock_metrics:
            mock_metrics.return_value = {
                "precision": 1.0,
                "recall": 1.0,
                "f1_score": 1.0,
            }

            # Evaluate document
            result = service.evaluate_document(
                actual_document=sample_document,
                expected_document=expected_document,
                store_results=True,
            )

            # Verify API contract
            assert result.id == "test-doc"
            assert result.status == Status.COMPLETED
            assert result.evaluation_report_uri is not None
            assert result.evaluation_results_uri is not None
            assert result.evaluation_result is not None

            # Verify Stickler enhancements
            assert (
                result.evaluation_result.section_results[0].attributes[0].weight == 3.0
            )

    @patch("idp_common.s3.write_content")
    @patch("idp_common.evaluation.service.EvaluationService._process_section")
    def test_evaluate_document_error_handling(
        self, mock_process_section, mock_write_content, service, sample_document
    ):
        """Test error handling in evaluate_document."""
        expected_document = sample_document

        # Configure mock to raise exception
        mock_process_section.side_effect = Exception("Test error")

        # Evaluate document
        result = service.evaluate_document(
            actual_document=sample_document, expected_document=expected_document
        )

        # Check error was captured
        assert len(result.errors) > 0
        assert "Test error" in result.errors[0]

    def test_evaluate_section_with_stickler(self, service):
        """Test evaluate_section with Stickler comparison."""
        section = Section(section_id="1", classification="Invoice", page_ids=["1"])

        expected_results = {
            "invoice_number": "INV-123",
            "invoice_date": "2023-05-08",
            "total_amount": 100.00,
        }

        actual_results = {
            "invoice_number": "INV-123",
            "invoice_date": "2023-05-08",
            "total_amount": 100.00,
        }

        # Mock Stickler model and comparison
        with patch.object(service, "_get_stickler_model") as mock_get_model:
            # Create mock Stickler model
            mock_model_class = MagicMock()
            mock_instance = MagicMock()

            # Configure comparison result
            mock_instance.compare_with.return_value = {
                "overall_score": 1.0,
                "field_scores": {
                    "invoice_number": 1.0,
                    "invoice_date": 1.0,
                    "total_amount": 1.0,
                },
                "match": True,
            }

            mock_model_class.return_value = mock_instance
            mock_get_model.return_value = mock_model_class

            # Mock _get_nested_value to return the values
            with patch.object(service, "_get_nested_value") as mock_nested:

                def nested_side_effect(obj, field_name):
                    if "expected" in str(obj):
                        return expected_results.get(field_name)
                    return actual_results.get(field_name)

                mock_nested.side_effect = nested_side_effect

                # Evaluate section
                result = service.evaluate_section(
                    section=section,
                    expected_results=expected_results,
                    actual_results=actual_results,
                )

                # Verify result
                assert result.section_id == "1"
                assert result.document_class == "Invoice"
                assert len(result.attributes) == 3

                # Verify Stickler was used
                mock_get_model.assert_called_once()
                mock_instance.compare_with.assert_called_once()
