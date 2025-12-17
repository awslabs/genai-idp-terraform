# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Pytest configuration file for the IDP Common package tests.
"""

import sys
from unittest.mock import MagicMock

# Mock external dependencies that may not be available in test environments
# These mocks need to be set up before any imports that might use these packages

# Mock strands modules for agent functionality
sys.modules["strands"] = MagicMock()
sys.modules["strands.models"] = MagicMock()
sys.modules["strands.hooks"] = MagicMock()
sys.modules["strands.hooks.events"] = MagicMock()

# Mock bedrock_agentcore modules for secure code execution
sys.modules["bedrock_agentcore"] = MagicMock()
sys.modules["bedrock_agentcore.tools"] = MagicMock()
sys.modules["bedrock_agentcore.tools.code_interpreter_client"] = MagicMock()

# PIL module is now used directly for document conversion functionality
# No mocking needed as PIL is a required dependency for the OCR module
