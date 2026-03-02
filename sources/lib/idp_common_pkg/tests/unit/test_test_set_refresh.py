# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from datetime import datetime
from unittest.mock import Mock

import pytest


@pytest.mark.unit
def test_is_valid_test_set_structure():
    """Test validation of test set folder structure"""

    def _is_valid_test_set_structure(s3_client, bucket, prefix):
        """Check if prefix contains input/ and baseline/ folders"""
        try:
            # Check for input/ folder
            input_response = s3_client.list_objects_v2(
                Bucket=bucket, Prefix=f"{prefix}/input/", MaxKeys=1
            )

            # Check for baseline/ folder
            baseline_response = s3_client.list_objects_v2(
                Bucket=bucket, Prefix=f"{prefix}/baseline/", MaxKeys=1
            )

            has_input = input_response.get("KeyCount", 0) > 0
            has_baseline = baseline_response.get("KeyCount", 0) > 0

            return has_input and has_baseline

        except Exception:
            return False

    # Mock S3 client
    s3_client = Mock()

    # Test case: Valid structure (has both input/ and baseline/ folders)
    s3_client.list_objects_v2.side_effect = [
        {
            "KeyCount": 1,
            "Contents": [{"Key": "my-test-set/input/file1.pdf"}],
        },  # input/ folder
        {
            "KeyCount": 1,
            "Contents": [{"Key": "my-test-set/baseline/file1.pdf/result.json"}],
        },  # baseline/ folder
    ]

    result = _is_valid_test_set_structure(s3_client, "test-bucket", "my-test-set")
    assert result is True


@pytest.mark.unit
def test_validate_test_set_files_valid():
    """Test file validation with matching input and baseline files"""

    def _validate_test_set_files(s3_client, bucket, prefix):
        """Validate that input and baseline files match"""
        try:
            input_files = set()
            baseline_files = set()

            # Get input files
            paginator = s3_client.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket=bucket, Prefix=f"{prefix}/input/"):
                for obj in page.get("Contents", []):
                    key = obj["Key"]
                    if not key.endswith("/"):  # Skip directories
                        filename = key.split("/")[-1]
                        input_files.add(filename)

            # Get baseline folder names
            for page in paginator.paginate(Bucket=bucket, Prefix=f"{prefix}/baseline/"):
                for obj in page.get("Contents", []):
                    key = obj["Key"]
                    if not key.endswith("/"):  # Skip directories
                        # Extract folder name after /baseline/
                        parts = key.split(f"{prefix}/baseline/", 1)
                        if len(parts) == 2 and "/" in parts[1]:
                            path_parts = parts[1].split("/")
                            # Look for .pdf file in path
                            for part in path_parts:
                                if part.endswith(".pdf"):
                                    baseline_files.add(part)
                                    break

            # Validate matching
            if len(input_files) == 0:
                return {
                    "valid": False,
                    "error": "No input files found",
                    "input_count": 0,
                }

            if len(baseline_files) == 0:
                return {
                    "valid": False,
                    "error": "No baseline files found",
                    "input_count": len(input_files),
                }

            missing_baselines = input_files - baseline_files
            if missing_baselines:
                return {
                    "valid": False,
                    "error": f"Missing baseline files for: {', '.join(list(missing_baselines)[:3])}",
                    "input_count": len(input_files),
                }

            extra_baselines = baseline_files - input_files
            if extra_baselines:
                return {
                    "valid": False,
                    "error": f"Extra baseline files: {', '.join(list(extra_baselines)[:3])}",
                    "input_count": len(input_files),
                }

            return {"valid": True, "input_count": len(input_files)}

        except Exception as e:
            return {
                "valid": False,
                "error": f"Validation error: {str(e)}",
                "input_count": 0,
            }

    s3_client = Mock()

    # Mock paginator - same instance used for both calls
    paginator = Mock()
    paginator.paginate.side_effect = [
        # First call for input files
        [
            {
                "Contents": [
                    {"Key": "my-test-set/input/document1.pdf"},
                    {"Key": "my-test-set/input/document2.pdf"},
                ]
            }
        ],
        # Second call for baseline files
        [
            {
                "Contents": [
                    {"Key": "my-test-set/baseline/document1.pdf/sections/result.json"},
                    {"Key": "my-test-set/baseline/document2.pdf/extraction.json"},
                ]
            }
        ],
    ]

    s3_client.get_paginator.return_value = paginator

    result = _validate_test_set_files(s3_client, "test-bucket", "my-test-set")

    assert result["valid"] is True
    assert result["input_count"] == 2
    assert "error" not in result


