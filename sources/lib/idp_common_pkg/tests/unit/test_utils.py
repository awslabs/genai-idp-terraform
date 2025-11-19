# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the utils module.
"""

import json

import pytest
from idp_common.utils import (
    detect_format,
    extract_json_from_text,
    extract_structured_data_from_text,
    extract_yaml_from_text,
)

# Import yaml with fallback for testing
try:
    import yaml

    YAML_AVAILABLE = True
except ImportError:
    yaml = None
    YAML_AVAILABLE = False


@pytest.mark.unit
class TestExtractJsonFromText:
    """Tests for the extract_json_from_text function."""

    def test_extract_json_code_block(self):
        """Test extracting JSON from ```json code block."""
        text = 'Here is the result:\n```json\n{"class": "invoice"}\n```\nEnd of result.'
        result = extract_json_from_text(text)
        assert result == '{"class": "invoice"}'

        # Verify it's valid JSON
        parsed = json.loads(result)
        assert parsed["class"] == "invoice"

    def test_extract_json_generic_code_block(self):
        """Test extracting JSON from generic ``` code block."""
        text = 'Here is the result:\n```\n{"invoice_number": "INV-123"}\n```\nEnd of result.'
        result = extract_json_from_text(text)
        assert result == '{"invoice_number": "INV-123"}'

        # Verify it's valid JSON
        parsed = json.loads(result)
        assert parsed["invoice_number"] == "INV-123"

    def test_extract_json_simple(self):
        """Test extracting JSON without code blocks."""
        text = 'The classification is {"class": "receipt"} based on the content.'
        result = extract_json_from_text(text)
        assert result == '{"class": "receipt"}'

        # Verify it's valid JSON
        parsed = json.loads(result)
        assert parsed["class"] == "receipt"

    def test_extract_json_nested(self):
        """Test extracting nested JSON."""
        text = 'Result: {"class": "letter", "metadata": {"confidence": 0.9}}'
        result = extract_json_from_text(text)
        assert result == '{"class": "letter", "metadata": {"confidence": 0.9}}'

        # Verify it's valid JSON
        parsed = json.loads(result)
        assert parsed["class"] == "letter"
        assert parsed["metadata"]["confidence"] == 0.9

    def test_extract_json_no_json(self):
        """Test with text containing no JSON."""
        text = "No JSON here"
        result = extract_json_from_text(text)
        assert result == "No JSON here"

    def test_extract_json_empty_text(self):
        """Test with empty text."""
        result = extract_json_from_text("")
        assert result == ""

    def test_extract_json_multiline_in_code_block(self):
        """Test extracting JSON with literal newlines in string values within code blocks."""
        text = """Here is the extracted data:
