# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Criteria Validation module for IDP documents.

This module provides services and models for validating documents against
dynamic business rules/criteria using LLMs for healthcare/insurance prior
authorization validation.
"""

from idp_common.criteria_validation.models import (
    BedrockInput,
    CriteriaValidationResult,
    LLMResponse,
)
from idp_common.criteria_validation.service import CriteriaValidationService

__all__ = [
    "CriteriaValidationService",
    "BedrockInput",
    "LLMResponse",
    "CriteriaValidationResult",
]
