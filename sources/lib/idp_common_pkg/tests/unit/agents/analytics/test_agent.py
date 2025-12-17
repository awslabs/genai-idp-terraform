# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the analytics agent module.
"""

# ruff: noqa: E402, I001
# The above line disables E402 (module level import not at top of file) and I001 (import block sorting) for this file

import sys
from unittest.mock import MagicMock, patch

import pytest

# Mock strands modules before importing analytics modules
sys.modules["strands"] = MagicMock()
sys.modules["strands.models"] = MagicMock()

# Mock bedrock_agentcore modules before importing analytics modules
sys.modules["bedrock_agentcore"] = MagicMock()
sys.modules["bedrock_agentcore.tools"] = MagicMock()
sys.modules["bedrock_agentcore.tools.code_interpreter_client"] = MagicMock()


@pytest.mark.unit
class TestCreateAnalyticsAgent:
    """Tests for the create_analytics_agent function."""

    @patch("idp_common.agents.analytics.config.load_python_plot_generation_examples")
    @patch("idp_common.agents.common.config.load_result_format_description")
    @patch("idp_common.agents.analytics.agent.strands.Agent")
    @patch("boto3.Session")
    def test_create_analytics_agent_success(
        self, mock_session, mock_agent_class, mock_load_result, mock_load_examples
    ):
        """Test successful creation of analytics agent."""
        # Import here to avoid issues with mocking
        from idp_common.agents.analytics.agent import create_analytics_agent

        # Setup mocks
        mock_load_examples.return_value = "Test examples"
        mock_load_result.return_value = "Test result format"
        mock_agent_instance = MagicMock()
        mock_agent_class.return_value = mock_agent_instance
        mock_session_instance = MagicMock()
        mock_session.return_value = mock_session_instance

        config = {
            "aws_region": "us-east-1",
            "athena_database": "test_db",
            "athena_output_location": "s3://test-bucket/results/",
        }

        # Create agent
        result = create_analytics_agent(config, mock_session_instance)

        # Verify agent was created (basic check)
        assert result is not None
        # Verify Strands agent was called
        mock_agent_class.assert_called_once()
