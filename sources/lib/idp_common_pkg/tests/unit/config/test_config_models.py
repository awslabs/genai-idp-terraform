# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Tests for configuration Pydantic models.
"""

import pytest
from idp_common.config.models import (
    AgenticConfig,
    AssessmentConfig,
    ExtractionConfig,
    IDPConfig,
)


class TestConfigModels:
    """Test configuration Pydantic models"""

    def test_agentic_config_with_booleans(self):
        """Test AgenticConfig with boolean values"""
        config_dict = {"enabled": False, "review_agent": True}
        config = AgenticConfig.model_validate(config_dict)

        assert config.enabled is False
        assert config.review_agent is True
        assert isinstance(config.enabled, bool)
        assert isinstance(config.review_agent, bool)

    def test_agentic_config_with_string_booleans(self):
        """Test AgenticConfig with string boolean values (legacy)"""
        config_dict = {"enabled": "false", "review_agent": "true"}
        config = AgenticConfig.model_validate(config_dict)

        # Pydantic should convert string booleans
        assert config.enabled is False
        assert config.review_agent is True

    def test_extraction_config_with_string_numbers(self):
        """Test ExtractionConfig with string numeric values"""
        config_dict = {
            "model": "us.amazon.nova-pro-v1:0",
            "temperature": "0.5",
            "top_p": "0.1",
            "top_k": "5",
            "max_tokens": "10000",
            "agentic": {"enabled": False, "review_agent": False},
        }
        config = ExtractionConfig.model_validate(config_dict)

        # Validators should convert strings to numbers
        assert config.temperature == 0.5
        assert config.top_p == 0.1
        assert config.top_k == 5.0
        assert config.max_tokens == 10000

        # Types should be correct
        assert isinstance(config.temperature, float)
        assert isinstance(config.top_p, float)
        assert isinstance(config.top_k, float)
        assert isinstance(config.max_tokens, int)

    def test_extraction_config_with_native_numbers(self):
        """Test ExtractionConfig with native numeric values"""
        config_dict = {
            "model": "us.amazon.nova-pro-v1:0",
            "temperature": 0.5,
            "top_p": 0.1,
            "top_k": 5.0,
            "max_tokens": 10000,
            "agentic": {"enabled": False, "review_agent": False},
        }
        config = ExtractionConfig.model_validate(config_dict)

        assert config.temperature == 0.5
        assert config.top_p == 0.1
        assert config.top_k == 5.0
        assert config.max_tokens == 10000

    def test_full_config_with_mixed_types(self):
        """Test full IDPConfig with mixed type representations"""
        config_dict = {
            "ocr": {
                "backend": "textract",
                "features": [{"name": "LAYOUT"}, {"name": "TABLES"}],
            },
            "classification": {
                "model": "us.amazon.nova-pro-v1:0",
                "temperature": "0.0",
                "top_p": "0.1",
                "top_k": "5",
                "max_tokens": "4096",
            },
            "extraction": {
                "model": "us.amazon.nova-pro-v1:0",
                "temperature": 0.0,
                "top_p": 0.1,
                "top_k": 5,
                "max_tokens": 10000,
                "agentic": {"enabled": False, "review_agent": True},
            },
            "assessment": {
                "model": "us.amazon.nova-lite-v1:0",
                "enabled": True,
                "temperature": "0.0",
                "granular": {"enabled": False, "list_batch_size": "1"},
            },
            "classes": [],
        }

        config = IDPConfig.model_validate(config_dict)

        # Booleans
        assert config.extraction.agentic.enabled is False
        assert config.extraction.agentic.review_agent is True
        assert config.assessment.enabled is True

        # Numbers from strings
        assert config.classification.temperature == 0.0
        assert config.classification.max_tokens == 4096

        # Numbers from natives
        assert config.extraction.top_p == 0.1
        assert config.extraction.max_tokens == 10000

    def test_config_type_hints(self):
        """Test that config can be used as type hint"""

        def process_config(config: ExtractionConfig) -> bool:
            """Example function with type hint"""
            if config.agentic.enabled:
                return True
            return False

        config_dict = {
            "model": "us.amazon.nova-pro-v1:0",
            "agentic": {"enabled": True},
        }
        config = ExtractionConfig.model_validate(config_dict)

        # This should work with type hints
        result = process_config(config)
        assert result is True

    def test_assessment_granular_config(self):
        """Test granular assessment configuration"""
        config_dict = {
            "model": "us.amazon.nova-lite-v1:0",
            "granular": {
                "enabled": True,
                "list_batch_size": "5",
                "simple_batch_size": "10",
                "max_workers": "20",
            },
        }
        config = AssessmentConfig.model_validate(config_dict)

        assert config.granular.enabled is True
        assert config.granular.list_batch_size == 5
        assert config.granular.simple_batch_size == 10
        assert config.granular.max_workers == 20

    def test_config_validation_range_checks(self):
        """Test that validation enforces ranges"""
        # temperature must be between 0 and 1
        with pytest.raises(Exception):  # Pydantic ValidationError
            ExtractionConfig.model_validate(
                {
                    "model": "test",
                    "temperature": 2.0,  # Invalid: > 1.0
                }
            )

    def test_config_defaults(self):
        """Test that defaults are applied correctly"""
        config_dict = {
            "model": "us.amazon.nova-pro-v1:0",
            # No agentic config provided
        }
        config = ExtractionConfig.model_validate(config_dict)

        # Should have defaults
        assert config.agentic.enabled is False
        assert config.agentic.review_agent is False
        assert config.temperature == 0.0
        assert config.max_tokens == 10000
