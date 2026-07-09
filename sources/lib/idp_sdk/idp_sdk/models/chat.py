# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Chat models for IDP SDK."""

from dataclasses import dataclass, field
from typing import List


@dataclass
class ChatResponse:
    """Response from a chat message."""

    response: str
    session_id: str
    agent_names: List[str] = field(default_factory=list)
