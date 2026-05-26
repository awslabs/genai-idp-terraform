#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
IDP SDK Examples: Run All Examples

This script runs all SDK examples to verify functionality.
Stack-independent examples run without arguments.
Stack-dependent examples require --stack-name.

Usage:
    # Run only stack-independent examples
    python run_all_examples.py

    # Run all examples including stack-dependent ones
    python run_all_examples.py --stack-name IDP-Nova-1

    # Run with document processing (requires stack)
    python run_all_examples.py --stack-name IDP-Nova-1 --run-processing
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Colors for output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"


def run_command(
    cmd: list, description: str, check: bool = True, timeout: int = 120
) -> tuple[bool, str]:
    """Run a command and return success status and output."""
    print(f"\n{BLUE}{'=' * 60}{RESET}")
    print(f"{BLUE}Running: {description}{RESET}")
    print(f"Command: {' '.join(cmd)}")
    print(f"{BLUE}{'=' * 60}{RESET}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)

        if result.returncode == 0:
            print(f"{GREEN}✓ PASSED{RESET}")
            return True, result.stdout
        else:
            print(f"{RED}✗ FAILED (exit code {result.returncode}){RESET}")
            if check:
                return False, result.stderr or result.stdout
            return True, result.stdout  # Don't count as failure if check=False

    except subprocess.TimeoutExpired:
        print(f"{RED}✗ TIMEOUT{RESET}")
        return False, "Command timed out"
    except Exception as e:
        print(f"{RED}✗ ERROR: {e}{RESET}")
        return False, str(e)


def main():
    parser = argparse.ArgumentParser(
        description="Run all IDP SDK examples",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--stack-name",
        type=str,
        help="CloudFormation stack name for stack-dependent examples",
    )
    parser.add_argument(
        "--run-processing",
        action="store_true",
        help="Run actual document processing (slow, requires stack)",
    )
    parser.add_argument(
        "--samples-dir",
        type=str,
        default="./samples",
        help="Directory containing sample documents",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        help="Output directory for results (default: temp dir)",
    )
    args = parser.parse_args()

    # Get script directory
    examples_dir = Path(__file__).parent.absolute()
    project_root = examples_dir.parent.parent.parent

    results = []

    print(f"\n{BLUE}{'#' * 60}{RESET}")
    print(f"{BLUE}# IDP SDK Examples Runner{RESET}")
    print(f"{BLUE}{'#' * 60}{RESET}")
    print(f"Examples directory: {examples_dir}")
    print(f"Project root: {project_root}")
    if args.stack_name:
        print(f"Stack name: {args.stack_name}")

    # ==================================================================
    # Stack-Independent Examples
    # ==================================================================
    print(f"\n{YELLOW}{'=' * 60}{RESET}")
    print(f"{YELLOW}STACK-INDEPENDENT EXAMPLES{RESET}")
    print(f"{YELLOW}{'=' * 60}{RESET}")

    # 1. Manifest Operations - Generate
    with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as f:
        temp_manifest = f.name

    success, output = run_command(
        [
            sys.executable,
            str(examples_dir / "manifest_operations.py"),
            "--directory",
            str(project_root / "samples"),
            "--output",
            temp_manifest,
        ],
        "Manifest: Generate from directory",
    )
    results.append(("Manifest: Generate", success))

    # 2. Manifest Operations - Validate
    if success:
        success, output = run_command(
            [
                sys.executable,
                str(examples_dir / "manifest_operations.py"),
                "--validate-only",
                temp_manifest,
            ],
            "Manifest: Validate generated manifest",
        )
        results.append(("Manifest: Validate", success))

    # Clean up temp manifest
    try:
        os.unlink(temp_manifest)
    except OSError:
        pass

    # 3. Config Operations - Create minimal
    success, output = run_command(
        [
            sys.executable,
            str(examples_dir / "config_operations.py"),
            "create",
            "--features",
            "min",
            "--pattern",
            "pattern-2",
        ],
        "Config: Create minimal template",
    )
    results.append(("Config: Create min", success))

    # 4. Config Operations - Create with all features
    success, output = run_command(
        [
            sys.executable,
            str(examples_dir / "config_operations.py"),
            "create",
            "--features",
            "all",
            "--pattern",
            "pattern-1",
        ],
        "Config: Create all features",
    )
    results.append(("Config: Create all", success))

    # 5. Config Operations - Validate (create temp config first)
    with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False, mode="w") as f:
        f.write("""
notes: Test configuration
classification:
  model: us.amazon.nova-2-lite-v1:0
extraction:
  model: us.amazon.nova-2-lite-v1:0
""")
        temp_config = f.name

    success, output = run_command(
        [
            sys.executable,
            str(examples_dir / "config_operations.py"),
            "validate",
            temp_config,
            "--pattern",
            "pattern-2",
        ],
        "Config: Validate config file",
    )
    results.append(("Config: Validate", success))

    try:
        os.unlink(temp_config)
    except OSError:
        pass

    # ==================================================================
    # Stack-Dependent Examples
    # ==================================================================
    if args.stack_name:
        print(f"\n{YELLOW}{'=' * 60}{RESET}")
        print(f"{YELLOW}STACK-DEPENDENT EXAMPLES (stack: {args.stack_name}){RESET}")
        print(f"{YELLOW}{'=' * 60}{RESET}")

        # 6. Workflow Control - Resources
        success, output = run_command(
            [
                sys.executable,
                str(examples_dir / "workflow_control.py"),
                "--stack-name",
                args.stack_name,
                "resources",
            ],
            "Workflow: Get stack resources",
        )
        results.append(("Workflow: Resources", success))

        # 7. Workflow Control - List batches
        success, output = run_command(
            [
                sys.executable,
                str(examples_dir / "workflow_control.py"),
                "--stack-name",
                args.stack_name,
                "list",
                "--limit",
                "5",
            ],
            "Workflow: List recent batches",
        )
        results.append(("Workflow: List", success))

        # 8. Config Operations - Download
        success, output = run_command(
            [
                sys.executable,
                str(examples_dir / "config_operations.py"),
                "download",
                "--stack-name",
                args.stack_name,
                "--format",
                "minimal",
            ],
            "Config: Download from stack",
        )
        results.append(("Config: Download", success))

        # 9. Batch status (if batches exist)
        # Extract batch ID from list output
        batch_id = None
        if "Batch:" in output:
            import re

            match = re.search(r"Batch: (\S+)", output)
            if match:
                batch_id = match.group(1)

        if batch_id:
            success, output = run_command(
                [
                    sys.executable,
                    str(examples_dir / "workflow_control.py"),
                    "--stack-name",
                    args.stack_name,
                    "status",
                    "--batch-id",
                    batch_id,
                ],
                f"Workflow: Get batch status ({batch_id[:30]}...)",
            )
            results.append(("Workflow: Status", success))
        else:
            print(f"\n{YELLOW}Skipping batch status - no existing batches found{RESET}")

        # 10. Run actual processing if requested
        if args.run_processing:
            print(f"\n{YELLOW}{'=' * 60}{RESET}")
            print(f"{YELLOW}DOCUMENT PROCESSING TEST{RESET}")
            print(f"{YELLOW}{'=' * 60}{RESET}")

            output_dir = args.output_dir or tempfile.mkdtemp(prefix="idp-sdk-test-")

            success, output = run_command(
                [
                    sys.executable,
                    str(examples_dir / "basic_processing.py"),
                    "--stack-name",
                    args.stack_name,
                    "--directory",
                    args.samples_dir,
                    "--output-dir",
                    output_dir,
                    "--number-of-files",
                    "2",  # Only process 2 files for test
                ],
                "Basic Processing: Submit and monitor (limited to 2 files)",
                timeout=600,  # 10 minutes for document processing
            )
            results.append(("Processing: Full workflow", success))

            print(f"\nOutput directory: {output_dir}")
    else:
        print(f"\n{YELLOW}{'=' * 60}{RESET}")
        print(f"{YELLOW}SKIPPING STACK-DEPENDENT EXAMPLES{RESET}")
        print(f"{YELLOW}Run with --stack-name <name> to include stack tests{RESET}")
        print(f"{YELLOW}{'=' * 60}{RESET}")

    # ==================================================================
    # Summary
    # ==================================================================
    print(f"\n{BLUE}{'#' * 60}{RESET}")
    print(f"{BLUE}# SUMMARY{RESET}")
    print(f"{BLUE}{'#' * 60}{RESET}")

    failed = sum(1 for _, s in results if not s)
    total = len(results)

    print("\nResults:")
    for name, success in results:
        status = f"{GREEN}✓ PASS{RESET}" if success else f"{RED}✗ FAIL{RESET}"
        print(f"  {status}  {name}")

    print(f"\n{'-' * 40}")
    if failed == 0:
        print(f"{GREEN}All {total} examples passed!{RESET}")
    else:
        print(f"{RED}{failed}/{total} examples failed{RESET}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
