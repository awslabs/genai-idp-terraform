# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import pytest


@pytest.mark.unit
def test_path_extraction_logic():
    """Test the path extraction logic for testset bucket files"""
    # Simulate the path extraction logic from _copy_input_files_from_test_set_bucket
    file_key = "fcc_benchmark/input/fcc_benchmark/033f718b16cb597c065930410752c294.pdf"
    test_set_id = "fcc_demo_test_set"

    # Extract actual file path from test_set/input/file_path
    path_parts = file_key.split("/")
    if len(path_parts) >= 3 and path_parts[1] == "input":
        actual_file_path = "/".join(path_parts[2:])
        dest_key = f"{test_set_id}/input/{actual_file_path}"
    else:
        dest_key = f"{test_set_id}/input/{file_key}"

    expected = (
        "fcc_demo_test_set/input/fcc_benchmark/033f718b16cb597c065930410752c294.pdf"
    )
    assert dest_key == expected


@pytest.mark.unit
def test_baseline_path_extraction_logic():
    """Test the path extraction logic for baseline files from testset bucket"""
    # Simulate the path extraction logic from _copy_baseline_from_testset
    file_key = "fcc_benchmark/input/fcc_benchmark/033f718b16cb597c065930410752c294.pdf"
    test_set_id = "demo_test_set"

    # Extract test set name and file name from path (format: test_set_name/input/file_name)
    path_parts = file_key.split("/")
    if len(path_parts) >= 3 and path_parts[1] == "input":
        source_test_set_name = path_parts[0]
        file_name = "/".join(path_parts[2:])  # Get full path after 'input/'

        # Source baseline path in testset bucket
        source_baseline_prefix = f"{source_test_set_name}/baseline/{file_name}/"
        # Destination baseline path
        dest_baseline_prefix = f"{test_set_id}/baseline/{file_name}/"

    expected_source = (
        "fcc_benchmark/baseline/fcc_benchmark/033f718b16cb597c065930410752c294.pdf/"
    )
    expected_dest = (
        "demo_test_set/baseline/fcc_benchmark/033f718b16cb597c065930410752c294.pdf/"
    )

    assert source_baseline_prefix == expected_source
    assert dest_baseline_prefix == expected_dest


@pytest.mark.unit
def test_path_extraction_edge_cases():
    """Test edge cases for path extraction"""
    test_set_id = "test-set-1"

    # Test normal file without input path
    file_key = "simple_file.pdf"
    path_parts = file_key.split("/")
    if len(path_parts) >= 3 and path_parts[1] == "input":
        actual_file_path = "/".join(path_parts[2:])
        dest_key = f"{test_set_id}/input/{actual_file_path}"
    else:
        dest_key = f"{test_set_id}/input/{file_key}"

    assert dest_key == "test-set-1/input/simple_file.pdf"

    # Test malformed path
    file_key = "malformed/path.pdf"
    path_parts = file_key.split("/")
    if len(path_parts) >= 3 and path_parts[1] == "input":
        actual_file_path = "/".join(path_parts[2:])
        dest_key = f"{test_set_id}/input/{actual_file_path}"
    else:
        dest_key = f"{test_set_id}/input/{file_key}"

    assert dest_key == "test-set-1/input/malformed/path.pdf"
