# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from datetime import datetime, timedelta

import pytest


@pytest.mark.unit
def test_time_period_calculation():
    """Test time period cutoff calculation"""
    # Test 1 week (168 hours)
    time_period_hours = 168
    cutoff_time = datetime.utcnow() - timedelta(hours=time_period_hours)

    # Should be 7 days ago
    expected_days = 7
    actual_days = (datetime.utcnow() - cutoff_time).days
    assert abs(actual_days - expected_days) <= 1  # Allow for minor time differences

    # Test 24 hours
    time_period_hours = 24
    cutoff_time = datetime.utcnow() - timedelta(hours=time_period_hours)

    # Should be 1 day ago
    expected_days = 1
    actual_days = (datetime.utcnow() - cutoff_time).days
    assert abs(actual_days - expected_days) <= 1


@pytest.mark.unit
def test_iso_format_with_z_suffix():
    """Test ISO format with Z suffix for GraphQL"""
    test_time = datetime(2024, 1, 1, 12, 0, 0)
    iso_string = test_time.isoformat() + "Z"

    assert iso_string == "2024-01-01T12:00:00Z"
    assert iso_string.endswith("Z")
