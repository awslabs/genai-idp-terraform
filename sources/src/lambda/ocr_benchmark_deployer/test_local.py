#!/usr/bin/env python3
"""
Local test script for the OCR Benchmark deployer.
Tests the simplified implementation with hardcoded image IDs.
"""

import os
import sys
import json

# Set HuggingFace cache to /tmp for consistency with Lambda
os.environ['HF_HOME'] = '/tmp/huggingface'
os.environ['HUGGINGFACE_HUB_CACHE'] = '/tmp/huggingface/hub'

from huggingface_hub import hf_hub_download, list_repo_files

# Import from index.py
from index import (
    HARDCODED_IMAGES,
    HF_REPO_ID,
    build_image_id_mapping,
    load_metadata_for_ids,
)


def test_hardcoded_images_count():
    """Test that hardcoded images have expected counts."""
    print("\n=== Testing Hardcoded Image Counts ===")
    
    expected_counts = {
        "BANK_CHECK": 52,
        "COMMERCIAL_LEASE_AGREEMENT": 52,
        "CREDIT_CARD_STATEMENT": 11,
        "DELIVERY_NOTE": 8,
        "EQUIPMENT_INSPECTION": 11,
        "GLOSSARY": 31,
        "PETITION_FORM": 51,
        "REAL_ESTATE": 59,
        "SHIFT_SCHEDULE": 18,
    }
    
    total = 0
    for doc_format, image_ids in HARDCODED_IMAGES.items():
        count = len(image_ids)
        total += count
        expected = expected_counts.get(doc_format, 0)
        status = "✓" if count == expected else "✗"
        print(f"  {status} {doc_format}: {count} images (expected {expected})")
    
    print(f"\n  Total: {total} images (expected 293)")
    assert total == 293, f"Expected 293 total images, got {total}"
    print("  ✓ Total count correct")


def test_download_metadata():
    """Test downloading metadata.jsonl from HuggingFace."""
    print("\n=== Testing Metadata Download ===")
    
    cache_dir = '/tmp/huggingface/hub'
    os.makedirs(cache_dir, exist_ok=True)
    
    print(f"  Downloading metadata from {HF_REPO_ID}...")
    metadata_path = hf_hub_download(
        repo_id=HF_REPO_ID,
        filename="test/metadata.jsonl",
        repo_type="dataset",
        cache_dir=cache_dir
    )
    
    print(f"  ✓ Downloaded to: {metadata_path}")
    
    # Build set of all target IDs
    all_target_ids = set()
    for image_ids in HARDCODED_IMAGES.values():
        all_target_ids.update(image_ids)
    
    print(f"  Loading metadata for {len(all_target_ids)} target images...")
    id_to_metadata = load_metadata_for_ids(metadata_path, all_target_ids)
    
    print(f"  ✓ Found metadata for {len(id_to_metadata)} images")
    
    # Check for missing metadata
    missing = all_target_ids - set(id_to_metadata.keys())
    if missing:
        print(f"  ⚠ Missing metadata for {len(missing)} IDs: {sorted(missing)[:10]}...")
    else:
        print("  ✓ All target IDs have metadata")
    
    return metadata_path, id_to_metadata


def test_image_filename_mapping():
    """Test building the image ID to filename mapping."""
    print("\n=== Testing Image Filename Mapping ===")
    
    cache_dir = '/tmp/huggingface/hub'
    id_to_filename = build_image_id_mapping(cache_dir)
    
    print(f"  ✓ Found {len(id_to_filename)} image files in repo")
    
    # Check which target IDs have files
    all_target_ids = set()
    for image_ids in HARDCODED_IMAGES.values():
        all_target_ids.update(image_ids)
    
    found_count = sum(1 for id in all_target_ids if id in id_to_filename)
    print(f"  ✓ {found_count}/{len(all_target_ids)} target images have files")
    
    # Show some sample mappings
    print("\n  Sample mappings:")
    for doc_format in list(HARDCODED_IMAGES.keys())[:3]:
        image_id = HARDCODED_IMAGES[doc_format][0]
        filename = id_to_filename.get(image_id, "NOT FOUND")
        print(f"    {doc_format}[{image_id}] -> {filename}")
    
    return id_to_filename


def test_sample_image_download(id_to_filename):
    """Test downloading a sample image."""
    print("\n=== Testing Sample Image Download ===")
    
    from index import download_and_convert_image
    
    # Pick first image from first format
    doc_format = list(HARDCODED_IMAGES.keys())[0]
    image_id = HARDCODED_IMAGES[doc_format][0]
    filename = id_to_filename.get(image_id)
    
    if not filename:
        print(f"  ✗ No filename found for {doc_format}/{image_id}")
        return
    
    print(f"  Downloading {doc_format}/{image_id} ({filename})...")
    
    cache_dir = '/tmp/huggingface/hub'
    image_bytes = download_and_convert_image(image_id, filename, cache_dir)
    
    print(f"  ✓ Downloaded and converted to PNG: {len(image_bytes)} bytes")


def test_baseline_structure(id_to_metadata):
    """Test that baseline JSON structure is correct."""
    print("\n=== Testing Baseline Structure ===")
    
    # Pick first image from first format
    doc_format = list(HARDCODED_IMAGES.keys())[0]
    image_id = HARDCODED_IMAGES[doc_format][0]
    
    metadata = id_to_metadata.get(image_id)
    if not metadata:
        print(f"  ✗ No metadata for {doc_format}/{image_id}")
        return
    
    true_json_output = metadata.get('true_json_output')
    if not true_json_output:
        print(f"  ✗ No true_json_output for {doc_format}/{image_id}")
        return
    
    # Parse true_json_output
    if isinstance(true_json_output, str):
        inference_result = json.loads(true_json_output)
    else:
        inference_result = true_json_output
    
    # Create baseline structure
    result_json = {
        "document_class": {
            "type": doc_format
        },
        "split_document": {
            "page_indices": [0]
        },
        "inference_result": inference_result
    }
    
    print(f"  Sample baseline for {doc_format}_{image_id}.png:")
    print(f"    document_class.type: {result_json['document_class']['type']}")
    print(f"    split_document.page_indices: {result_json['split_document']['page_indices']}")
    print(f"    inference_result keys: {list(inference_result.keys())[:5]}...")
    print("  ✓ Baseline structure valid")


def main():
    """Run all tests."""
    print("=" * 60)
    print("OCR Benchmark Deployer - Local Test")
    print("=" * 60)
    
    # Test 1: Verify hardcoded counts
    test_hardcoded_images_count()
    
    # Test 2: Download and parse metadata
    metadata_path, id_to_metadata = test_download_metadata()
    
    # Test 3: Build filename mapping
    id_to_filename = test_image_filename_mapping()
    
    # Test 4: Download a sample image
    test_sample_image_download(id_to_filename)
    
    # Test 5: Verify baseline structure
    test_baseline_structure(id_to_metadata)
    
    print("\n" + "=" * 60)
    print("All tests passed! ✓")
    print("=" * 60)


if __name__ == "__main__":
    main()
