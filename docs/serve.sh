#!/bin/bash

# Quick start script for GenAI IDP Accelerator documentation
# This script helps you get the documentation running locally

set -e

echo "🚀 GenAI IDP Accelerator Documentation Setup"
echo "============================================="

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please install Python 3.8 or later and try again."
    exit 1
fi

echo "✅ Python 3 found: $(python3 --version)"

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed."
    echo "Please install pip3 and try again."
    exit 1
fi

echo "✅ pip3 found: $(pip3 --version)"

# Install dependencies
echo ""
echo "📦 Installing documentation dependencies..."
pip3 install -r requirements.txt

# Check if MkDocs was installed successfully
if ! command -v mkdocs &> /dev/null; then
    echo "❌ MkDocs installation failed."
    echo "Please check the error messages above and try again."
    exit 1
fi

echo "✅ MkDocs installed: $(mkdocs --version)"

# Build the documentation to check for errors
echo ""
echo "🏗️ Building documentation to check for errors..."
mkdocs build --clean

echo "✅ Documentation builds successfully!"

# Start the development server
echo ""
echo "🌐 Starting documentation server..."
echo "📖 Documentation will be available at: http://127.0.0.1:8000"
echo "🔄 The server will automatically reload when you make changes"
echo "⏹️ Press Ctrl+C to stop the server"
echo ""

# Start MkDocs development server
mkdocs serve
