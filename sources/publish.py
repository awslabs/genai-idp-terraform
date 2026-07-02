#!/usr/bin/env python3

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Backward compatibility wrapper for publish.py.

⚠️  DEPRECATED: Use 'idp-cli publish' instead.

The IDPPublisher class has been moved to idp_sdk._core.publish.
This script is maintained for backward compatibility with existing
CI/CD pipelines and 'idp-cli deploy --from-code' workflows.

Equivalent commands:
    idp-cli publish --source-dir . --bucket <bucket> --prefix <prefix> --region <region>
    idp-cli publish --source-dir . --region <region> --headless
"""

import importlib
import os
import sys

# Ensure lib packages are importable when running from project root
_project_root = os.path.dirname(os.path.abspath(__file__))
for _lib_pkg in ["lib/idp_sdk", "lib/idp_common_pkg", "lib/idp_cli_pkg"]:
    _lib_path = os.path.join(_project_root, _lib_pkg)
    if _lib_path not in sys.path and os.path.isdir(_lib_path):
        sys.path.insert(0, _lib_path)


def _get_publisher_class():
    """Lazy import of IDPPublisher to avoid import errors when dependencies aren't available."""
    _publish_mod = importlib.import_module("idp_sdk._core.publish")
    return _publish_mod.IDPPublisher


# Re-export IDPPublisher for backward compatibility via lazy descriptor
# (tests and other code do `from publish import IDPPublisher`)
class _LazyIDPPublisher:
    """Lazy proxy that resolves IDPPublisher on first access."""

    _cls = None

    def __init_subclass__(cls, **kwargs):
        pass

    def __new__(cls, *args, **kwargs):
        if cls._cls is None:
            cls._cls = _get_publisher_class()
        return cls._cls(*args, **kwargs)


# This allows `from publish import IDPPublisher` to work
try:
    IDPPublisher = _get_publisher_class()
except (ImportError, ModuleNotFoundError):
    # If dependencies aren't available (e.g., wrong Python version),
    # fall back to lazy class so the module can at least be imported
    IDPPublisher = _LazyIDPPublisher  # type: ignore

if __name__ == "__main__":
    # Resolve the real class for direct execution
    try:
        _RealPublisher = _get_publisher_class()
    except (ImportError, ModuleNotFoundError) as e:
        print(f"Error: Cannot import IDPPublisher: {e}", file=sys.stderr)
        print("", file=sys.stderr)
        print(
            "Required packages are not installed. To fix this, run one of:",
            file=sys.stderr,
        )
        print(
            "  make setup          Install into your current Python environment",
            file=sys.stderr,
        )
        print(
            "  make setup-venv     Create a .venv and install into it", file=sys.stderr
        )
        print("", file=sys.stderr)
        print(
            "If you already ran 'make setup-venv', activate it first:", file=sys.stderr
        )
        print("  source .venv/bin/activate", file=sys.stderr)
        sys.exit(1)

    from rich.console import Console

    # Show deprecation notice when run directly by a user
    if not os.environ.get("IDP_SDK_PUBLISH_SUBPROCESS"):
        console = Console()
        console.print()
        console.print(
            "[bold yellow]⚠️  DEPRECATED: Use 'idp-cli publish' instead of running publish.py directly.[/bold yellow]"
        )
        console.print(
            "[dim]Equivalent: idp-cli publish --source-dir . --bucket <bucket> --prefix <prefix> --region <region>[/dim]"
        )
        console.print(
            "[dim]Headless:   idp-cli publish --source-dir . --region <region> --headless[/dim]"
        )
        console.print()

    if len(sys.argv) < 4:
        publisher = _RealPublisher()
        publisher.print_usage()
        sys.exit(1)

    publisher = _RealPublisher()
    publisher.run(sys.argv[1:])
