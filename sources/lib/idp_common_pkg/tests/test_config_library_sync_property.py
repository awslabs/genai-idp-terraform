"""
Property-based test for config_library synchronization and Lambda pricing entries.

**Feature: idp-terraform-upgrade, Property 3: Configuration Lambda Pricing Entries**
**Validates: Requirements 1.3, 2.4, 14.2**

This test verifies that:
1. The config_library is properly synchronized between CDK and Terraform implementations
2. All config files contain valid Lambda pricing entries for cost metering
"""

import hashlib
import os
from pathlib import Path
from typing import Dict, List, Tuple

import pytest

try:
    import yaml
    YAML_AVAILABLE = True
except ImportError:
    YAML_AVAILABLE = False

# Define the source and target directories relative to workspace root
CDK_CONFIG_PATH = "genai-idp/sources/config_library"
TERRAFORM_CONFIG_PATH = "genai-idp-terraform/sources/config_library"

# Expected Lambda pricing entries
EXPECTED_LAMBDA_PRICING = {
    "lambda/requests": {"invocations"},
    "lambda/duration": {"gb_seconds"},
}


def get_workspace_root() -> Path:
    """Find the workspace root by looking for known markers."""
    current = Path(__file__).resolve()
    for parent in current.parents:
        if (parent / "genai-idp").exists() and (parent / "genai-idp-terraform").exists():
            return parent
    return Path.cwd()


