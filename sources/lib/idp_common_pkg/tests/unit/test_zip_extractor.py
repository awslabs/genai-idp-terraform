# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from unittest.mock import Mock

import pytest


@pytest.mark.unit
def test_file_validation_logic():
    """Test the file validation logic for input and baseline matching"""

    # Mock zip file structure
    mock_files = [
        # Input files
        Mock(filename="my-test-set/input/document1.pdf", is_dir=lambda: False),
        Mock(filename="my-test-set/input/document2.pdf", is_dir=lambda: False),
        # Baseline files
        Mock(
            filename="my-test-set/baseline/document1.pdf/sections/result.json",
            is_dir=lambda: False,
        ),
        Mock(
            filename="my-test-set/baseline/document1.pdf/metadata.json",
            is_dir=lambda: False,
        ),
        Mock(
            filename="my-test-set/baseline/document2.pdf/extraction.json",
            is_dir=lambda: False,
        ),
        # Directory entries (should be ignored)
        Mock(filename="my-test-set/input/", is_dir=lambda: True),
        Mock(filename="my-test-set/baseline/", is_dir=lambda: True),
    ]

    # Simulate the validation logic
    input_files = []
    baseline_files = []
    input_names = set()
    baseline_names = set()

    for file_info in mock_files:
        if not file_info.is_dir():
            file_path = file_info.filename

            if "/input/" in file_path:
                input_files.append(file_info)
                # Extract filename for matching
                filename = file_path.split("/")[-1]
                input_names.add(filename)
            elif "/baseline/" in file_path:
                baseline_files.append(file_info)
                # Extract folder name after /baseline/ for matching
                parts = file_path.split("/baseline/", 1)
                if len(parts) == 2 and "/" in parts[1]:
                    # Handle nested structure: baseline/category/filename.pdf/sections/...
                    path_parts = parts[1].split("/")
                    if len(path_parts) >= 2:
                        # Look for the .pdf file
                        for part in path_parts:
                            if part.endswith(".pdf"):
                                baseline_names.add(part)
                                break

    # Assertions
    assert len(input_files) == 2
    assert len(baseline_files) == 3
    assert input_names == {"document1.pdf", "document2.pdf"}
    assert baseline_names == {"document1.pdf", "document2.pdf"}

    # Validation checks
    assert len(input_files) == len(input_names)  # Each input file should be unique
    missing_baselines = input_names - baseline_names
    assert not missing_baselines, f"Missing baseline files for: {missing_baselines}"

    extra_baselines = baseline_names - input_names
    assert not extra_baselines, f"Extra baseline files: {extra_baselines}"


@pytest.mark.unit
def test_complex_file_structure():
    """Test with complex nested structure like the real S3 bucket"""

    mock_files = [
        # Input files with nested structure
        Mock(
            filename="fcc_benchmark/input/fcc_benchmark/033f718b16cb597c065930410752c294.pdf",
            is_dir=lambda: False,
        ),
        Mock(
            filename="fcc_benchmark/input/fcc_benchmark/03f65053aea282ad8d5e759a9f18bdbb.pdf",
            is_dir=lambda: False,
        ),
        # Baseline files with nested structure
        Mock(
            filename="fcc_benchmark/baseline/fcc_benchmark/033f718b16cb597c065930410752c294.pdf/sections/1/result.json",
            is_dir=lambda: False,
        ),
        Mock(
            filename="fcc_benchmark/baseline/fcc_benchmark/03f65053aea282ad8d5e759a9f18bdbb.pdf/sections/1/result.json",
            is_dir=lambda: False,
        ),
    ]

    input_names = set()
    baseline_names = set()

    for file_info in mock_files:
        if not file_info.is_dir():
            file_path = file_info.filename

            if "/input/" in file_path:
                filename = file_path.split("/")[-1]
                input_names.add(filename)
            elif "/baseline/" in file_path:
                parts = file_path.split("/baseline/", 1)
                if len(parts) == 2 and "/" in parts[1]:
                    path_parts = parts[1].split("/")
                    if len(path_parts) >= 2:
                        for part in path_parts:
                            if part.endswith(".pdf"):
                                baseline_names.add(part)
                                break

    # Should match the complex filenames
    expected_names = {
        "033f718b16cb597c065930410752c294.pdf",
        "03f65053aea282ad8d5e759a9f18bdbb.pdf",
    }
    assert input_names == expected_names
    assert baseline_names == expected_names
    assert input_names == baseline_names
