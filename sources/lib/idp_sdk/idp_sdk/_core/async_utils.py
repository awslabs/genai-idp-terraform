# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Async utilities for running coroutines from synchronous code."""

import asyncio
from typing import Any, Coroutine


def run_async(coro: Coroutine) -> Any:
    """Run a coroutine in a new event loop, with proper cleanup."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()