def compute_file_hash(filepath: Path) -> str:
    """Compute SHA256 hash of a file's contents."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def get_all_files(base_path: Path) -> List[Tuple[str, Path]]:
    """Get all files in a directory recursively."""
    exclude_dirs = {"__pycache__", ".pytest_cache"}
    exclude_file_patterns = {".pyc"}
    
    files = []
    for root, dirnames, filenames in os.walk(base_path):
        dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
        
        for filename in filenames:
            if any(pattern in filename for pattern in exclude_file_patterns):
                continue
            
            abs_path = Path(root) / filename
            rel_path = abs_path.relative_to(base_path)
            files.append((str(rel_path), abs_path))
    return files


def get_config_yaml_files(base_path: Path) -> List[Path]:
    """Get all config.yaml files in the config_library."""
    config_files = []
    for root, _, filenames in os.walk(base_path):
        for filename in filenames:
            if filename == "config.yaml":
                config_files.append(Path(root) / filename)
    return config_files


def parse_yaml_file(filepath: Path) -> Dict:
    """Parse a YAML file and return its contents."""
    if not YAML_AVAILABLE:
        pytest.skip("PyYAML not installed")
    
    with open(filepath, "r") as f:
        return yaml.safe_load(f)


class TestConfigLibrarySynchronization:
    """
    Test class for config_library synchronization integrity.
    
    **Validates: Requirements 1.3, 14.2**
    """

    @pytest.fixture(scope="class")
    def workspace_root(self) -> Path:
        return get_workspace_root()

    @pytest.fixture(scope="class")
    def cdk_config_path(self, workspace_root: Path) -> Path:
        return workspace_root / CDK_CONFIG_PATH

    @pytest.fixture(scope="class")
    def terraform_config_path(self, workspace_root: Path) -> Path:
        return workspace_root / TERRAFORM_CONFIG_PATH

    @pytest.fixture(scope="class")
    def cdk_files(self, cdk_config_path: Path) -> List[Tuple[str, Path]]:
        if not cdk_config_path.exists():
            pytest.skip(f"CDK config path does not exist: {cdk_config_path}")
        return get_all_files(cdk_config_path)

    @pytest.fixture(scope="class")
    def terraform_files(self, terraform_config_path: Path) -> List[Tuple[str, Path]]:
        if not terraform_config_path.exists():
            pytest.skip(f"Terraform config path does not exist: {terraform_config_path}")
        return get_all_files(terraform_config_path)

    def test_file_count_matches(
        self, cdk_files: List[Tuple[str, Path]], terraform_files: List[Tuple[str, Path]]
    ):
        """Property: File counts must match between implementations."""
        cdk_count = len(cdk_files)
        terraform_count = len(terraform_files)
        assert cdk_count == terraform_count, (
            f"File count mismatch: CDK has {cdk_count} files, "
            f"Terraform has {terraform_count} files"
        )

    def test_all_cdk_files_exist_in_terraform(
        self,
        cdk_files: List[Tuple[str, Path]],
        terraform_config_path: Path,
    ):
        """Property: All CDK files must exist in Terraform."""
        missing_files = []
        for rel_path, _ in cdk_files:
            terraform_file = terraform_config_path / rel_path
            if not terraform_file.exists():
                missing_files.append(rel_path)
        
        assert len(missing_files) == 0, (
            f"Missing {len(missing_files)} files in Terraform:\n"
            + "\n".join(f"  - {f}" for f in missing_files)
        )

    def test_file_content_hashes_match(
        self,
        cdk_files: List[Tuple[str, Path]],
        terraform_config_path: Path,
    ):
        """
        Property: File content hashes must match between implementations.
        
        **Validates: Requirements 1.3, 14.2**
        """
        mismatched_files = []
        
        for rel_path, cdk_abs_path in cdk_files:
            terraform_file = terraform_config_path / rel_path
            
            if not terraform_file.exists():
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
            f"Found {len(mismatched_files)} files with hash mismatches:\n"
            + "\n".join(
                f"  {m['file']}: CDK={m['cdk_hash']} vs TF={m['terraform_hash']}"
                for m in mismatched_files
            )
        )

    def test_pattern_directories_exist(self, terraform_config_path: Path):
        """Property: All pattern directories must exist."""
        expected_patterns = ["pattern-1", "pattern-2", "pattern-3"]
        
        missing_patterns = []
        for pattern in expected_patterns:
            if not (terraform_config_path / pattern).exists():
                missing_patterns.append(pattern)
        
        assert len(missing_patterns) == 0, (
            f"Missing pattern directories: {missing_patterns}"
        )

    def test_config_yaml_files_exist(self, terraform_config_path: Path):
        """Property: Config YAML files must exist for all sample configurations."""
        config_files = get_config_yaml_files(terraform_config_path)
        
        assert len(config_files) >= 7, (
            f"Expected at least 7 config.yaml files, found {len(config_files)}"
        )


class TestLambdaPricingEntries:
    """
    Property-based test class for Lambda pricing entries in config files.
    
    Property 3: Configuration Lambda Pricing Entries
    *For any* configuration file in config_library, the file SHALL contain
    valid Lambda pricing entries with invocation_cost and gb_seconds_cost fields.
    
    **Validates: Requirements 2.4**
    """

    @pytest.fixture(scope="class")
    def workspace_root(self) -> Path:
        return get_workspace_root()

    @pytest.fixture(scope="class")
    def terraform_config_path(self, workspace_root: Path) -> Path:
        return workspace_root / TERRAFORM_CONFIG_PATH

    @pytest.fixture(scope="class")
    def config_yaml_files(self, terraform_config_path: Path) -> List[Path]:
        if not terraform_config_path.exists():
            pytest.skip(f"Terraform config path does not exist: {terraform_config_path}")
        return get_config_yaml_files(terraform_config_path)

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not installed")
    def test_all_configs_have_pricing_section(self, config_yaml_files: List[Path]):
        """
        Property: All config files must have a pricing section.
        
        **Validates: Requirements 2.4**
        """
        missing_pricing = []
        
        for config_file in config_yaml_files:
            try:
                config = parse_yaml_file(config_file)
                if "pricing" not in config:
                    missing_pricing.append(str(config_file))
            except Exception as e:
                missing_pricing.append(f"{config_file} (parse error: {e})")
        
        assert len(missing_pricing) == 0, (
            f"Config files missing 'pricing' section:\n"
            + "\n".join(f"  - {f}" for f in missing_pricing)
        )

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not installed")
    def test_all_configs_have_lambda_requests_pricing(self, config_yaml_files: List[Path]):
        """
        Property 3: All config files must have lambda/requests pricing entry.
        
        *For any* configuration file, it SHALL contain lambda/requests pricing
        with invocations unit.
        
        **Validates: Requirements 2.4**
        """
        missing_lambda_requests = []
        
        for config_file in config_yaml_files:
            try:
                config = parse_yaml_file(config_file)
                pricing = config.get("pricing", [])
                
                # Find lambda/requests entry
                lambda_requests = None
                for entry in pricing:
                    if entry.get("name") == "lambda/requests":
                        lambda_requests = entry
                        break
                
                if lambda_requests is None:
                    missing_lambda_requests.append(f"{config_file}: missing lambda/requests entry")
                else:
                    # Verify it has invocations unit
                    units = lambda_requests.get("units", [])
                    has_invocations = any(u.get("name") == "invocations" for u in units)
                    if not has_invocations:
                        missing_lambda_requests.append(
                            f"{config_file}: lambda/requests missing 'invocations' unit"
                        )
            except Exception as e:
                missing_lambda_requests.append(f"{config_file} (parse error: {e})")
        
        assert len(missing_lambda_requests) == 0, (
            f"Lambda requests pricing issues:\n"
            + "\n".join(f"  - {f}" for f in missing_lambda_requests)
        )

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not installed")
    def test_all_configs_have_lambda_duration_pricing(self, config_yaml_files: List[Path]):
        """
        Property 3: All config files must have lambda/duration pricing entry.
        
        *For any* configuration file, it SHALL contain lambda/duration pricing
        with gb_seconds unit.
        
        **Validates: Requirements 2.4**
        """
        missing_lambda_duration = []
        
        for config_file in config_yaml_files:
            try:
                config = parse_yaml_file(config_file)
                pricing = config.get("pricing", [])
                
                # Find lambda/duration entry
                lambda_duration = None
                for entry in pricing:
                    if entry.get("name") == "lambda/duration":
                        lambda_duration = entry
                        break
                
                if lambda_duration is None:
                    missing_lambda_duration.append(f"{config_file}: missing lambda/duration entry")
                else:
                    # Verify it has gb_seconds unit
                    units = lambda_duration.get("units", [])
                    has_gb_seconds = any(u.get("name") == "gb_seconds" for u in units)
                    if not has_gb_seconds:
                        missing_lambda_duration.append(
                            f"{config_file}: lambda/duration missing 'gb_seconds' unit"
                        )
            except Exception as e:
                missing_lambda_duration.append(f"{config_file} (parse error: {e})")
        
        assert len(missing_lambda_duration) == 0, (
            f"Lambda duration pricing issues:\n"
            + "\n".join(f"  - {f}" for f in missing_lambda_duration)
        )

    @pytest.mark.skipif(not YAML_AVAILABLE, reason="PyYAML not installed")
    def test_lambda_pricing_values_are_valid(self, config_yaml_files: List[Path]):
        """
        Property: Lambda pricing values must be valid positive numbers.
        
        **Validates: Requirements 2.4**
        """
        invalid_pricing = []
        
        for config_file in config_yaml_files:
            try:
                config = parse_yaml_file(config_file)
                pricing = config.get("pricing", [])
                
                for entry in pricing:
                    name = entry.get("name", "")
                    if name.startswith("lambda/"):
                        units = entry.get("units", [])
                        for unit in units:
                            price = unit.get("price")
                            if price is None:
                                invalid_pricing.append(
                                    f"{config_file}: {name}/{unit.get('name')} has no price"
                                )
                            else:
                                try:
                                    price_float = float(price)
                                    if price_float <= 0:
                                        invalid_pricing.append(
                                            f"{config_file}: {name}/{unit.get('name')} "
                                            f"has non-positive price: {price}"
                                        )
                                except (ValueError, TypeError):
                                    invalid_pricing.append(
                                        f"{config_file}: {name}/{unit.get('name')} "
                                        f"has invalid price format: {price}"
                                    )
            except Exception as e:
                invalid_pricing.append(f"{config_file} (parse error: {e})")
        
        assert len(invalid_pricing) == 0, (
            f"Invalid Lambda pricing values:\n"
            + "\n".join(f"  - {f}" for f in invalid_pricing)
        )


class TestConfigLibraryVerificationSummary:
    """
    Verification summary tests for config_library synchronization.
    
    **Validates: Requirements 1.3, 2.4, 14.2**
    """

    @pytest.fixture(scope="class")
    def workspace_root(self) -> Path:
        return get_workspace_root()

    @pytest.fixture(scope="class")
    def cdk_config_path(self, workspace_root: Path) -> Path:
        return workspace_root / CDK_CONFIG_PATH

    @pytest.fixture(scope="class")
    def terraform_config_path(self, workspace_root: Path) -> Path:
        return workspace_root / TERRAFORM_CONFIG_PATH

    def test_synchronization_summary(
        self,
        cdk_config_path: Path,
        terraform_config_path: Path,
    ):
        """
        Generate a summary of the config_library synchronization status.
        
        **Validates: Requirements 1.3, 2.4, 14.2**
        """
        if not cdk_config_path.exists() or not terraform_config_path.exists():
            pytest.skip("Config paths do not exist")
        
        # Count files
        cdk_files = get_all_files(cdk_config_path)
        terraform_files = get_all_files(terraform_config_path)
        
        # Count config.yaml files
        cdk_configs = get_config_yaml_files(cdk_config_path)
        terraform_configs = get_config_yaml_files(terraform_config_path)
        
        # Calculate hash matches
        matching_hashes = 0
        for rel_path, cdk_abs_path in cdk_files:
            terraform_file = terraform_config_path / rel_path
            if terraform_file.exists():
                if compute_file_hash(cdk_abs_path) == compute_file_hash(terraform_file):
                    matching_hashes += 1
        
        # Check Lambda pricing in all configs
        lambda_pricing_count = 0
        if YAML_AVAILABLE:
            for config_file in terraform_configs:
                try:
                    config = parse_yaml_file(config_file)
                    pricing = config.get("pricing", [])
                    has_requests = any(e.get("name") == "lambda/requests" for e in pricing)
                    has_duration = any(e.get("name") == "lambda/duration" for e in pricing)
                    if has_requests and has_duration:
                        lambda_pricing_count += 1
                except Exception:
                    pass
        
        # Print summary
        print("\n" + "=" * 60)
        print("CONFIG_LIBRARY SYNCHRONIZATION SUMMARY")
        print("=" * 60)
        print(f"CDK Files:              {len(cdk_files)}")
        print(f"Terraform Files:        {len(terraform_files)}")
        print(f"CDK Config YAMLs:       {len(cdk_configs)}")
        print(f"TF Config YAMLs:        {len(terraform_configs)}")
        print(f"Matching Hashes:        {matching_hashes}/{len(cdk_files)}")
        print(f"Lambda Pricing Configs: {lambda_pricing_count}/{len(terraform_configs)}")
        print(f"Sync Status:            {'✓ COMPLETE' if matching_hashes == len(cdk_files) else '✗ INCOMPLETE'}")
        print(f"Lambda Pricing Status:  {'✓ ALL CONFIGS' if lambda_pricing_count == len(terraform_configs) else '✗ MISSING'}")
        print("=" * 60)
        
        assert True
