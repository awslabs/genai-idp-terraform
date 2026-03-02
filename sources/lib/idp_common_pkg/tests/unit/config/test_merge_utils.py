# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Tests for configuration merge utilities.
"""

from idp_common.config.merge_utils import deep_update, get_diff_dict


class TestDeepUpdate:
    """Test deep_update function."""

    def test_simple_update(self):
        """Test simple key-value update."""
        target = {"a": 1, "b": 2}
        source = {"b": 3, "c": 4}
        result = deep_update(target, source)

        assert result == {"a": 1, "b": 3, "c": 4}
        assert result is target  # Modified in place

    def test_nested_dict_merge(self):
        """Test nested dictionary merge."""
        target = {"config": {"temp": 0.5, "top_p": 0.9}, "other": 1}
        source = {"config": {"temp": 1.0}}
        result = deep_update(target, source)

        assert result == {"config": {"temp": 1.0, "top_p": 0.9}, "other": 1}

    def test_deeply_nested_merge(self):
        """Test deeply nested dictionary merge."""
        target = {"level1": {"level2": {"level3": {"a": 1, "b": 2}}}}
        source = {"level1": {"level2": {"level3": {"b": 99, "c": 3}}}}
        result = deep_update(target, source)

        assert result["level1"]["level2"]["level3"] == {"a": 1, "b": 99, "c": 3}

    def test_override_dict_with_value(self):
        """Test that dict can be replaced with non-dict value."""
        target = {"config": {"nested": "value"}}
        source = {"config": "simple_string"}
        result = deep_update(target, source)

        assert result == {"config": "simple_string"}

    def test_override_value_with_dict(self):
        """Test that value can be replaced with dict."""
        target = {"config": "simple_string"}
        source = {"config": {"nested": "value"}}
        result = deep_update(target, source)

        assert result == {"config": {"nested": "value"}}

    def test_empty_source(self):
        """Test update with empty source."""
        target = {"a": 1, "b": 2}
        source = {}
        result = deep_update(target, source)

        assert result == {"a": 1, "b": 2}

    def test_empty_target(self):
        """Test update on empty target."""
        target = {}
        source = {"a": 1, "b": 2}
        result = deep_update(target, source)

        assert result == {"a": 1, "b": 2}

    def test_list_values_replaced(self):
        """Test that list values are replaced, not merged."""
        target = {"items": [1, 2, 3]}
        source = {"items": [4, 5]}
        result = deep_update(target, source)

        assert result == {"items": [4, 5]}

    def test_deep_copy_prevents_mutation(self):
        """Test that values are deep copied to prevent mutation."""
        nested_list = [1, 2, 3]
        target = {"a": 1}
        source = {"b": nested_list}
        result = deep_update(target, source)

        # Modify original list
        nested_list.append(4)

        # Result should not be affected
        assert result["b"] == [1, 2, 3]


class TestGetDiffDict:
    """Test get_diff_dict function."""

    def test_no_differences(self):
        """Test when dicts are identical."""
        base = {"a": 1, "b": 2}
        modified = {"a": 1, "b": 2}
        diff = get_diff_dict(base, modified)

        assert diff == {}

    def test_simple_value_change(self):
        """Test simple value change."""
        base = {"a": 1, "b": 2}
        modified = {"a": 1, "b": 3}
        diff = get_diff_dict(base, modified)

        assert diff == {"b": 3}

    def test_added_key(self):
        """Test new key added."""
        base = {"a": 1}
        modified = {"a": 1, "b": 2}
        diff = get_diff_dict(base, modified)

        assert diff == {"b": 2}

    def test_removed_key_ignored(self):
        """Test that removed keys are not tracked in diff."""
        base = {"a": 1, "b": 2}
        modified = {"a": 1}
        diff = get_diff_dict(base, modified)

        # Diff should be empty - we don't track removals
        assert diff == {}

    def test_nested_value_change(self):
        """Test nested value change."""
        base = {"config": {"temp": 0.5, "top_p": 0.9}}
        modified = {"config": {"temp": 1.0, "top_p": 0.9}}
        diff = get_diff_dict(base, modified)

        assert diff == {"config": {"temp": 1.0}}

    def test_nested_key_added(self):
        """Test new nested key added."""
        base = {"config": {"temp": 0.5}}
        modified = {"config": {"temp": 0.5, "top_p": 0.9}}
        diff = get_diff_dict(base, modified)

        assert diff == {"config": {"top_p": 0.9}}

    def test_multiple_nested_changes(self):
        """Test multiple changes at different nesting levels."""
        base = {
            "extraction": {"temp": 0.5, "model": "nova"},
            "assessment": {"enabled": True},
        }
        modified = {
            "extraction": {"temp": 1.0, "model": "nova"},
            "assessment": {"enabled": True},
            "new_section": {"value": 42},
        }
        diff = get_diff_dict(base, modified)

        assert diff == {"extraction": {"temp": 1.0}, "new_section": {"value": 42}}

    def test_entire_nested_dict_replaced(self):
        """Test when entire nested dict is replaced."""
        base = {"config": {"a": 1, "b": 2}}
        modified = {"config": {"c": 3, "d": 4}}
        diff = get_diff_dict(base, modified)

        # All values in config differ
        assert diff == {"config": {"c": 3, "d": 4}}

    def test_empty_base(self):
        """Test diff when base is empty."""
        base = {}
        modified = {"a": 1, "b": 2}
        diff = get_diff_dict(base, modified)

        assert diff == {"a": 1, "b": 2}

    def test_empty_modified(self):
        """Test diff when modified is empty."""
        base = {"a": 1, "b": 2}
        modified = {}
        diff = get_diff_dict(base, modified)

        # All keys removed - not tracked
        assert diff == {}

    def test_complex_nested_scenario(self):
        """Test complex real-world scenario."""
        base = {
            "extraction": {
                "model": "nova-pro",
                "temperature": 0.0,
                "top_p": 0.1,
                "image": {"dpi": 300},
            },
            "assessment": {"enabled": True, "model": "claude"},
        }
        modified = {
            "extraction": {
                "model": "nova-premier",  # Changed
                "temperature": 0.0,  # Same
                "top_p": 0.5,  # Changed
                "image": {"dpi": 300, "width": 1024},  # Added nested
            },
            "assessment": {"enabled": True, "model": "claude"},
            "custom_field": "value",  # Added top-level
        }
        diff = get_diff_dict(base, modified)

        assert diff == {
            "extraction": {
                "model": "nova-premier",
                "top_p": 0.5,
                "image": {"width": 1024},
            },
            "custom_field": "value",
        }

    def test_deep_copy_in_diff(self):
        """Test that diff values are deep copied."""
        nested_list = [1, 2, 3]
        base = {"a": 1}
        modified = {"a": 1, "b": nested_list}
        diff = get_diff_dict(base, modified)

        # Modify original list
        nested_list.append(4)

        # Diff should not be affected
        assert diff["b"] == [1, 2, 3]

    def test_diff_can_recreate_modified(self):
        """Test that applying diff to base recreates modified (except deletions)."""
        base = {"a": 1, "b": {"c": 2, "d": 3}, "e": 5}
        modified = {
            "a": 1,
            "b": {"c": 99, "d": 3},  # c changed
            "e": 5,
            "f": 6,  # added
            # Note: we keep all fields, nothing deleted
        }

        diff = get_diff_dict(base, modified)

        # Apply diff to base
        from copy import deepcopy

        result = deepcopy(base)
        deep_update(result, diff)

        # Result should match modified
        assert result == modified