```json
{
    "summary": "This is a multi-line
summary that spans
multiple lines",
    "key_points": [
        "Point 1 with
newline",
        "Point 2"
    ],
    "description": "Another field
with newlines"
}
```
End of response."""

        result = extract_json_from_text(text)

        # Should be able to parse the result as valid JSON
        parsed = json.loads(result)
        assert "summary" in parsed
        assert "key_points" in parsed
        assert "description" in parsed
        assert len(parsed["key_points"]) == 2

    def test_extract_json_multiline_without_code_blocks(self):
        """Test extracting JSON with newlines but without code blocks."""
        text = """The result is {
    "invoice_number": "INV-123",
    "description": "This is a long
description that spans
multiple lines",
    "amount": 100.50
} based on the document analysis."""

        result = extract_json_from_text(text)

        # Should be able to parse the result as valid JSON
        parsed = json.loads(result)
        assert parsed["invoice_number"] == "INV-123"
        assert "description" in parsed
        assert parsed["amount"] == 100.50

    def test_extract_json_complex_nested_with_newlines(self):
        """Test extracting complex nested JSON with newlines."""
        text = """```json
{
    "document_type": "invoice",
    "extracted_fields": {
        "vendor_info": {
            "name": "ACME Corp",
            "address": "123 Main St
Suite 100
Anytown, ST 12345"
        },
        "line_items": [
            {
                "description": "Product A
with detailed specs",
                "quantity": 2,
                "price": 50.00
            }
        ]
    },
    "notes": "This invoice contains
multiple line items
with complex descriptions"
}
```"""

        result = extract_json_from_text(text)

        # Should be able to parse the result as valid JSON
        parsed = json.loads(result)
        assert parsed["document_type"] == "invoice"
        assert "vendor_info" in parsed["extracted_fields"]
        assert "line_items" in parsed["extracted_fields"]
        assert len(parsed["extracted_fields"]["line_items"]) == 1
        assert parsed["extracted_fields"]["line_items"][0]["quantity"] == 2

    def test_extract_json_with_escaped_quotes(self):
        """Test extracting JSON with escaped quotes and newlines."""
        text = """{
    "text": "He said \\"Hello world\\" to everyone",
    "multiline": "Line 1\\nLine 2\\nLine 3"
}"""

        result = extract_json_from_text(text)

        # Should be able to parse the result as valid JSON
        parsed = json.loads(result)
        assert 'He said "Hello world" to everyone' in parsed["text"]
        assert "Line 1\nLine 2\nLine 3" == parsed["multiline"]

    def test_extract_json_malformed_fallback(self):
        """Test that malformed JSON falls back to original text."""
        text = 'Here is malformed JSON: { "key": "value" missing closing brace'
        result = extract_json_from_text(text)
        # Should return original text when JSON is malformed
        assert result == text

    def test_extract_json_multiple_json_objects(self):
        """Test extracting the first valid JSON object when multiple exist."""
        text = 'First: {"a": 1} and second: {"b": 2}'
        result = extract_json_from_text(text)

        # Should extract the first complete JSON object
        parsed = json.loads(result)
        assert parsed["a"] == 1

    def test_extract_json_with_arrays(self):
        """Test extracting JSON containing arrays."""
        text = """The extracted data is:
```json
{
    "items": [
        {"name": "Item 1", "value": 10},
        {"name": "Item 2", "value": 20}
    ],
    "total": 30
}
```"""

        result = extract_json_from_text(text)

        # Should be able to parse the result as valid JSON
        parsed = json.loads(result)
        assert len(parsed["items"]) == 2
        assert parsed["items"][0]["name"] == "Item 1"
        assert parsed["total"] == 30


@pytest.mark.unit
@pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
class TestExtractYamlFromText:
    """Tests for the extract_yaml_from_text function."""

    def test_extract_yaml_code_block(self):
        """Test extracting YAML from ```yaml code block."""
        text = "Here is the result:\n```yaml\nclass: invoice\nconfidence: 0.9\n```\nEnd of result."
        result = extract_yaml_from_text(text)
        assert result == "class: invoice\nconfidence: 0.9"

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["class"] == "invoice"
        assert parsed["confidence"] == 0.9

    def test_extract_yaml_yml_code_block(self):
        """Test extracting YAML from ```yml code block."""
        text = "Here is the result:\n```yml\ninvoice_number: INV-123\namount: 100.50\n```\nEnd of result."
        result = extract_yaml_from_text(text)
        assert result == "invoice_number: INV-123\namount: 100.50"

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["invoice_number"] == "INV-123"
        assert parsed["amount"] == 100.50

    def test_extract_yaml_generic_code_block(self):
        """Test extracting YAML from generic ``` code block."""
        text = "Here is the result:\n```\nclass: receipt\nvendor: ACME Corp\n```\nEnd of result."
        result = extract_yaml_from_text(text)
        assert result == "class: receipt\nvendor: ACME Corp"

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["class"] == "receipt"
        assert parsed["vendor"] == "ACME Corp"

    def test_extract_yaml_document_markers(self):
        """Test extracting YAML with document markers."""
        text = """Here is the YAML:
---
document_type: invoice
fields:
  vendor: ACME Corp
  amount: 250.00
  items:
    - name: Product A
      quantity: 2
    - name: Product B
      quantity: 1
---
End of document."""

        result = extract_yaml_from_text(text)

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["document_type"] == "invoice"
        assert parsed["fields"]["vendor"] == "ACME Corp"
        assert len(parsed["fields"]["items"]) == 2

    def test_extract_yaml_multiline_strings(self):
        """Test extracting YAML with multiline strings."""
        text = """```yaml
