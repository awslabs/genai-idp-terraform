# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from __future__ import annotations

import boto3
import json
import os
from typing import Dict, Any, Optional, Union
from botocore.exceptions import ClientError
import logging
import datetime

from .models import IDPConfig, SchemaConfig, ConfigurationRecord
from .merge_utils import deep_update, get_diff_dict
from .constants import (
    CONFIG_TYPE_SCHEMA,
    CONFIG_TYPE_DEFAULT,
    CONFIG_TYPE_CUSTOM,
    VALID_CONFIG_TYPES,
)

logger = logging.getLogger(__name__)


class ConfigurationManager:
    """
    Manages IDP configurations stored in DynamoDB.

    All operations use IDPConfig (Pydantic models) - no dict manipulation!
    ConfigurationRecord handles DynamoDB serialization internally.

    Example:
        manager = ConfigurationManager()

        # Get configuration (always returns IDPConfig)
        config = manager.get_configuration(CONFIG_TYPE_DEFAULT)

        # Save configuration
        manager.save_configuration(CONFIG_TYPE_CUSTOM, config)
    """

    def __init__(self, table_name: Optional[str] = None):
        """
        Initialize the configuration manager.

        Args:
            table_name: Optional override for configuration table name.
                       If not provided, uses CONFIGURATION_TABLE_NAME env var.

        Raises:
            ValueError: If table name cannot be determined
        """
        table_name = table_name or os.environ.get("CONFIGURATION_TABLE_NAME")
        if not table_name:
            raise ValueError(
                "Configuration table name not provided. Either set CONFIGURATION_TABLE_NAME "
                "environment variable or provide table_name parameter."
            )

        self.dynamodb = boto3.resource("dynamodb")
        self.table = self.dynamodb.Table(table_name)  # pyright: ignore[reportAttributeAccessIssue]
        self.table_name = table_name
        logger.info(f"ConfigurationManager initialized with table: {table_name}")

    def get_configuration(
        self, config_type: str
    ) -> Optional[Union[SchemaConfig, IDPConfig]]:
        """
        Retrieve configuration from DynamoDB.

        This method:
        1. Reads the DynamoDB item
        2. Deserializes into ConfigurationRecord (auto-migrates legacy format)
        3. Checks if migration occurred and persists if needed
        4. Returns SchemaConfig for Schema type, IDPConfig for Default/Custom

        Args:
            config_type: Configuration type (Schema, Default, Custom)

        Returns:
            SchemaConfig for Schema type, IDPConfig for Default/Custom, or None if not found

        Raises:
            ClientError: If DynamoDB operation fails
        """
        try:
            record = self._read_record(config_type)
            if record is None:
                logger.info(f"Configuration not found: {config_type}")
                return None

            # Note: ConfigurationRecord.from_dynamodb_item() auto-migrates legacy format
            # We don't need to check for migration separately - it's already done
            # If we want to persist the migration, we can optionally do so here

            return record.config

        except ClientError as e:
            logger.error(f"Error retrieving configuration {config_type}: {e}")
            raise

    def sync_custom_with_new_default(
        self, old_default: IDPConfig, new_default: IDPConfig, old_custom: IDPConfig
    ) -> IDPConfig:
        """
        Sync Custom config when Default is updated, preserving user customizations.

        Algorithm:
        1. Find what the user customized (diff between old_custom and old_default)
        2. Start with new_default
        3. Apply user customizations to new_default

        This ensures users get all new default values except for fields they customized.

        Args:
            old_default: Previous default configuration
            new_default: New default configuration being saved
            old_custom: Current custom configuration

        Returns:
            New custom configuration with user changes preserved
        """
        from copy import deepcopy

        # Convert to dicts
        old_default_dict = old_default.model_dump(mode="python")
        old_custom_dict = old_custom.model_dump(mode="python")
        new_default_dict = new_default.model_dump(mode="python")

        # Find what the user customized (only fields that differ)
        user_customizations = get_diff_dict(old_default_dict, old_custom_dict)

        logger.info(
            f"User customizations to preserve: {list(user_customizations.keys())}"
        )

        # Start with new default and apply user customizations
        new_custom_dict = deepcopy(new_default_dict)
        deep_update(new_custom_dict, user_customizations)

        return IDPConfig(**new_custom_dict)

    def save_configuration(
        self,
        config_type: str,
        config: Union[SchemaConfig, IDPConfig, Dict[str, Any]],
        skip_sync: bool = False,
    ) -> None:
        """
        Save configuration to DynamoDB.

        This method:
        1. Converts dict to IDPConfig if needed
        2. If saving Default, syncs Custom to preserve user customizations (unless skip_sync=True)
        3. Creates ConfigurationRecord
        4. Serializes to DynamoDB item
        5. Writes to DynamoDB
        6. Sends notification

        Args:
            config_type: Configuration type (Schema, Default, Custom)
            config: SchemaConfig, IDPConfig model, or dict (dict will be converted to appropriate type)
            skip_sync: If True, skip automatic Custom sync when saving Default (used for save-as-default)

        Raises:
            ClientError: If DynamoDB operation fails
        """
        # Convert dict to appropriate config type if needed (for backward compatibility)
        if isinstance(config, dict):
            if config_type == CONFIG_TYPE_SCHEMA:
                config = SchemaConfig(**config)
            else:
                config = IDPConfig(**config)

        # If updating Default, sync Custom to preserve user customizations
        # Skip sync if this is a "save as default" operation where Custom will be deleted
        if (
            config_type == CONFIG_TYPE_DEFAULT
            and not skip_sync
            and isinstance(config, IDPConfig)
        ):
            old_default = self.get_configuration(CONFIG_TYPE_DEFAULT)
            old_custom = self.get_configuration(CONFIG_TYPE_CUSTOM)

            if (
                old_default
                and old_custom
                and isinstance(old_default, IDPConfig)
                and isinstance(old_custom, IDPConfig)
            ):
                logger.info(
                    "Syncing Custom config with new Default while preserving user customizations"
                )
                new_custom = self.sync_custom_with_new_default(
                    old_default, config, old_custom
                )
                # Save the synced custom config
                self.save_configuration(CONFIG_TYPE_CUSTOM, new_custom, skip_sync=True)

        # Create record
        record = ConfigurationRecord(configuration_type=config_type, config=config)

        # Write to DynamoDB
        self._write_record(record)

        # Send notification
        self._send_update_notification(config_type, config)

    def delete_configuration(self, config_type: str) -> None:
        """
        Delete configuration from DynamoDB.

        Args:
            config_type: Configuration type to delete

        Raises:
            ClientError: If DynamoDB operation fails
        """
        try:
            self.table.delete_item(Key={"Configuration": config_type})
            logger.info(f"Deleted configuration: {config_type}")
        except ClientError as e:
            logger.error(f"Error deleting configuration {config_type}: {e}")
            raise

    def handle_update_custom_configuration(
        self, custom_config: Union[str, Dict[str, Any], IDPConfig]
    ) -> bool:
        """
        Handle the updateConfiguration GraphQL mutation.

        This method:
        1. Parses the input (JSON string, dict, or IDPConfig)
        2. Validates that config is not empty (prevents data loss)
        3. Checks for saveAsDefault flag
        4. Either updates Custom or merges into Default
        5. Sends notifications

        Args:
            custom_config: Configuration as JSON string, dict, or IDPConfig

        Returns:
            True on success

        Raises:
            Exception: If configuration update fails or is empty
        """
        # Reject completely empty configuration to prevent accidental data deletion
        if not custom_config:
            logger.error("Rejecting empty configuration update")
            raise Exception(
                "Cannot update with empty configuration. Frontend should not send empty diffs."
            )

        # Parse input
        if isinstance(custom_config, str):
            config_dict = json.loads(custom_config)
        elif isinstance(custom_config, IDPConfig):
            config_dict = custom_config.model_dump(mode="python")
        else:
            config_dict = custom_config

        # Additional validation: reject if parsed config is empty dict
        if isinstance(config_dict, dict) and len(config_dict) == 0:
            logger.error("Rejecting empty configuration dict")
            raise Exception(
                "Cannot update with empty configuration. Frontend should not send empty diffs."
            )

        # Extract special flags
        save_as_default = config_dict.pop("saveAsDefault", False)
        reset_to_default = config_dict.pop("resetToDefault", False)

        # Handle reset to default - delete Custom entirely
        # On next getConfiguration, the auto-copy logic will repopulate Custom from Default
        if reset_to_default:
            logger.info("Resetting Custom configuration by deleting it")
            self.delete_configuration(CONFIG_TYPE_CUSTOM)
            logger.info(
                "Custom configuration deleted, will be repopulated from Default on next read"
            )
            return True

        # Convert to IDPConfig
        config = IDPConfig(**config_dict)

        if save_as_default:
            # Save as Default: Replace Default with the received config (current Custom state)
            # Frontend sends the complete merged Custom config
            # This becomes the new baseline for all users
            # Skip sync since we're about to delete Custom anyway
            self.save_configuration(CONFIG_TYPE_DEFAULT, config, skip_sync=True)

            # Delete Custom since it's now the same as Default
            self.delete_configuration(CONFIG_TYPE_CUSTOM)

            logger.info("Saved current Custom as new Default and cleared Custom")
        else:
            # Normal custom config update - merge diff into existing Custom
            # Data Flow: Frontend sends diff, we merge into existing Custom
            # Note: Custom should always exist (getConfiguration copies Default on first read)
            existing_custom = self.get_configuration(CONFIG_TYPE_CUSTOM)
            if not existing_custom or not existing_custom.model_dump(
                exclude_unset=True
            ):
                # Fallback: If Custom is somehow empty, use Default as base
                # This should rarely happen due to auto-copy in getConfiguration
                logger.warning(
                    "Custom config is empty during update, using Default as base"
                )
                existing_custom = (
                    self.get_configuration(CONFIG_TYPE_DEFAULT) or IDPConfig()
                )

            # Apply the diff to existing Custom (deep update to handle nested objects)
            existing_dict = existing_custom.model_dump(mode="python")
            update_dict = config.model_dump(mode="python", exclude_unset=True)
            deep_update(existing_dict, update_dict)
            merged_custom = IDPConfig(**existing_dict)

            # Save updated Custom configuration
            self.save_configuration(CONFIG_TYPE_CUSTOM, merged_custom)
            logger.info("Updated Custom configuration by merging diff")

        return True

    # ===== Private Methods =====

    def _read_record(self, config_type: str) -> Optional[ConfigurationRecord]:
        """
        Read ConfigurationRecord from DynamoDB.

        Args:
            config_type: Configuration type to read

        Returns:
            ConfigurationRecord or None if not found
        """
        response = self.table.get_item(Key={"Configuration": config_type})
        item = response.get("Item")

        if item is None:
            return None

        return ConfigurationRecord.from_dynamodb_item(item)

    def _write_record(self, record: ConfigurationRecord) -> None:
        """
        Write ConfigurationRecord to DynamoDB.

        Args:
            record: ConfigurationRecord to write
        """
        item = record.to_dynamodb_item()
        self.table.put_item(Item=item)
        logger.info(f"Saved configuration: {record.configuration_type}")

    def _send_update_notification(
        self, configuration_key: str, configuration_data: Union[SchemaConfig, IDPConfig]
    ) -> None:
        """
        Send a message to the ConfigurationQueue to notify pattern-specific processors
        about configuration updates.

        Args:
            configuration_key: The configuration key that was updated ('Schema', 'Custom' or 'Default')
            configuration_data: The updated configuration (SchemaConfig or IDPConfig model)
        """
        try:
            configuration_queue_url = os.environ.get("CONFIGURATION_QUEUE_URL")
            if not configuration_queue_url:
                logger.debug(
                    "CONFIGURATION_QUEUE_URL environment variable not set, skipping notification"
                )
                return

            sqs = boto3.client("sqs")

            # Create message payload
            message_body = {
                "eventType": "CONFIGURATION_UPDATED",
                "configurationKey": configuration_key,
                "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
                "data": {
                    "configurationKey": configuration_key,
                },
            }

            # Send message to SQS
            response = sqs.send_message(
                QueueUrl=configuration_queue_url,
                MessageBody=json.dumps(message_body),
                MessageAttributes={
                    "eventType": {
                        "StringValue": "CONFIGURATION_UPDATED",
                        "DataType": "String",
                    },
                    "configurationKey": {
                        "StringValue": configuration_key,
                        "DataType": "String",
                    },
                },
            )

            logger.info(
                f"Configuration update message sent to queue. MessageId: {response.get('MessageId')}"
            )

        except Exception as e:
            logger.warning(f"Failed to send configuration update message: {e}")
            # Don't fail the entire operation if queue message fails
