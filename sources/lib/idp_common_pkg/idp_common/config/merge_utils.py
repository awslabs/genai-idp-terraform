# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Utility functions for configuration merging and manipulation.
"""

from typing import Dict, Any
from copy import deepcopy


def deep_update(target: Dict[str, Any], source: Dict[str, Any]) -> Dict[str, Any]:
    """
    Recursively update target dict with source dict.

    Nested dictionaries are merged recursively. Other values are deep copied
    to avoid mutation issues.

    Args:
        target: Target dictionary to update
        source: Source dictionary with updates

    Returns:
        Updated target dictionary (modified in place)
    """
    for key, value in source.items():
        if key in target and isinstance(target[key], dict) and isinstance(value, dict):
            deep_update(target[key], value)
        else:
            target[key] = deepcopy(value)
    return target


def get_diff_dict(base: Dict[str, Any], modified: Dict[str, Any]) -> Dict[str, Any]:
    """
    Get a dictionary containing only the fields that differ between base and modified.

    This creates a "diff dict" that when applied to base (via deep_update) would
    produce modified. Recursively compares nested dictionaries.

    Args:
        base: Base/default dictionary
        modified: Modified/custom dictionary

    Returns:
        Dictionary containing only the differences (values from modified that differ from base)

    Example:
        base = {"a": 1, "b": {"c": 2, "d": 3}}
        modified = {"a": 1, "b": {"c": 5, "d": 3}, "e": 6}
        result = {"b": {"c": 5}, "e": 6}  # Only changed/added fields
    """
    diff = {}

    # Check for added or changed keys in modified
    for key, value in modified.items():
        if key not in base:
            # New key - include it
            diff[key] = deepcopy(value)
        elif isinstance(value, dict) and isinstance(base[key], dict):
            # Both are dicts - recurse
            nested_diff = get_diff_dict(base[key], value)
            if nested_diff:  # Only include if there are differences
                diff[key] = nested_diff
        elif value != base[key]:
            # Value changed
            diff[key] = deepcopy(value)

    # Note: We don't track deletions (keys in base but not in modified)
    # This is intentional - Custom should always be a complete config

    return diff
