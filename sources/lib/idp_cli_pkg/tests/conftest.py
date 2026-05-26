# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Test configuration and fixtures for idp_cli tests
"""

import sys
from pathlib import Path

# Add idp_common_pkg to Python path for testing
# This mirrors the production code's approach of dynamically adding the path
# Since idp_cli_pkg is in lib/, we go up to lib/ level and find idp_common_pkg there
project_root = Path(__file__).parent.parent.parent  # lib/
idp_common_path = project_root / "idp_common_pkg"

if idp_common_path.exists():
    sys.path.insert(0, str(idp_common_path))
else:
    raise RuntimeError(
        f"idp_common_pkg not found at expected location: {idp_common_path}"
    )
