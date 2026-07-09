#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

##############################################################################################
# WSL Development Environment Setup Script
# 
# This script automates the installation of development tools for the GenAI IDP accelerator
# on Windows Subsystem for Linux (WSL) Ubuntu systems. It installs Python 3, AWS CLI, 
# SAM CLI, Node.js, and other essential development tools.
#
# Usage: ./wsl_setup.sh
# Note: Run this script inside WSL Ubuntu environment
##############################################################################################

# exit on failure
set -ex

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install git unzip -y
sudo apt install python3 python3-pip python3-venv python3-full -y
sudo apt install build-essential make -y

# Verify Python version
python3 --version

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -  # nosemgrep: bash.curl.security.curl-pipe-bash.curl-pipe-bash - Official NodeSource repository with HTTPS verification for development environment only
sudo apt-get install -y nodejs

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscli.zip"
unzip awscli.zip
sudo ./aws/install
rm -rf aws awscli.zip

# Verify AWS CLI installation
aws --version

# Install AWS SAM CLI
wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
sudo ./sam-installation/install
rm -rf sam-installation aws-sam-cli-linux-x86_64.zip

# Verify SAM installation
sam --version

echo "DONE - WSL development environment setup complete."
echo "Next steps:"
echo "1. Create Python virtual environment: python3 -m venv venv"
echo "2. Activate virtual environment: source venv/bin/activate"
echo "3. Install Python packages: pip install setuptools wheel boto3 rich PyYAML botocore ruff pytest"
echo "4. Install IDP common package: pip install -e lib/idp_common_pkg/"
echo "5. Configure AWS CLI: aws configure"