@pytest.mark.unit
def test_validate_test_set_files_missing_baseline():
    """Test file validation with missing baseline files"""

    def _validate_test_set_files(s3_client, bucket, prefix):
        """Validate that input and baseline files match"""
        input_files = set()
        baseline_files = set()

        # Get input files
        paginator = s3_client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=bucket, Prefix=f"{prefix}/input/"):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                if not key.endswith("/"):
                    filename = key.split("/")[-1]
                    input_files.add(filename)

        # Get baseline folder names
        for page in paginator.paginate(Bucket=bucket, Prefix=f"{prefix}/baseline/"):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                if not key.endswith("/"):
                    parts = key.split(f"{prefix}/baseline/", 1)
                    if len(parts) == 2 and "/" in parts[1]:
                        path_parts = parts[1].split("/")
                        for part in path_parts:
                            if part.endswith(".pdf"):
                                baseline_files.add(part)
                                break

        missing_baselines = input_files - baseline_files
        if missing_baselines:
            return {
                "valid": False,
                "error": f"Missing baseline files for: {', '.join(list(missing_baselines))}",
                "input_count": len(input_files),
            }

        return {"valid": True, "input_count": len(input_files)}

    s3_client = Mock()

    # Mock paginator for input files
    input_paginator = Mock()
    input_paginator.paginate.return_value = [
        {
            "Contents": [
                {"Key": "my-test-set/input/document1.pdf"},
                {"Key": "my-test-set/input/document2.pdf"},
            ]
        }
    ]

    # Mock paginator for baseline files (missing document2.pdf)
    baseline_paginator = Mock()
    baseline_paginator.paginate.return_value = [
        {
            "Contents": [
                {"Key": "my-test-set/baseline/document1.pdf/sections/result.json"}
            ]
        }
    ]

    s3_client.get_paginator.side_effect = [input_paginator, baseline_paginator]

    result = _validate_test_set_files(s3_client, "test-bucket", "my-test-set")

    assert result["valid"] is False
    assert result["input_count"] == 2
    assert "Missing baseline files for:" in result["error"]
    assert "document2.pdf" in result["error"]


@pytest.mark.unit
def test_get_test_set_creation_time():
    """Test getting creation time from S3 objects"""

    def _get_test_set_creation_time(s3_client, bucket, prefix):
        """Get the earliest creation time from files in the test set"""
        earliest_time = None

        # Check input folder for earliest file
        paginator = s3_client.get_paginator("list_objects_v2")
        for page in paginator.paginate(
            Bucket=bucket, Prefix=f"{prefix}/input/", MaxKeys=10
        ):
            for obj in page.get("Contents", []):
                if not obj["Key"].endswith("/"):  # Skip directories
                    if earliest_time is None or obj["LastModified"] < earliest_time:
                        earliest_time = obj["LastModified"]

        if earliest_time is None:
            raise Exception(
                f"No files found in {prefix}/input/ to determine creation time"
            )

        return earliest_time.isoformat()

    s3_client = Mock()

    # Mock paginator with files having different timestamps
    paginator = Mock()
    older_time = datetime(2023, 1, 1, 10, 0, 0)
    newer_time = datetime(2023, 1, 1, 12, 0, 0)

    paginator.paginate.return_value = [
        {
            "Contents": [
                {"Key": "my-test-set/input/file1.pdf", "LastModified": newer_time},
                {"Key": "my-test-set/input/file2.pdf", "LastModified": older_time},
            ]
        }
    ]

    s3_client.get_paginator.return_value = paginator

    result = _get_test_set_creation_time(s3_client, "test-bucket", "my-test-set")

    # Should return the earlier timestamp
    assert result == older_time.isoformat()


@pytest.mark.unit
def test_get_test_set_creation_time_no_files():
    """Test creation time function throws exception when no files found"""

    def _get_test_set_creation_time(s3_client, bucket, prefix):
        """Get the earliest creation time from files in the test set"""
        earliest_time = None

        paginator = s3_client.get_paginator("list_objects_v2")
        for page in paginator.paginate(
            Bucket=bucket, Prefix=f"{prefix}/input/", MaxKeys=10
        ):
            for obj in page.get("Contents", []):
                if not obj["Key"].endswith("/"):
                    if earliest_time is None or obj["LastModified"] < earliest_time:
                        earliest_time = obj["LastModified"]

        if earliest_time is None:
            raise Exception(
                f"No files found in {prefix}/input/ to determine creation time"
            )

        return earliest_time.isoformat()

    s3_client = Mock()

    # Mock paginator with no files
    paginator = Mock()
    paginator.paginate.return_value = [{"Contents": []}]
    s3_client.get_paginator.return_value = paginator

    with pytest.raises(Exception) as exc_info:
        _get_test_set_creation_time(s3_client, "test-bucket", "my-test-set")

    assert "No files found in my-test-set/input/ to determine creation time" in str(
        exc_info.value
    )
