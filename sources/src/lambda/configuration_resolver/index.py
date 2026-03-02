# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

from idp_common.config.configuration_manager import ConfigurationManager
from idp_common.config.models import SchemaConfig, IDPConfig
from idp_common.config.constants import (
    CONFIG_TYPE_SCHEMA,
    CONFIG_TYPE_DEFAULT,
    CONFIG_TYPE_CUSTOM,
)
from pydantic import ValidationError
import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))
logging.getLogger("idp_common.bedrock.client").setLevel(
    os.environ.get("BEDROCK_LOG_LEVEL", "INFO")
)


def handler(event, context):
    """
    AWS Lambda handler for GraphQL operations related to configuration.

    Returns structured responses with success/error information:

    Success response:
    {
        "success": true,
        "Schema": {...},
        "Default": {...},
        "Custom": {...}
    }

    Error response:
    {
        "success": false,
        "error": {
            "type": "ValidationError" | "JSONDecodeError",
            "message": "...",
            "validationErrors": [...]  // if ValidationError
        }
    }
    """
    logger.info(f"Event received: {json.dumps(event)}")

    # Extract the GraphQL operation type
    operation = event["info"]["fieldName"]

    # Initialize ConfigurationManager
    manager = ConfigurationManager()

    try:
        if operation == "getConfiguration":
            return handle_get_configuration(manager)
        elif operation == "updateConfiguration":
            args = event["arguments"]
            custom_config = args.get("customConfig")
            success = manager.handle_update_custom_configuration(custom_config)
            return {
                "success": success,
                "message": "Configuration updated successfully"
                if success
                else "Configuration update failed",
            }
        elif operation == "listConfigurationLibrary":
            return handle_list_config_library(event["arguments"])
        elif operation == "getConfigurationLibraryFile":
            return handle_get_config_library_file(event["arguments"])
        else:
            raise Exception(f"Unsupported operation: {operation}")
    except ValidationError as e:
        # Pydantic validation error - return structured error for UI
        logger.error(f"Configuration validation error: {e}")

        # Build structured error response that UI can parse
        validation_errors = []
        for error in e.errors():
            field_path = " -> ".join(str(loc) for loc in error["loc"])
            validation_errors.append(
                {"field": field_path, "message": error["msg"], "type": error["type"]}
            )

        # Return error as data (not exception) so UI can handle it
        return {
            "success": False,
            "error": {
                "type": "ValidationError",
                "message": "Configuration validation failed",
                "validationErrors": validation_errors,
            },
        }

    except json.JSONDecodeError as e:
        # JSON parsing error - return structured error
        logger.error(f"JSON decode error: {e}")
        return {
            "success": False,
            "error": {
                "type": "JSONDecodeError",
                "message": f"Invalid JSON format: {str(e)}",
                "position": {
                    "line": e.lineno if hasattr(e, "lineno") else None,
                    "column": e.colno if hasattr(e, "colno") else None,
                },
            },
        }


def handle_get_configuration(manager):
    """
    Handle the getConfiguration GraphQL query
    Returns Schema, Default, and Custom configuration items with auto-migration support

    Data Flow:
    1. If Custom is empty on first read, copy Default → Custom
    2. Frontend only uses Custom for display and diffing
    3. Default is only used for "Reset to Default" operation

    New ConfigurationManager API returns IDPConfig directly - convert to dict for GraphQL
    """
    try:
        # Get all configurations - migration happens automatically in get_configuration
        # API returns SchemaConfig for Schema, IDPConfig for Default/Custom
        schema_config = manager.get_configuration(CONFIG_TYPE_SCHEMA)
        if schema_config:
            # Remove config_type discriminator before sending to frontend
            schema_dict = schema_config.model_dump(
                mode="python", exclude={"config_type"}
            )
        else:
            schema_dict = {}

        default_config = manager.get_configuration(CONFIG_TYPE_DEFAULT)
        if default_config and isinstance(default_config, IDPConfig):
            default_dict = default_config.model_dump(
                mode="python", exclude={"config_type"}
            )
        else:
            default_dict = {}

        custom_config = manager.get_configuration(CONFIG_TYPE_CUSTOM)

        # IMPORTANT: If Custom is empty on first read, copy Default → Custom
        # This ensures frontend always has a complete config to diff against
        if not custom_config or (
            isinstance(custom_config, IDPConfig)
            and not custom_config.model_dump(exclude_unset=True)
        ):
            logger.info("Custom config is empty, copying Default → Custom")
            if default_config and isinstance(default_config, IDPConfig):
                manager.save_configuration(CONFIG_TYPE_CUSTOM, default_config)
                custom_config = default_config
                logger.info("Copied Default to Custom on first read")
            else:
                logger.warning("Default config is also empty, using empty Custom")

        if custom_config and isinstance(custom_config, IDPConfig):
            custom_dict = custom_config.model_dump(
                mode="python", exclude={"config_type"}
            )
        else:
            custom_dict = {}

        # Return all configurations as dicts (GraphQL requires JSON-serializable)
        result = {
            "success": True,
            "Schema": schema_dict,
            "Default": default_dict,
            "Custom": custom_dict,
        }

        logger.info(f"Returning configuration")
        return result

    except Exception as e:
        logger.error(f"Error in getConfiguration: {str(e)}")
        raise e


