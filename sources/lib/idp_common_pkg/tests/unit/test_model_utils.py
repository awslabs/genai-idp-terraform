# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Unit tests for model_utils module."""

import pytest
from idp_common.bedrock.model_utils import parse_model_id


@pytest.mark.unit
class TestParseModelId:
    """Test model ID parsing functionality."""

    def test_parse_model_without_suffix(self):
        """Test parsing model ID without service tier suffix."""
        base_id, tier = parse_model_id("us.amazon.nova-2-lite-v1:0")
        assert base_id == "us.amazon.nova-2-lite-v1:0"
        assert tier is None

    def test_parse_model_with_flex_suffix(self):
        """Test parsing model ID with flex suffix."""
        base_id, tier = parse_model_id("us.amazon.nova-2-lite-v1:0:flex")
        assert base_id == "us.amazon.nova-2-lite-v1:0"
        assert tier == "flex"

    def test_parse_model_with_priority_suffix(self):
        """Test parsing model ID with priority suffix."""
        base_id, tier = parse_model_id("us.amazon.nova-2-lite-v1:0:priority")
        assert base_id == "us.amazon.nova-2-lite-v1:0"
        assert tier == "priority"

    def test_parse_model_with_uppercase_suffix(self):
        """Test parsing model ID with uppercase suffix."""
        base_id, tier = parse_model_id("us.amazon.nova-2-lite-v1:0:FLEX")
        assert base_id == "us.amazon.nova-2-lite-v1:0"
        assert tier == "flex"

    def test_parse_model_with_invalid_suffix(self):
        """Test parsing model ID with invalid suffix."""
        base_id, tier = parse_model_id("us.amazon.nova-2-lite-v1:0:invalid")
        assert base_id == "us.amazon.nova-2-lite-v1:0:invalid"
        assert tier is None

    def test_parse_empty_string(self):
        """Test parsing empty string."""
        base_id, tier = parse_model_id("")
        assert base_id == ""
        assert tier is None

    def test_parse_none(self):
        """Test parsing None."""
        base_id, tier = parse_model_id(None)
        assert base_id is None
        assert tier is None

    def test_parse_model_with_1m_and_tier(self):
        """Test parsing model ID with both 1m and tier suffix."""
        # This should not happen in practice, but test behavior
        base_id, tier = parse_model_id("us.anthropic.claude-3-5-haiku:1m:flex")
        assert base_id == "us.anthropic.claude-3-5-haiku:1m"
        assert tier == "flex"

    def test_parse_global_model_with_flex(self):
        """Test parsing global model with flex suffix."""
        base_id, tier = parse_model_id("global.amazon.nova-2-lite-v1:0:flex")
        assert base_id == "global.amazon.nova-2-lite-v1:0"
        assert tier == "flex"

    def test_parse_global_model_with_priority(self):
        """Test parsing global model with priority suffix."""
        base_id, tier = parse_model_id("global.amazon.nova-2-lite-v1:0:priority")
        assert base_id == "global.amazon.nova-2-lite-v1:0"
        assert tier == "priority"
