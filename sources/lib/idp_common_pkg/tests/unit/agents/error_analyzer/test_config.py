# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for Error Analyzer configuration.
"""

import pytest
from idp_common.agents.error_analyzer.config import get_aws_service_capabilities
from idp_common.config.models import (
    ErrorAnalyzerConfig,
    ErrorAnalyzerParameters,
)


@pytest.mark.unit
class TestErrorAnalyzerConfig:
    """Test error analyzer configuration functions."""

    def test_default_error_patterns(self):
        """Test default error patterns in ErrorAnalyzerConfig."""
        config = ErrorAnalyzerConfig()

        assert isinstance(config.error_patterns, list)
        assert len(config.error_patterns) > 0
        assert "ERROR" in config.error_patterns
        assert "Exception" in config.error_patterns
        assert "Timeout" in config.error_patterns
        assert "ThrottlingException" in config.error_patterns

    def test_get_aws_service_capabilities(self):
        """Test AWS service capabilities are returned."""
        capabilities = get_aws_service_capabilities()

        assert isinstance(capabilities, dict)
        assert "cloudwatch_logs" in capabilities
        assert "dynamodb" in capabilities
        assert "benefits" in capabilities

        # Check CloudWatch capabilities
        cw_caps = capabilities["cloudwatch_logs"]
        assert "description" in cw_caps
        assert "capabilities" in cw_caps
        assert "search_log_events" in cw_caps["capabilities"]
        assert "implementation" in cw_caps

        # Check DynamoDB capabilities
        db_caps = capabilities["dynamodb"]
        assert "description" in db_caps
        assert "capabilities" in db_caps
        assert "scan_table" in db_caps["capabilities"]
        assert "implementation" in db_caps

    def test_error_analyzer_parameters_defaults(self):
        """Test ErrorAnalyzerParameters default values."""
        params = ErrorAnalyzerParameters()

        assert params.max_log_events == 5
        assert params.time_range_hours_default == 24
        assert params.max_log_message_length == 400
        assert params.max_events_per_log_group == 5
        assert params.max_log_groups == 20
        assert params.max_stepfunction_timeline_events == 3
        assert params.max_stepfunction_error_length == 400
        assert params.xray_slow_segment_threshold_ms == 5000
        assert params.xray_error_rate_threshold == 0.05
        assert params.xray_response_time_threshold_ms == 10000

    def test_error_analyzer_config_defaults(self):
        """Test ErrorAnalyzerConfig default values."""
        config = ErrorAnalyzerConfig()

        assert config.model_id == "us.anthropic.claude-sonnet-4-20250514-v1:0"
        assert isinstance(config.system_prompt, str)
        assert len(config.system_prompt) > 0
        assert isinstance(config.parameters, ErrorAnalyzerParameters)
        assert config.parameters.max_log_events == 5
