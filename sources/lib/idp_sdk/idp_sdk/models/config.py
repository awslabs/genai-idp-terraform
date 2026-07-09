# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Configuration-related models."""

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class ConfigCreateResult(BaseModel):
    """Result of config template creation."""

    yaml_content: str = Field(description="Generated YAML configuration content")
    output_path: Optional[str] = Field(
        default=None, description="Path where config was written"
    )


class ConfigValidationResult(BaseModel):
    """Result of configuration validation."""

    valid: bool = Field(description="Whether configuration is valid")
    errors: List[str] = Field(default_factory=list, description="Validation errors")
    warnings: List[str] = Field(default_factory=list, description="Validation warnings")
    deprecated_fields: List[str] = Field(
        default_factory=list,
        description="Deprecated fields found in the configuration file",
    )
    unknown_fields: List[str] = Field(
        default_factory=list,
        description="Unknown fields found in the configuration file (not in IDPConfig schema)",
    )
    merged_config: Optional[Dict[str, Any]] = Field(
        default=None, description="Merged configuration (if show_merged=True)"
    )


class ConfigDownloadResult(BaseModel):
    """Result of config download."""

    config: Dict[str, Any] = Field(description="Configuration dictionary")
    yaml_content: str = Field(description="Configuration as YAML string")
    output_path: Optional[str] = Field(
        default=None, description="Path where config was written"
    )


class ConfigUploadResult(BaseModel):
    """Result of config upload."""

    success: bool = Field(description="Whether upload succeeded")
    version: Optional[str] = Field(
        default=None, description="Configuration version that was uploaded"
    )
    version_created: bool = Field(
        default=False,
        description="True if a new version was created; False if an existing version was updated",
    )
    error: Optional[str] = Field(default=None, description="Error message if failed")


class ConfigActivateResult(BaseModel):
    """Result of a configuration version activation."""

    success: bool = Field(description="Whether activation succeeded")
    activated_version: str = Field(description="The configuration version activated")
    bda_synced: bool = Field(
        default=False,
        description="Whether BDA blueprint sync was performed",
    )
    bda_classes_synced: int = Field(
        default=0,
        description="Number of BDA classes successfully synced",
    )
    bda_classes_failed: int = Field(
        default=0,
        description="Number of BDA classes that failed to sync",
    )
    error: Optional[str] = Field(default=None, description="Error message if failed")


class ConfigVersionInfo(BaseModel):
    """Information about a single configuration version."""

    version_name: str = Field(description="Configuration version name/identifier")
    is_active: bool = Field(
        default=False, description="Whether this is the currently active version"
    )
    created_at: Optional[str] = Field(
        default=None, description="ISO timestamp when version was created"
    )
    updated_at: Optional[str] = Field(
        default=None, description="ISO timestamp when version was last updated"
    )
    description: Optional[str] = Field(
        default=None, description="Optional description for this version"
    )


class ConfigListResult(BaseModel):
    """Result of listing configuration versions."""

    versions: List[ConfigVersionInfo] = Field(
        description="List of configuration versions"
    )
    count: int = Field(description="Total number of versions returned")


class ConfigDeleteResult(BaseModel):
    """Result of deleting a configuration version."""

    success: bool = Field(description="Whether deletion succeeded")
    deleted_version: str = Field(
        description="The configuration version that was deleted"
    )
    error: Optional[str] = Field(default=None, description="Error message if failed")


class ConfigSyncBdaResult(BaseModel):
    """Result of BDA blueprint synchronization."""

    success: bool = Field(description="Whether sync succeeded")
    direction: str = Field(
        description="Sync direction: 'bidirectional', 'bda_to_idp', or 'idp_to_bda'"
    )
    mode: str = Field(
        default="replace",
        description="Sync mode: 'replace' or 'merge'",
    )
    classes_synced: int = Field(
        default=0, description="Number of classes successfully synced"
    )
    classes_failed: int = Field(
        default=0, description="Number of classes that failed to sync"
    )
    processed_classes: List[str] = Field(
        default_factory=list, description="Names of processed classes"
    )
    error: Optional[str] = Field(default=None, description="Error message if failed")
