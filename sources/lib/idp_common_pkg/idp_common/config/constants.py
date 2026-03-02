# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Configuration type constants.

These constants define the valid configuration types used throughout the system.
Use these instead of hardcoded strings to ensure consistency and type safety.
"""

# Configuration Types
CONFIG_TYPE_SCHEMA = "Schema"
CONFIG_TYPE_DEFAULT = "Default"
CONFIG_TYPE_CUSTOM = "Custom"

# All valid configuration types
VALID_CONFIG_TYPES = [CONFIG_TYPE_SCHEMA, CONFIG_TYPE_DEFAULT, CONFIG_TYPE_CUSTOM]
