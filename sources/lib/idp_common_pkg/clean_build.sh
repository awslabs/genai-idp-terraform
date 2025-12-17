#!/bin/bash
# Clean build script to remove all build artifacts and rebuild cleanly

echo "Cleaning all build artifacts..."
rm -rf build/
rm -rf dist/
rm -rf *.egg-info/
find . -name "__pycache__" -type d -exec rm -rf {} +
find . -name "*.pyc" -delete

echo "Building package..."
pip install -e .

echo "Done!"
