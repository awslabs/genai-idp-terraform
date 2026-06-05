# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Chat operations for IDP SDK."""

from typing import Optional

from idp_sdk.exceptions import IDPProcessingError
from idp_sdk.models.chat import ChatResponse


class ChatOperation:
    """Agent Companion Chat operations.

    Provides programmatic access to the multi-agent orchestrator
    (Analytics, Error Analyzer, etc.) from Python code.

    Example:
        >>> client = IDPClient(stack_name="IDP")
        >>> resp = client.chat.send_message("How many documents processed today?")
        >>> print(resp.response)

        # Multi-turn conversation
        >>> resp = client.chat.send_message("Break that down by document type",
        ...     session_id=resp.session_id)
    """

    def __init__(self, client):
        self._client = client
        self._processor = None
        self._processor_cache = {}

    def _get_processor(self, stack_name=None):
        name = stack_name or self._client._require_stack()
        if name not in self._processor_cache:
            from idp_sdk._core.chat_processor import ChatProcessor

            self._processor_cache[name] = ChatProcessor(
                stack_name=name, region=self._client._region
            )
        if not stack_name:
            self._processor = self._processor_cache[name]
        return self._processor_cache[name]

    def send_message(
        self,
        prompt: str,
        session_id: Optional[str] = None,
        stack_name: Optional[str] = None,
    ) -> ChatResponse:
        """Send a message to the Agent Companion Chat.

        Args:
            prompt: Natural language message
            session_id: Session ID for multi-turn conversations.
                        Reuse from a previous ChatResponse.session_id.
            stack_name: Optional stack name override

        Returns:
            ChatResponse with response text and session_id
        """
        processor = self._get_processor(stack_name)

        try:
            return processor.send_message(prompt=prompt, session_id=session_id)
        except Exception as e:
            raise IDPProcessingError(f"Chat request failed: {e}") from e
