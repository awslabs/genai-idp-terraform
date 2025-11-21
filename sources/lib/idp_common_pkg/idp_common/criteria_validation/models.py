# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Models for criteria validation using LLMs.

This module provides data models for validation inputs and results.
"""

import re
from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class BedrockInput:
    """Input model for Bedrock LLM criteria validation."""

    question: str
    prompt: str
    system_prompt: str
    criteria_type: str
    recommendation: str
    user_history: Optional[str] = None
    txt_file_uri: Optional[str] = None
    initial_response: Optional[List] = None

    def __post_init__(self):
        """Validate and clean input data."""
        # Strip whitespace from string fields
        if isinstance(self.question, str):
            self.question = self.question.strip()
        if isinstance(self.prompt, str):
            self.prompt = self.prompt.strip()
        if isinstance(self.system_prompt, str):
            self.system_prompt = self.system_prompt.strip()
        if isinstance(self.criteria_type, str):
            self.criteria_type = self.criteria_type.strip()
        if isinstance(self.recommendation, str):
            self.recommendation = self.recommendation.strip()
        if self.user_history and isinstance(self.user_history, str):
            self.user_history = self.user_history.strip()
        if self.txt_file_uri and isinstance(self.txt_file_uri, str):
            self.txt_file_uri = self.txt_file_uri.strip()

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)


@dataclass
class LLMResponse:
    """Response model from LLM for criteria validation."""

    criteria_type: str
    question: str
    Recommendation: str
    Reasoning: str
    source_file: List[str] = field(default_factory=list)

    def __init__(self, **kwargs):
        """Custom init to enforce extra="forbid" behavior."""
        # Get the expected field names
        expected_fields = {
            "criteria_type",
            "question",
            "Recommendation",
            "Reasoning",
            "source_file",
        }

        # Check for extra fields
        extra_fields = set(kwargs.keys()) - expected_fields
        if extra_fields:
            raise TypeError(f"Unexpected keyword arguments: {extra_fields}")

        # Set defaults for missing fields
        self.criteria_type = kwargs.get("criteria_type")
        self.question = kwargs.get("question")
        self.Recommendation = kwargs.get("Recommendation")
        self.Reasoning = kwargs.get("Reasoning")
        self.source_file = kwargs.get("source_file", [])

        # Call post_init for validation
        self.__post_init__()

    def __post_init__(self):
        """Validate and clean input data."""
        # Strip whitespace from string fields
        if isinstance(self.criteria_type, str):
            self.criteria_type = self.criteria_type.strip()
        if isinstance(self.question, str):
            self.question = self.question.strip()

        # Validate and clean Recommendation
        if isinstance(self.Recommendation, str):
            self.Recommendation = self.Recommendation.strip()
            valid_values = ["Pass", "Fail", "Information Not Found"]
            if self.Recommendation not in valid_values:
                raise ValueError(f"Recommendation must be one of {valid_values}")

        # Clean Reasoning
        if self.Reasoning:
            if isinstance(self.Reasoning, str):
                # Remove line breaks and extra spaces
                self.Reasoning = " ".join(self.Reasoning.split())

                # Remove or replace problematic characters
                self.Reasoning = re.sub(
                    r"[^\x20-\x7E]", "", self.Reasoning
                )  # Remove non-printable characters

                # Remove markdown-style bullets and numbers
                self.Reasoning = re.sub(r"^\s*[-*•]\s*", "", self.Reasoning)
                self.Reasoning = re.sub(r"^\s*\d+\.\s*", "", self.Reasoning)

        # Validate source files
        if self.source_file is None:
            self.source_file = []
        elif isinstance(self.source_file, list):
            # Ensure all files are s3:// URLs
            self.source_file = [
                f if f.startswith("s3://") else f"s3://{f}" for f in self.source_file
            ]

    def dict(self) -> Dict[str, Any]:
        """Convert to dictionary (compatibility method for Pydantic migration)."""
        return asdict(self)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)


@dataclass
class CriteriaValidationResult:
    """Result of criteria validation for a document request."""

    request_id: str
    criteria_type: str
    validation_responses: List[Dict[str, Any]]
    summary: Optional[Dict[str, Any]] = None
    metering: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None
    output_uri: Optional[str] = None
    errors: Optional[List[str]] = None
    cost_tracking: Optional[Dict[str, Any]] = None