summary: |
  This is a multiline
  summary that spans
  multiple lines
description: >
  This is a folded
  multiline string
  that gets joined
notes:
  - First note
  - Second note with
    continuation
```"""

        result = extract_yaml_from_text(text)

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert "This is a multiline" in parsed["summary"]
        assert (
            "This is a folded multiline string that gets joined"
            in parsed["description"]
        )
        assert len(parsed["notes"]) == 2

    def test_extract_yaml_nested_structure(self):
        """Test extracting complex nested YAML."""
        text = """```yaml
document:
  type: invoice
  metadata:
    created: 2023-01-01
    version: 1.0
  content:
    vendor:
      name: ACME Corporation
      address:
        street: 123 Main St
        city: Anytown
        state: ST
        zip: 12345
    line_items:
      - description: Product A
        quantity: 2
        unit_price: 25.00
        total: 50.00
      - description: Product B
        quantity: 1
        unit_price: 75.00
        total: 75.00
    totals:
      subtotal: 125.00
      tax: 10.00
      total: 135.00
```"""

        result = extract_yaml_from_text(text)

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["document"]["type"] == "invoice"
        assert parsed["document"]["content"]["vendor"]["name"] == "ACME Corporation"
        assert len(parsed["document"]["content"]["line_items"]) == 2
        assert parsed["document"]["content"]["totals"]["total"] == 135.00

    def test_extract_yaml_with_lists(self):
        """Test extracting YAML with various list formats."""
        text = """```yaml
simple_list:
  - item1
  - item2
  - item3

complex_list:
  - name: First Item
    value: 100
  - name: Second Item
    value: 200

inline_list: [a, b, c]

mixed_content:
  - simple_string
  - key: value
    another: item
  - [nested, inline, list]
