# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import pytest
from idp_common.ocr.document_converter import DocumentConverter


@pytest.mark.unit
def test_document_converter_initialization():
    """Test DocumentConverter initialization."""
    converter = DocumentConverter(dpi=150)
    assert converter.dpi == 150
    assert converter.page_width == int(8.5 * 150)
    assert converter.page_height == int(11 * 150)


@pytest.mark.unit
def test_convert_text_to_pages():
    """Test text to pages conversion."""
    converter = DocumentConverter(dpi=72)  # Lower DPI for faster testing

    # Test simple text
    text = "Hello World\nThis is a test"
    pages = converter.convert_text_to_pages(text)

    assert len(pages) >= 1
    assert isinstance(pages[0], tuple)
    assert len(pages[0]) == 2
    assert isinstance(pages[0][0], bytes)  # Image bytes
    assert isinstance(pages[0][1], str)  # Text content


@pytest.mark.unit
def test_convert_csv_to_pages():
    """Test CSV to pages conversion."""
    converter = DocumentConverter(dpi=72)

    csv_content = "Name,Age,City\nJohn,25,NYC\nJane,30,LA"
    pages = converter.convert_csv_to_pages(csv_content)

    assert len(pages) >= 1
    assert isinstance(pages[0][0], bytes)
    assert "Name" in pages[0][1]
    assert "John" in pages[0][1]


@pytest.mark.unit
def test_format_csv_as_table():
    """Test CSV table formatting."""
    converter = DocumentConverter()

    rows = [["Name", "Age"], ["John", "25"], ["Jane", "30"]]
    formatted = converter._format_csv_as_table(rows)

    assert "Name" in formatted
    assert "John" in formatted
    assert "|" in formatted  # Table separator


@pytest.mark.unit
def test_create_empty_page():
    """Test empty page creation."""
    converter = DocumentConverter(dpi=72)

    empty_page = converter._create_empty_page()
    assert isinstance(empty_page, bytes)
    assert len(empty_page) > 0
