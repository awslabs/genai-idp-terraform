#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Verification script for Stickler installation.

This script tests that Stickler is properly installed and all required
features are available for the IDP evaluation system.
"""

import sys
from typing import Any, Dict


def verify_stickler_import():
    """Verify Stickler can be imported."""
    try:
        import stickler

        print("✓ Stickler imported successfully")
        print(f"  Location: {stickler.__file__}")
        return True
    except ImportError as e:
        print(f"✗ Failed to import Stickler: {e}")
        return False


def verify_structured_model():
    """Verify StructuredModel is available."""
    try:
        from stickler import StructuredModel  # noqa: F401

        print("✓ StructuredModel available")
        return True
    except ImportError as e:
        print(f"✗ Failed to import StructuredModel: {e}")
        return False


def verify_comparators():
    """Verify required comparators are available."""
    try:
        from stickler.comparators import (  # noqa: F401
            ExactComparator,
            FuzzyComparator,
            LevenshteinComparator,
            NumericComparator,
        )

        print("✓ All required comparators available")
        print("  - ExactComparator")
        print("  - LevenshteinComparator")
        print("  - NumericComparator")
        print("  - FuzzyComparator")
        return True
    except ImportError as e:
        print(f"✗ Failed to import comparators: {e}")
        return False


def verify_dynamic_model_creation():
    """Verify dynamic model creation from JSON works."""
    try:
        from stickler import StructuredModel

        # Test configuration
        config: Dict[str, Any] = {
            "model_name": "TestModel",
            "match_threshold": 0.8,
            "fields": {
                "name": {"type": "str", "comparator": "ExactComparator", "weight": 1.0},
                "value": {
                    "type": "float",
                    "comparator": "NumericComparator",
                    "weight": 1.5,
                },
            },
        }

        # Create dynamic model
        TestModel = StructuredModel.model_from_json(config)

        # Test instantiation - type checker can't understand dynamic model creation
        test1 = TestModel(**{"name": "Test", "value": 42.0})  # type: ignore
        test2 = TestModel(**{"name": "Test", "value": 42.1})  # type: ignore

        # Test comparison
        result = test1.compare_with(test2)

        print("✓ Dynamic model creation works")
        print(f"  Model created: {TestModel.__name__}")
        print(f"  Comparison result: {result.get('overall_score', 'N/A'):.3f}")
        return True
    except Exception as e:
        print(f"✗ Dynamic model creation failed: {e}")
        import traceback

        traceback.print_exc()
        return False


def verify_list_matching():
    """Verify list matching with Hungarian algorithm."""
    try:
        from stickler import StructuredModel

        config: Dict[str, Any] = {
            "model_name": "ListTestModel",
            "fields": {
                "items": {
                    "type": "list_structured_model",
                    "fields": {
                        "id": {"type": "str", "comparator": "ExactComparator"},
                        "name": {"type": "str", "comparator": "LevenshteinComparator"},
                    },
                }
            },
        }

        ListTestModel = StructuredModel.model_from_json(config)

        # Test with reordered lists - type checker can't understand dynamic model creation
        test1 = ListTestModel(  # type: ignore
            **{"items": [{"id": "A", "name": "Alice"}, {"id": "B", "name": "Bob"}]}
        )
        test2 = ListTestModel(  # type: ignore
            **{"items": [{"id": "B", "name": "Bob"}, {"id": "A", "name": "Alice"}]}
        )

        result = test1.compare_with(test2)

        print("✓ List matching with Hungarian algorithm works")
        print(f"  Comparison score: {result.get('overall_score', 'N/A'):.3f}")
        return True
    except Exception as e:
        print(f"✗ List matching failed: {e}")
        import traceback

        traceback.print_exc()
        return False


def main():
    """Run all verification tests."""
    print("=" * 80)
    print("Stickler Installation Verification")
    print("=" * 80)
    print()

    tests = [
        ("Import", verify_stickler_import),
        ("StructuredModel", verify_structured_model),
        ("Comparators", verify_comparators),
        ("Dynamic Model Creation", verify_dynamic_model_creation),
        ("List Matching", verify_list_matching),
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\nTest: {test_name}")
        print("-" * 80)
        success = test_func()
        results.append((test_name, success))
        print()

    print("=" * 80)
    print("Summary")
    print("=" * 80)

    passed = sum(1 for _, success in results if success)
    total = len(results)

    for test_name, success in results:
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"{status:8} {test_name}")

    print()
    print(f"Results: {passed}/{total} tests passed")
    print("=" * 80)

    if passed == total:
        print("\n✅ All verification tests passed!")
        print("Stickler is properly installed and ready to use.")
        return 0
    else:
        print(f"\n❌ {total - passed} test(s) failed!")
        print(
            "Please check the error messages above and ensure Stickler is properly installed."
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
