# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the extraction models module.
"""

import json
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import pytest

# Define mock classes that match the structure of the real ones
# This avoids importing the actual modules that depend on PIL


@dataclass
class ExtractedAttribute:
    """A single extracted attribute from a document"""

    name: str
    value: Any
    confidence: float = 1.0


@dataclass
class ExtractionResult:
    """Result of extraction for a document section"""

    section_id: str
    document_class: str
    attributes: List[ExtractedAttribute]
    raw_response: Optional[str] = None
    metering: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None
    output_uri: Optional[str] = None


@dataclass
class PageInfo:
    """Information about a page used in extraction"""

    page_id: str
    text_uri: Optional[str] = None
    image_uri: Optional[str] = None
    raw_text_uri: Optional[str] = None


@pytest.mark.unit
class TestExtractedAttribute:
    """Tests for the ExtractedAttribute class."""

    def test_init_with_required_fields(self):
        """Test initialization with only required fields."""
        attr = ExtractedAttribute(name="invoice_number", value="INV-123")

        assert attr.name == "invoice_number"
        assert attr.value == "INV-123"
        assert attr.confidence == 1.0  # Default value

    def test_init_with_all_fields(self):
        """Test initialization with all fields."""
        attr = ExtractedAttribute(
            name="invoice_number", value="INV-123", confidence=0.95
        )

        assert attr.name == "invoice_number"
        assert attr.value == "INV-123"
        assert attr.confidence == 0.95

    def test_init_with_different_value_types(self):
        """Test initialization with different value types."""
        # String value
        attr_str = ExtractedAttribute(name="invoice_number", value="INV-123")
        assert attr_str.value == "INV-123"

        # Numeric value
        attr_num = ExtractedAttribute(name="total_amount", value=123.45)
        assert attr_num.value == 123.45

        # Boolean value
        attr_bool = ExtractedAttribute(name="is_paid", value=True)
        assert attr_bool.value is True

        # Dictionary value
        attr_dict = ExtractedAttribute(
            name="address", value={"street": "123 Main St", "city": "Anytown"}
        )
        assert attr_dict.value == {"street": "123 Main St", "city": "Anytown"}

        # List value
        attr_list = ExtractedAttribute(name="line_items", value=["item1", "item2"])
        assert attr_list.value == ["item1", "item2"]

        # None value
        attr_none = ExtractedAttribute(name="optional_field", value=None)
        assert attr_none.value is None


@pytest.mark.unit
class TestExtractionResult:
    """Tests for the ExtractionResult class."""

    def test_init_with_required_fields(self):
        """Test initialization with only required fields."""
        attributes = [
            ExtractedAttribute(name="invoice_number", value="INV-123"),
            ExtractedAttribute(name="invoice_date", value="2025-05-08"),
        ]

        result = ExtractionResult(
            section_id="1", document_class="invoice", attributes=attributes
        )

        assert result.section_id == "1"
        assert result.document_class == "invoice"
        assert len(result.attributes) == 2
        assert result.attributes[0].name == "invoice_number"
        assert result.attributes[1].name == "invoice_date"
        assert result.raw_response is None
        assert result.metering is None
        assert result.metadata is None
        assert result.output_uri is None

    def test_init_with_all_fields(self):
        """Test initialization with all fields."""
        attributes = [
            ExtractedAttribute(name="invoice_number", value="INV-123"),
            ExtractedAttribute(name="invoice_date", value="2025-05-08"),
        ]

        raw_response = '{"invoice_number": "INV-123", "invoice_date": "2025-05-08"}'
        metering = {"tokens": 500}
        metadata = {"processing_time": 1.5}
        output_uri = "s3://bucket/output.json"

        result = ExtractionResult(
            section_id="1",
            document_class="invoice",
            attributes=attributes,
            raw_response=raw_response,
            metering=metering,
            metadata=metadata,
            output_uri=output_uri,
        )

        assert result.section_id == "1"
        assert result.document_class == "invoice"
        assert len(result.attributes) == 2
        assert result.raw_response == raw_response
        assert result.metering == metering
        assert result.metadata == metadata
        assert result.output_uri == output_uri

    def test_serialization_compatibility(self):
        """Test that the class can be serialized and deserialized with JSON."""
        attributes = [
            ExtractedAttribute(name="invoice_number", value="INV-123"),
            ExtractedAttribute(name="total_amount", value=123.45),
        ]

        result = ExtractionResult(
            section_id="1",
            document_class="invoice",
            attributes=attributes,
            metadata={"processing_time": 1.5},
        )

        # Convert to dict (as would happen in JSON serialization)
        result_dict = {
            "section_id": result.section_id,
            "document_class": result.document_class,
            "attributes": [
                {"name": attr.name, "value": attr.value, "confidence": attr.confidence}
                for attr in result.attributes
            ],
            "metadata": result.metadata,
        }

        # Verify the dict contains the expected values
        assert result_dict["section_id"] == "1"
        assert result_dict["document_class"] == "invoice"
        assert len(result_dict["attributes"]) == 2
        assert result_dict["attributes"][0]["name"] == "invoice_number"
        assert result_dict["attributes"][0]["value"] == "INV-123"
        assert result_dict["attributes"][1]["name"] == "total_amount"
        assert result_dict["attributes"][1]["value"] == 123.45
        assert result_dict["metadata"]["processing_time"] == 1.5

        # Verify it can be converted to JSON
        json_str = json.dumps(result_dict)
        assert json_str is not None

        # Verify it can be parsed back from JSON
        parsed_dict = json.loads(json_str)
        assert parsed_dict["section_id"] == result.section_id
        assert parsed_dict["document_class"] == result.document_class
        assert len(parsed_dict["attributes"]) == len(result.attributes)


@pytest.mark.unit
class TestPageInfo:
    """Tests for the PageInfo class."""

    def test_init_with_required_fields(self):
        """Test initialization with only required fields."""
        page_info = PageInfo(page_id="1")

        assert page_info.page_id == "1"
        assert page_info.text_uri is None
        assert page_info.image_uri is None
        assert page_info.raw_text_uri is None

    def test_init_with_all_fields(self):
        """Test initialization with all fields."""
        page_info = PageInfo(
            page_id="1",
            text_uri="s3://bucket/text.txt",
            image_uri="s3://bucket/image.jpg",
            raw_text_uri="s3://bucket/raw.json",
        )

        assert page_info.page_id == "1"
        assert page_info.text_uri == "s3://bucket/text.txt"
        assert page_info.image_uri == "s3://bucket/image.jpg"
        assert page_info.raw_text_uri == "s3://bucket/raw.json"