def handle_list_config_library(args):
    """
    List available configurations from S3 config_library for a specific pattern
    Returns: { success: bool, items: [...], error: str }
    """
    import boto3
    from botocore.exceptions import ClientError

    pattern = args.get("pattern")
    if not pattern:
        return {"success": False, "items": [], "error": "Pattern parameter is required"}

    try:
        s3_client = boto3.client("s3")
        bucket_name = os.environ.get("CONFIGURATION_BUCKET")
        prefix = f"config_library/{pattern}/"

        logger.info(
            f"Listing config library for pattern: {pattern} in bucket: {bucket_name}"
        )

        # List "directories" under the pattern folder
        response = s3_client.list_objects_v2(
            Bucket=bucket_name, Prefix=prefix, Delimiter="/"
        )

        items = []

        # CommonPrefixes are the "directories" (config folders)
        for common_prefix in response.get("CommonPrefixes", []):
            config_dir = common_prefix["Prefix"]
            config_name = config_dir.rstrip("/").split("/")[-1]

            # Check if README.md exists in this config directory
            readme_key = f"{config_dir}README.md"
            has_readme = False

            try:
                s3_client.head_object(Bucket=bucket_name, Key=readme_key)
                has_readme = True
            except ClientError as e:
                if e.response["Error"]["Code"] != "404":
                    logger.warning(f"Error checking README for {config_name}: {e}")

            # Detect which config file type exists (prefer YAML, fallback to JSON)
            config_file_type = None
            yaml_key = f"{config_dir}config.yaml"
            json_key = f"{config_dir}config.json"

            try:
                s3_client.head_object(Bucket=bucket_name, Key=yaml_key)
                config_file_type = "yaml"
            except ClientError:
                # YAML doesn't exist, try JSON
                try:
                    s3_client.head_object(Bucket=bucket_name, Key=json_key)
                    config_file_type = "json"
                except ClientError:
                    logger.warning(
                        f"No config file found for {config_name} (checked yaml and json)"
                    )
                    # Skip this config if no config file exists
                    continue

            items.append({
                "name": config_name,
                "hasReadme": has_readme,
                "path": config_dir,
                "configFileType": config_file_type
            })

        if not items:
            logger.info(f"No configurations found for pattern: {pattern}")

        logger.info(f"Found {len(items)} configurations for pattern: {pattern}")
        return {"success": True, "items": items, "error": None}

    except ClientError as e:
        logger.error(f"S3 error listing config library: {e}")
        return {
            "success": False,
            "items": [],
            "error": f"Failed to list configurations: {str(e)}",
        }
    except Exception as e:
        logger.error(f"Error listing config library: {e}")
        return {
            "success": False,
            "items": [],
            "error": f"Unexpected error: {str(e)}",
        }


def handle_get_config_library_file(args):
    """
    Get a specific file (config.yaml or README.md) from config library
    Returns: { success: bool, content: str, contentType: str, error: str }
    """
    import boto3
    from botocore.exceptions import ClientError

    pattern = args.get("pattern")
    config_name = args.get("configName")
    file_name = args.get("fileName")

    if not all([pattern, config_name, file_name]):
        return {
            "success": False,
            "content": "",
            "contentType": "",
            "error": "Missing required parameters",
        }

    # Security: Only allow specific file names
    if file_name not in ["config.yaml", "config.json", "README.md"]:
        return {
            "success": False,
            "content": "",
            "contentType": "",
            "error": f"Invalid file name: {file_name}",
        }

    try:
        s3_client = boto3.client("s3")
        bucket_name = os.environ.get("CONFIGURATION_BUCKET")
        key = f"config_library/{pattern}/{config_name}/{file_name}"

        logger.info(f"Getting file from S3: {bucket_name}/{key}")

        response = s3_client.get_object(Bucket=bucket_name, Key=key)
        content = response["Body"].read().decode("utf-8")

        # Set appropriate content type based on file extension
        if file_name == "README.md":
            content_type = "text/markdown"
        elif file_name == "config.json":
            content_type = "application/json"
        else:
            content_type = "text/yaml"

        logger.info(
            f"Successfully retrieved {file_name} for {pattern}/{config_name} "
            f"({len(content)} bytes)"
        )
        return {
            "success": True,
            "content": content,
            "contentType": content_type,
            "error": None,
        }

    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            error_msg = f"File not found: {file_name}"
        else:
            error_msg = f"S3 error: {str(e)}"

        logger.error(f"Error getting config library file: {error_msg}")
        return {
            "success": False,
            "content": "",
            "contentType": "",
            "error": error_msg,
        }
    except Exception as e:
        logger.error(f"Error getting config library file: {e}")
        return {
            "success": False,
            "content": "",
            "contentType": "",
            "error": f"Unexpected error: {str(e)}",
        }
