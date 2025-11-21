# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the OCR results module.
"""

import pytest


@pytest.mark.unit
class TestOcrResults:
    """Tests for the OCR results module."""

    def test_module_deprecation(self):
        """Test that the module is properly marked as deprecated."""
        import idp_common.ocr.results

        # Check that the module docstring indicates it's deprecated
        assert "deprecated" in idp_common.ocr.results.__doc__.lower()

        # Check that the docstring mentions where functionality was moved
        assert "idp_common.models" in idp_common.ocr.results.__doc__
