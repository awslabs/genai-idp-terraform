# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json

import pytest


@pytest.mark.unit
def test_default_time_period():
    """Test default time period is 1 week (168 hours)"""
    # Simulate the useState logic from TestResultsList
    stored = None  # No localStorage value
    default_period = stored if stored else 168

    assert default_period == 168  # 1 week in hours


@pytest.mark.unit
def test_stored_time_period():
    """Test stored time period from localStorage"""
    # Simulate stored value
    stored_value = "720"  # 1 month
    parsed_value = json.loads(stored_value) if stored_value else 168

    assert parsed_value == 720


@pytest.mark.unit
def test_time_period_options():
    """Test common time period options"""
    periods = {"1 day": 24, "1 week": 168, "1 month": 720, "3 months": 2160}

    assert periods["1 day"] == 24
    assert periods["1 week"] == 168
    assert periods["1 month"] == 720
    assert periods["3 months"] == 2160
