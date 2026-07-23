# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Put the bundle-assembler Lambda source on sys.path.

The tests import the Lambda handler by its bare module name ``index`` (that is
how it is deployed in the Lambda runtime). Add the Lambda source directory to
sys.path so ``importlib.import_module("index")`` resolves when pytest is run
from the repo root, without requiring a PYTHONPATH env var.
"""

import os
import sys

# tests/bundle-assembler/ -> repo root -> src/lambda/bundle-assembler
_LAMBDA_SRC = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "src", "lambda", "bundle-assembler")
)
if _LAMBDA_SRC not in sys.path:
    sys.path.insert(0, _LAMBDA_SRC)
