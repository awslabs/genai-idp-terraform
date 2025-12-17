"""
Property-based test for source synchronization integrity.

**Feature: idp-terraform-upgrade, Property 1: Source Synchronization Integrity**
**Validates: Requirements 1.2, 14.1**

This test verifies that for any file in the synchronized source directories
(idp_common_pkg), the file content hash in the Terraform implementation
matches the corresponding file content hash in the CDK implementation.
"""

import hashlib
import os
from pathlib import Path
from typing import List, Tuple

import pytest

# Define the source and target directories relative to workspace root
# These paths are relative to the workspace root
CDK_SOURCE_PATH = "genai-idp/sources/lib/idp_common_pkg"
TERRAFORM_SOURCE_PATH = "genai-idp-terraform/sources/lib/idp_common_pkg"


def get_workspace_root() -> Path:
    """Find the workspace root by looking for known markers."""
    current = Path(__file__).resolve()
    # Navigate up to find the workspace root (contains both genai-idp and genai-idp-terraform)
    for parent in current.parents:
        if (parent / "genai-idp").exists() and (parent / "genai-idp-terraform").exists():
            return parent
    # Fallback: assume we're running from workspace root
    return Path.cwd()


def compute_file_hash(filepath: Path) -> str:
    """Compute SHA256 hash of a file's contents."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def get_all_files(base_path: Path) -> List[Tuple[str, Path]]:
    """
    Get all files in a directory recursively.
    Returns list of (relative_path, absolute_path) tuples.
    Excludes cache directories and test_source_sync_property.py (the test file itself).
    """
    # Directories to exclude from comparison
    exclude_dirs = {"__pycache__", ".pytest_cache"}
    
    # File patterns to exclude from comparison
    exclude_file_patterns = {
        ".pyc",
        "test_source_sync_property.py",  # This test file only exists in Terraform
        "test_config_library_sync_property.py",  # This test file only exists in Terraform
    }
    
    files = []
    for root, dirnames, filenames in os.walk(base_path):
        # Skip excluded directories
        dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
        
        for filename in filenames:
            # Skip excluded files
            if any(pattern in filename for pattern in exclude_file_patterns):
                continue
            
            abs_path = Path(root) / filename
            rel_path = abs_path.relative_to(base_path)
            files.append((str(rel_path), abs_path))
    return files


class TestSourceSynchronizationIntegrity:
    """
    Property-based test class for source synchronization integrity.
    
    Property 1: Source Synchronization Integrity
    *For any* file in the synchronized source directories (idp_common_pkg),
    the file content hash in the Terraform implementation SHALL match
    the corresponding file content hash in the CDK implementation.
    """

    @pytest.fixture(scope="class")
    def workspace_root(self) -> Path:
        """Get the workspace root directory."""
        return get_workspace_root()

    @pytest.fixture(scope="class")
    def cdk_source_path(self, workspace_root: Path) -> Path:
        """Get the CDK source path."""
        return workspace_root / CDK_SOURCE_PATH

    @pytest.fixture(scope="class")
    def terraform_source_path(self, workspace_root: Path) -> Path:
        """Get the Terraform source path."""
        return workspace_root / TERRAFORM_SOURCE_PATH

    @pytest.fixture(scope="class")
    def cdk_files(self, cdk_source_path: Path) -> List[Tuple[str, Path]]:
        """Get all files from CDK source."""
        if not cdk_source_path.exists():
            pytest.skip(f"CDK source path does not exist: {cdk_source_path}")
        return get_all_files(cdk_source_path)

    @pytest.fixture(scope="class")
    def terraform_files(self, terraform_source_path: Path) -> List[Tuple[str, Path]]:
        """Get all files from Terraform source."""
        if not terraform_source_path.exists():
            pytest.skip(f"Terraform source path does not exist: {terraform_source_path}")
        return get_all_files(terraform_source_path)

    def test_file_count_matches(
        self, cdk_files: List[Tuple[str, Path]], terraform_files: List[Tuple[str, Path]]
    ):
        """
        Property: The number of files in CDK and Terraform implementations must match.
        """
        cdk_count = len(cdk_files)
        terraform_count = len(terraform_files)
        assert cdk_count == terraform_count, (
            f"File count mismatch: CDK has {cdk_count} files, "
            f"Terraform has {terraform_count} files"
        )

    def test_all_cdk_files_exist_in_terraform(
        self,
        cdk_files: List[Tuple[str, Path]],
        terraform_source_path: Path,
    ):
        """
        Property: For any file in CDK source, a corresponding file must exist in Terraform.
        """
        missing_files = []
        for rel_path, _ in cdk_files:
            terraform_file = terraform_source_path / rel_path
            if not terraform_file.exists():
                missing_files.append(rel_path)
        
        assert len(missing_files) == 0, (
            f"Missing {len(missing_files)} files in Terraform implementation:\n"
            + "\n".join(missing_files[:20])  # Show first 20
            + (f"\n... and {len(missing_files) - 20} more" if len(missing_files) > 20 else "")
        )

    def test_all_terraform_files_exist_in_cdk(
        self,
        terraform_files: List[Tuple[str, Path]],
        cdk_source_path: Path,
    ):
        """
        Property: For any file in Terraform source, a corresponding file must exist in CDK.
        """
        extra_files = []
        for rel_path, _ in terraform_files:
            cdk_file = cdk_source_path / rel_path
            if not cdk_file.exists():
                extra_files.append(rel_path)
        
        assert len(extra_files) == 0, (
            f"Found {len(extra_files)} extra files in Terraform implementation:\n"
            + "\n".join(extra_files[:20])  # Show first 20
            + (f"\n... and {len(extra_files) - 20} more" if len(extra_files) > 20 else "")
        )

    def test_file_content_hashes_match(
        self,
        cdk_files: List[Tuple[str, Path]],
        terraform_source_path: Path,
    ):
        """
        Property 1: Source Synchronization Integrity
        
        *For any* file in the synchronized source directories (idp_common_pkg),
        the file content hash in the Terraform implementation SHALL match
        the corresponding file content hash in the CDK implementation.
        
        **Validates: Requirements 1.2, 14.1**
        """
        mismatched_files = []
        
        for rel_path, cdk_abs_path in cdk_files:
            terraform_file = terraform_source_path / rel_path
            
            if not terraform_file.exists():
                # Skip files that don't exist - covered by other tests
                continue
            
            cdk_hash = compute_file_hash(cdk_abs_path)
            terraform_hash = compute_file_hash(terraform_file)
            
            if cdk_hash != terraform_hash:
                mismatched_files.append({
                    "file": rel_path,
                    "cdk_hash": cdk_hash[:16] + "...",
                    "terraform_hash": terraform_hash[:16] + "...",
                })
        
        assert len(mismatched_files) == 0, (
            f"Found {len(mismatched_files)} files with content hash mismatches:\n"
            + "\n".join(
                f"  {m['file']}: CDK={m['cdk_hash']} vs TF={m['terraform_hash']}"
                for m in mismatched_files[:20]
            )
            + (f"\n... and {len(mismatched_files) - 20} more" if len(mismatched_files) > 20 else "")
        )

    def test_directory_structure_matches(
        self,
        cdk_source_path: Path,
        terraform_source_path: Path,
    ):
        """
        Property: Directory structure must be identical between implementations.
        """
        def get_dirs(base_path: Path) -> set:
            # Directories to exclude from comparison
            exclude_dirs = {"__pycache__", ".pytest_cache"}
            
            dirs = set()
            for root, dirnames, _ in os.walk(base_path):
                # Skip excluded directories
                dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
                
                for dirname in dirnames:
                    abs_path = Path(root) / dirname
                    rel_path = abs_path.relative_to(base_path)
                    dirs.add(str(rel_path))
            return dirs
        
        cdk_dirs = get_dirs(cdk_source_path)
        terraform_dirs = get_dirs(terraform_source_path)
        
        missing_dirs = cdk_dirs - terraform_dirs
        extra_dirs = terraform_dirs - cdk_dirs
        
        assert len(missing_dirs) == 0, (
            f"Missing directories in Terraform: {missing_dirs}"
        )
        assert len(extra_dirs) == 0, (
            f"Extra directories in Terraform: {extra_dirs}"
        )


class TestSourceSynchronizationVerification:
    """
    Additional verification tests for source synchronization.
    
    These tests provide detailed verification of the synchronization
    including key directory checks and sample file hash verification.
    
    **Validates: Requirements 1.2, 14.1**
    """

    @pytest.fixture(scope="class")
    def workspace_root(self) -> Path:
        """Get the workspace root directory."""
        return get_workspace_root()

    @pytest.fixture(scope="class")
    def cdk_source_path(self, workspace_root: Path) -> Path:
        """Get the CDK source path."""
        return workspace_root / CDK_SOURCE_PATH

    @pytest.fixture(scope="class")
    def terraform_source_path(self, workspace_root: Path) -> Path:
        """Get the Terraform source path."""
        return workspace_root / TERRAFORM_SOURCE_PATH

    def test_key_directories_exist(self, terraform_source_path: Path):
        """
        Verify that key directories required for v0.3.18 features exist.
        
        These directories are critical for new features:
        - agents: Agent Analytics feature
        - discovery: Discovery Module feature
        - utils: Lambda metering utilities
        - metrics: Cost metering support
        - config: Configuration management
        
        **Validates: Requirements 1.2, 14.1**
        """
        key_directories = [
            "idp_common/agents",
            "idp_common/discovery",
            "idp_common/utils",
            "idp_common/metrics",
            "idp_common/config",
            "idp_common/assessment",
            "idp_common/classification",
            "idp_common/extraction",
            "idp_common/bda",
            "idp_common/bedrock",
        ]
        
        missing_dirs = []
        for dir_path in key_directories:
            full_path = terraform_source_path / dir_path
            if not full_path.exists():
                missing_dirs.append(dir_path)
            elif not full_path.is_dir():
                missing_dirs.append(f"{dir_path} (exists but is not a directory)")
        
        assert len(missing_dirs) == 0, (
            f"Missing key directories in Terraform implementation:\n"
            + "\n".join(f"  - {d}" for d in missing_dirs)
        )

    def test_key_files_exist(self, terraform_source_path: Path):
        """
        Verify that key files required for the package exist.
        
        **Validates: Requirements 1.2, 14.1**
        """
        key_files = [
            "pyproject.toml",
            "setup.py",
            "README.md",
            "idp_common/__init__.py",
            "idp_common/models.py",
            "idp_common/utils/lambda_metering.py",  # Critical for Lambda cost metering
            "idp_common/discovery/classes_discovery.py",  # Critical for Discovery Module
            "idp_common/agents/__init__.py",  # Critical for Agent Analytics
        ]
        
        missing_files = []
        for file_path in key_files:
            full_path = terraform_source_path / file_path
            if not full_path.exists():
                missing_files.append(file_path)
        
        assert len(missing_files) == 0, (
            f"Missing key files in Terraform implementation:\n"
            + "\n".join(f"  - {f}" for f in missing_files)
        )

    def test_sample_file_hashes_match(
        self,
        cdk_source_path: Path,
        terraform_source_path: Path,
    ):
        """
        Verify that a sample of critical files have matching hashes.
        
        This test checks specific files that are critical for functionality.
        
        **Validates: Requirements 1.2, 14.1**
        """
        critical_files = [
            "pyproject.toml",
            "idp_common/__init__.py",
            "idp_common/models.py",
            "idp_common/classification/service.py",
            "idp_common/extraction/service.py",
            "idp_common/assessment/service.py",
            "idp_common/utils/lambda_metering.py",
            "idp_common/config/configuration_manager.py",
        ]
        
        mismatches = []
        for file_path in critical_files:
            cdk_file = cdk_source_path / file_path
            terraform_file = terraform_source_path / file_path
            
            if not cdk_file.exists():
                continue  # Skip if CDK file doesn't exist
            
            if not terraform_file.exists():
                mismatches.append(f"{file_path}: missing in Terraform")
                continue
            
            cdk_hash = compute_file_hash(cdk_file)
            terraform_hash = compute_file_hash(terraform_file)
            
            if cdk_hash != terraform_hash:
                mismatches.append(
                    f"{file_path}: hash mismatch "
                    f"(CDK: {cdk_hash[:12]}... vs TF: {terraform_hash[:12]}...)"
                )
        
        assert len(mismatches) == 0, (
            f"Critical file verification failed:\n"
            + "\n".join(f"  - {m}" for m in mismatches)
        )

    def test_agents_subdirectories_exist(self, terraform_source_path: Path):
        """
        Verify that the agents module has all required subdirectories.
        
        The agents module is critical for Agent Analytics feature.
        
        **Validates: Requirements 1.2, 14.1**
        """
        agents_path = terraform_source_path / "idp_common" / "agents"
        
        if not agents_path.exists():
            pytest.fail("agents directory does not exist")
        
        expected_subdirs = [
            "analytics",
            "common",
            "factory",
            "orchestrator",
        ]
        
        missing_subdirs = []
        for subdir in expected_subdirs:
            if not (agents_path / subdir).exists():
                missing_subdirs.append(subdir)
        
        assert len(missing_subdirs) == 0, (
            f"Missing subdirectories in agents module:\n"
            + "\n".join(f"  - {d}" for d in missing_subdirs)
        )

    def test_test_directory_structure(self, terraform_source_path: Path):
        """
        Verify that the tests directory has proper structure.
        
        **Validates: Requirements 1.2, 14.1**
        """
        tests_path = terraform_source_path / "tests"
        
        assert tests_path.exists(), "tests directory does not exist"
        
        expected_items = [
            "unit",
            "integration",
            "__init__.py",
            "conftest.py",
        ]
        
        missing_items = []
        for item in expected_items:
            if not (tests_path / item).exists():
                missing_items.append(item)
        
        assert len(missing_items) == 0, (
            f"Missing items in tests directory:\n"
            + "\n".join(f"  - {i}" for i in missing_items)
        )

    def test_synchronization_summary(
        self,
        cdk_source_path: Path,
        terraform_source_path: Path,
    ):
        """
        Generate a summary of the synchronization status.
        
        This test always passes but provides useful diagnostic information.
        
        **Validates: Requirements 1.2, 14.1**
        """
        # Count files
        cdk_files = get_all_files(cdk_source_path)
        terraform_files = get_all_files(terraform_source_path)
        
        # Count directories
        def count_dirs(base_path: Path) -> int:
            exclude_dirs = {"__pycache__", ".pytest_cache"}
            count = 0
            for root, dirnames, _ in os.walk(base_path):
                dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
                count += len(dirnames)
            return count
        
        cdk_dir_count = count_dirs(cdk_source_path)
        terraform_dir_count = count_dirs(terraform_source_path)
        
        # Calculate hash matches
        matching_hashes = 0
        for rel_path, cdk_abs_path in cdk_files:
            terraform_file = terraform_source_path / rel_path
            if terraform_file.exists():
                if compute_file_hash(cdk_abs_path) == compute_file_hash(terraform_file):
                    matching_hashes += 1
        
        # Print summary (visible in pytest output with -v flag)
        print("\n" + "=" * 60)
        print("SYNCHRONIZATION SUMMARY")
        print("=" * 60)
        print(f"CDK Files:        {len(cdk_files)}")
        print(f"Terraform Files:  {len(terraform_files)}")
        print(f"CDK Directories:  {cdk_dir_count}")
        print(f"TF Directories:   {terraform_dir_count}")
        print(f"Matching Hashes:  {matching_hashes}/{len(cdk_files)}")
        print(f"Sync Status:      {'✓ COMPLETE' if matching_hashes == len(cdk_files) else '✗ INCOMPLETE'}")
        print("=" * 60)
        
        # This test always passes - it's for informational purposes
        assert True