```"""

        result = extract_yaml_from_text(text)

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert len(parsed["simple_list"]) == 3
        assert parsed["simple_list"][0] == "item1"
        assert len(parsed["complex_list"]) == 2
        assert parsed["complex_list"][0]["name"] == "First Item"
        assert parsed["inline_list"] == ["a", "b", "c"]
        assert len(parsed["mixed_content"]) == 3

    def test_extract_yaml_pattern_detection(self):
        """Test YAML extraction using pattern detection."""
        text = """The extracted data shows:
class: document
confidence: 0.95
fields:
  title: Important Document
  date: 2023-01-01
  tags:
    - urgent
    - review
status: processed"""

        result = extract_yaml_from_text(text)

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["class"] == "document"
        assert parsed["confidence"] == 0.95
        assert parsed["fields"]["title"] == "Important Document"
        assert "urgent" in parsed["fields"]["tags"]

    def test_extract_yaml_no_yaml(self):
        """Test with text containing no YAML."""
        text = "No YAML here, just plain text"
        result = extract_yaml_from_text(text)
        assert result == "No YAML here, just plain text"

    def test_extract_yaml_empty_text(self):
        """Test with empty text."""
        result = extract_yaml_from_text("")
        assert result == ""

    def test_extract_yaml_malformed_fallback(self):
        """Test that malformed YAML falls back to original text."""
        text = """Here is malformed YAML:
```yaml
key: value
  invalid: [unclosed bracket
    more: invalid
```"""
        result = extract_yaml_from_text(text)
        # The function extracts the code block content and tries to validate it
        # Since this YAML is malformed, it should fall back to original text
        assert result == text

    def test_extract_yaml_mixed_with_json(self):
        """Test YAML extraction when text contains both YAML and JSON."""
        text = """Here's some YAML:
```yaml
type: document
status: processed
```
And here's some JSON: {"other": "data"}"""

        result = extract_yaml_from_text(text)
        assert result == "type: document\nstatus: processed"

        # Verify it's valid YAML
        parsed = yaml.safe_load(result)
        assert parsed["type"] == "document"
        assert parsed["status"] == "processed"


@pytest.mark.unit
class TestDetectFormat:
    """Tests for the detect_format function."""

    def test_detect_json_code_block(self):
        """Test detecting JSON from code block."""
        text = '```json\n{"key": "value"}\n```'
        result = detect_format(text)
        assert result == "json"

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_detect_yaml_code_block(self):
        """Test detecting YAML from code block."""
        text = "```yaml\nkey: value\n```"
        result = detect_format(text)
        assert result == "yaml"

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_detect_yml_code_block(self):
        """Test detecting YAML from yml code block."""
        text = "```yml\nkey: value\n```"
        result = detect_format(text)
        assert result == "yaml"

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_detect_yaml_document_marker(self):
        """Test detecting YAML from document marker."""
        text = "---\nkey: value\nother: data"
        result = detect_format(text)
        assert result == "yaml"

    def test_detect_json_braces(self):
        """Test detecting JSON from braces."""
        text = '{"key": "value", "number": 123}'
        result = detect_format(text)
        assert result == "json"

    def test_detect_json_array(self):
        """Test detecting JSON array."""
        text = '[{"item": 1}, {"item": 2}]'
        result = detect_format(text)
        assert result == "json"

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_detect_yaml_pattern(self):
        """Test detecting YAML from patterns."""
        text = """key: value
another_key: another value
list_items:
  - item1
  - item2"""
        result = detect_format(text)
        assert result == "yaml"

    def test_detect_unknown_format(self):
        """Test detecting unknown format."""
        text = "This is just plain text with no structure"
        result = detect_format(text)
        assert result == "unknown"

    def test_detect_empty_text(self):
        """Test detecting format of empty text."""
        result = detect_format("")
        assert result == "unknown"

    def test_detect_json_preference(self):
        """Test that JSON is preferred when both formats are valid."""
        # This text is valid both as JSON and YAML
        text = '{"key": "value"}'
        result = detect_format(text)
        assert result == "json"


@pytest.mark.unit
class TestExtractStructuredDataFromText:
    """Tests for the extract_structured_data_from_text function."""

    def test_extract_json_auto_detection(self):
        """Test automatic JSON detection and parsing."""
        text = '```json\n{"class": "invoice", "confidence": 0.9}\n```'
        parsed_data, detected_format = extract_structured_data_from_text(text)

        assert detected_format == "json"
        assert isinstance(parsed_data, dict)
        assert parsed_data["class"] == "invoice"
        assert parsed_data["confidence"] == 0.9

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_extract_yaml_auto_detection(self):
        """Test automatic YAML detection and parsing."""
        text = """```yaml
class: invoice
confidence: 0.9
fields:
  vendor: ACME Corp
  amount: 100.50
```"""
        parsed_data, detected_format = extract_structured_data_from_text(text)

        assert detected_format == "yaml"
        assert isinstance(parsed_data, dict)
        assert parsed_data["class"] == "invoice"
        assert parsed_data["confidence"] == 0.9
        assert parsed_data["fields"]["vendor"] == "ACME Corp"

    def test_extract_json_explicit_format(self):
        """Test explicit JSON format specification."""
        text = 'Result: {"status": "success", "data": [1, 2, 3]}'
        parsed_data, detected_format = extract_structured_data_from_text(
            text, preferred_format="json"
        )

        assert detected_format == "json"
        assert isinstance(parsed_data, dict)
        assert parsed_data["status"] == "success"
        assert parsed_data["data"] == [1, 2, 3]

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_extract_yaml_explicit_format(self):
        """Test explicit YAML format specification."""
        text = """status: success
data:
  - item1
  - item2
  - item3"""
        parsed_data, detected_format = extract_structured_data_from_text(
            text, preferred_format="yaml"
        )

        assert detected_format == "yaml"
        assert isinstance(parsed_data, dict)
        assert parsed_data["status"] == "success"
        assert parsed_data["data"] == ["item1", "item2", "item3"]

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_extract_fallback_json_to_yaml(self):
        """Test fallback from JSON to YAML when JSON parsing fails."""
        # This looks like JSON but is actually YAML
        text = """class: document
fields: {vendor: "ACME Corp", amount: 100.50}
status: processed"""

        parsed_data, detected_format = extract_structured_data_from_text(
            text, preferred_format="json"
        )

        # Should fallback to YAML
        assert detected_format == "yaml"
        assert isinstance(parsed_data, dict)
        assert parsed_data["class"] == "document"
        assert parsed_data["fields"]["vendor"] == "ACME Corp"

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_extract_fallback_yaml_to_json(self):
        """Test fallback from YAML to JSON when YAML parsing fails."""
        # This is valid JSON but we're asking for YAML first
        text = '{"class": "document", "status": "processed"}'

        parsed_data, detected_format = extract_structured_data_from_text(
            text, preferred_format="yaml"
        )

        # Should fallback to JSON
        assert detected_format == "json"
        assert isinstance(parsed_data, dict)
        assert parsed_data["class"] == "document"
        assert parsed_data["status"] == "processed"

    def test_extract_unknown_format_fallback(self):
        """Test handling of unknown format."""
        text = "This is just plain text with no structure"
        parsed_data, detected_format = extract_structured_data_from_text(text)

        assert detected_format == "unknown"
        assert parsed_data == text

    def test_extract_empty_text(self):
        """Test handling of empty text."""
        parsed_data, detected_format = extract_structured_data_from_text("")

        assert detected_format == "unknown"
        assert parsed_data == ""

    def test_extract_malformed_data(self):
        """Test handling of malformed data."""
        text = '{"malformed": json without closing brace'
        parsed_data, detected_format = extract_structured_data_from_text(text)

        assert detected_format == "unknown"
        assert parsed_data == text

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not available")
    def test_extract_complex_nested_structure(self):
        """Test extraction of complex nested structure."""
        text = """```yaml
document:
  classification:
    type: invoice
    confidence: 0.95
  extraction:
    vendor:
      name: ACME Corporation
      contact:
        email: billing@acme.com
        phone: 555-0123
    line_items:
      - description: Product A
        details:
          sku: PROD-A-001
          category: electronics
        pricing:
          unit_price: 25.00
          quantity: 2
          total: 50.00
      - description: Product B
        details:
          sku: PROD-B-002
          category: accessories
        pricing:
          unit_price: 15.00
          quantity: 3
          total: 45.00
    summary:
      subtotal: 95.00
      tax_rate: 0.08
      tax_amount: 7.60
      total: 102.60
```"""

        parsed_data, detected_format = extract_structured_data_from_text(text)

        assert detected_format == "yaml"
        assert isinstance(parsed_data, dict)

        # Test deep nested access
        doc = parsed_data["document"]
        assert doc["classification"]["type"] == "invoice"
        assert doc["classification"]["confidence"] == 0.95
        assert doc["extraction"]["vendor"]["name"] == "ACME Corporation"
        assert len(doc["extraction"]["line_items"]) == 2
        assert doc["extraction"]["line_items"][0]["pricing"]["total"] == 50.00
        assert doc["extraction"]["summary"]["total"] == 102.60


@pytest.mark.unit
@pytest.mark.skipif(
    YAML_AVAILABLE, reason="Test only runs when PyYAML is not available"
)
class TestYamlNotAvailable:
    """Tests for YAML functions when PyYAML is not available."""

    def test_extract_yaml_without_library(self):
        """Test YAML extraction when library is not available."""
        text = "key: value"
        result = extract_yaml_from_text(text)
        # Should return original text when YAML library is not available
        assert result == text

    def test_detect_format_without_yaml_library(self):
        """Test format detection when YAML library is not available."""
        # Should still detect JSON
        json_text = '{"key": "value"}'
        result = detect_format(json_text)
        assert result == "json"

        # Should return unknown for YAML-like content
        yaml_text = "key: value"
        result = detect_format(yaml_text)
        assert result == "unknown"

    def test_extract_structured_data_without_yaml_library(self):
        """Test structured data extraction when YAML library is not available."""
        # Should still work for JSON
        json_text = '{"key": "value"}'
        parsed_data, detected_format = extract_structured_data_from_text(json_text)
        assert detected_format == "json"
        assert parsed_data["key"] == "value"

        # Should return original text for YAML-like content
        yaml_text = "key: value"
        parsed_data, detected_format = extract_structured_data_from_text(yaml_text)
        assert detected_format == "unknown"
        assert parsed_data == yaml_text
