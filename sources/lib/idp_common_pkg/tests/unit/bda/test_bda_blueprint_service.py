# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the BdaBlueprintService class.
"""

# ruff: noqa: E402, I001
# The above line disables E402 (module level import not at top of file) and I001 (import block sorting) for this file

import pytest

# Import standard library modules first
import json
from unittest.mock import MagicMock, patch

# Import third-party modules
from botocore.exceptions import ClientError

# Import application modules
from idp_common.bda.bda_blueprint_service import BdaBlueprintService


@pytest.mark.unit
class TestBdaBlueprintService:
    """Tests for the BdaBlueprintService class."""

    @pytest.fixture
    def mock_custom_configuration(self):
        """Fixture providing mock custom configuration data."""
        return {
            "Configuration": "Custom",
            "classes": [
                {
                    "name": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "attributes": [
                        {
                            "name": "PersonalInformation",
                            "description": "Personal information of employee",
                            "attributeType": "group",
                            "groupType": "normal",
                            "groupAttributes": [
                                {
                                    "name": "FirstName",
                                    "dataType": "string",
                                    "description": "First Name of Employee",
                                },
                                {
                                    "name": "LastName",
                                    "dataType": "string",
                                    "description": "Last Name of Employee",
                                },
                            ],
                        }
                    ],
                },
                {
                    "name": "I-9",
                    "description": "Employment Eligibility Verification",
                    "blueprint_arn": "arn:aws:bedrock:us-west-2:123456789012:blueprint/existing-i9-blueprint",
                    "attributes": [
                        {
                            "name": "EmployeeInfo",
                            "description": "Employee information section",
                            "attributeType": "group",
                            "groupType": "normal",
                            "groupAttributes": [
                                {
                                    "name": "FullName",
                                    "dataType": "string",
                                    "description": "Employee full name",
                                }
                            ],
                        }
                    ],
                },
            ],
        }

    @pytest.fixture
    def mock_blueprint_schema(self):
        """Fixture providing mock blueprint schema."""
        return {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "description": "Employee's Withholding Certificate form",
            "class": "W-4",
            "type": "object",
            "definitions": {
                "PersonalInformation": {
                    "type": "object",
                    "properties": {
                        "firstname": {
                            "type": "string",
                            "instruction": "First Name of Employee",
                        },
                        "lastname": {
                            "type": "string",
                            "instruction": "Last Name of Employee",
                        },
                    },
                }
            },
            "properties": {
                "PersonalInformation": {"$ref": "#/definitions/PersonalInformation"}
            },
        }

    @pytest.fixture
    def mock_blueprint_response(self):
        """Fixture providing mock blueprint creation response."""
        return {
            "status": "success",
            "blueprint": {
                "blueprintArn": "arn:aws:bedrock:us-west-2:123456789012:blueprint/w4-12345678",
                "blueprintName": "W-4-12345678",
                "blueprintStage": "LIVE",
                "blueprintVersion": "1",
            },
        }

    @pytest.fixture
    def service(self):
        """Fixture providing a BdaBlueprintService instance with mocked dependencies."""
        with (
            patch("boto3.resource") as mock_dynamodb,
            patch("boto3.client") as mock_boto_client,
            patch(
                "idp_common.bda.bda_blueprint_service.ConfigurationManager"
            ) as mock_config_manager,
            patch.dict("os.environ", {"CONFIGURATION_TABLE_NAME": "test-config-table"}),
        ):
            # Mock DynamoDB table
            mock_table = MagicMock()
            mock_dynamodb.return_value.Table.return_value = mock_table

            # Mock boto3 client for BDABlueprintCreator
            mock_bedrock_client = MagicMock()
            mock_boto_client.return_value = mock_bedrock_client

            # Mock configuration manager
            mock_manager_instance = mock_config_manager.return_value
            mock_manager_instance.get_configuration.return_value = None
            mock_manager_instance.handle_update_custom_configuration.return_value = True

            service = BdaBlueprintService(
                dataAutomationProjectArn="arn:aws:bedrock:us-west-2:123456789012:project/test-project"
            )

            # Store mocks for access in tests
            service._mock_table = mock_table
            service.config_manager = mock_manager_instance

            # Replace the blueprint_creator with a mock
            mock_blueprint_creator = MagicMock()
            service.blueprint_creator = mock_blueprint_creator
            service._mock_blueprint_creator = mock_blueprint_creator

            return service

    def test_init(self):
        """Test initialization of BdaBlueprintService."""
        with (
            patch("boto3.resource") as mock_dynamodb,
            patch("boto3.client") as mock_boto_client,
            patch.dict(
                "os.environ",
                {
                    "CONFIGURATION_TABLE_NAME": "test-config-table",
                    "AWS_REGION": "us-east-1",
                },
            ),
        ):
            service = BdaBlueprintService(
                dataAutomationProjectArn="arn:aws:bedrock:us-west-2:123456789012:project/test-project"
            )

            assert (
                service.dataAutomationProjectArn
                == "arn:aws:bedrock:us-west-2:123456789012:project/test-project"
            )

            # Verify boto3 client was called for BDABlueprintCreator
            mock_boto_client.assert_called_with(service_name="bedrock-data-automation")

            # Verify DynamoDB table was set up
            mock_dynamodb.assert_called_once_with("dynamodb")

    def test_create_blueprints_from_custom_configuration_no_config(self, service):
        """Test handling when no custom configuration exists."""
        # Mock empty configuration retrieval
        service.config_manager.get_configuration.return_value = {
            "Configuration": "Custom",
            "classes": [],
        }

        # This should not raise an exception but should handle empty classes gracefully
        # Note: The current implementation has a bug with len(classess) < 0 which is never true
        # We'll test the actual behavior
        result = service.create_blueprints_from_custom_configuration()

        # Should complete without processing any classes
        assert result["status"] == "success"
        assert "No classes to process" in result["message"]
        service.blueprint_creator.create_blueprint.assert_not_called()
        service.blueprint_creator.update_blueprint.assert_not_called()

    def test_create_blueprints_from_custom_configuration_no_classes_key(self, service):
        """Test handling when configuration has no 'classes' key."""
        # Mock configuration without classes key
        service.config_manager.get_configuration.return_value = {
            "Configuration": "Custom"
        }

        # Should handle missing classes key gracefully
        result = service.create_blueprints_from_custom_configuration()

        assert result["status"] == "success"
        service.blueprint_creator.create_blueprint.assert_not_called()

    def test_create_blueprints_from_custom_configuration_dynamodb_error(self, service):
        """Test handling of DynamoDB error during configuration retrieval."""
        # Mock DynamoDB error
        error_response = {
            "Error": {"Code": "ResourceNotFoundException", "Message": "Table not found"}
        }
        service.config_manager.get_configuration.side_effect = ClientError(
            error_response, "GetItem"
        )

        # Should raise exception on DynamoDB error
        with pytest.raises(Exception, match="Failed to process blueprint creation"):
            service.create_blueprints_from_custom_configuration()

    def test_create_blueprints_from_custom_configuration_partial_failure(
        self, service, mock_custom_configuration
    ):
        """Test handling when one blueprint succeeds and another fails."""
        # Mock configuration retrieval
        service.config_manager.get_configuration.return_value = (
            mock_custom_configuration
        )

        # Mock first blueprint creation success, second failure
        success_response = {
            "status": "success",
            "blueprint": {
                "blueprintArn": "arn:aws:bedrock:us-west-2:123456789012:blueprint/w4-12345678",
                "blueprintName": "W-4-12345678",
            },
        }

        service.blueprint_creator.create_blueprint.return_value = success_response
        service.blueprint_creator.update_blueprint.side_effect = Exception(
            "Update failed"
        )
        service.blueprint_creator.create_blueprint_version.return_value = (
            success_response
        )

        # Should continue processing despite individual failures
        # The method should complete and update configuration with successful blueprints
        service.create_blueprints_from_custom_configuration()

        # Should still update configuration despite partial failure
        service.config_manager.handle_update_custom_configuration.assert_called_once()

    def test_check_for_updates_no_changes(self, service):
        """Test _check_for_updates when no changes are detected."""
        # Mock custom class configuration
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            "attributes": [
                {
                    "name": "PersonalInformation",
                    "description": "Personal info",
                    "groupAttributes": [
                        {
                            "name": "FirstName",
                            "dataType": "string",
                            "description": "First Name of Employee",
                        },
                        {
                            "name": "LastName",
                            "dataType": "string",
                            "description": "Last Name of Employee",
                        },
                    ],
                }
            ],
        }

        # Mock existing blueprint schema that matches the custom class
        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {
                        "Personalinformation": {  # Formatted section name (capitalize)
                            "properties": {
                                "firstname": {  # Formatted field name (lowercase)
                                    "type": "string",
                                    "instruction": "First Name of Employee",
                                },
                                "lastname": {  # Formatted field name (lowercase)
                                    "type": "string",
                                    "instruction": "Last Name of Employee",
                                },
                            }
                        }
                    },
                }
            )
        }

        # Execute the method
        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return False (no updates needed)
        assert result is False

    def test_check_for_updates_class_name_changed(self, service):
        """Test _check_for_updates when class name has changed."""
        custom_class = {
            "name": "W-4-Updated",  # Changed name
            "description": "Employee's Withholding Certificate form",
            "attributes": [],
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",  # Original name
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {},
                }
            )
        }

        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return True (updates needed)
        assert result is True

    def test_check_for_updates_description_changed(self, service):
        """Test _check_for_updates when description has changed."""
        custom_class = {
            "name": "W-4",
            "description": "Updated Employee's Withholding Certificate form",  # Changed description
            "attributes": [],
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",  # Original description
                    "definitions": {},
                }
            )
        }

        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return True (updates needed)
        assert result is True

    def test_check_for_updates_new_group_added(self, service):
        """Test _check_for_updates when a new group is added."""
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            "attributes": [
                {"name": "PersonalInformation", "groupAttributes": []},
                {
                    "name": "NewSection",  # New group not in existing blueprint
                    "groupAttributes": [],
                },
            ],
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {
                        "Personalinformation": {  # Formatted section name (capitalize)
                            "properties": {}
                        }
                        # Newsection is missing
                    },
                }
            )
        }

        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return True (updates needed)
        assert result is True

    def test_check_for_updates_field_description_changed(self, service):
        """Test _check_for_updates when a field description has changed."""
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            "attributes": [
                {
                    "name": "PersonalInformation",
                    "groupAttributes": [
                        {
                            "name": "FirstName",
                            "dataType": "string",
                            "description": "Updated first name description",  # Changed description
                        }
                    ],
                }
            ],
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {
                        "Personalinformation": {  # Formatted section name (capitalize)
                            "properties": {
                                "firstname": {  # Formatted field name (lowercase)
                                    "type": "string",
                                    "instruction": "First Name of Employee",  # Original description
                                }
                            }
                        }
                    },
                }
            )
        }

        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return True (updates needed)
        assert result is True

    def test_check_for_updates_new_field_added(self, service):
        """Test _check_for_updates when a new field is added to existing group."""
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            "attributes": [
                {
                    "name": "PersonalInformation",
                    "groupAttributes": [
                        {
                            "name": "FirstName",
                            "dataType": "string",
                            "description": "First Name of Employee",
                        },
                        {
                            "name": "MiddleName",  # New field
                            "dataType": "string",
                            "description": "Middle Name of Employee",
                        },
                    ],
                }
            ],
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {
                        "Personalinformation": {  # Formatted section name (capitalize)
                            "properties": {
                                "firstname": {  # Formatted field name (lowercase)
                                    "type": "string",
                                    "instruction": "First Name of Employee",
                                }
                                # middlename is missing
                            }
                        }
                    },
                }
            )
        }

        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return True (updates needed)
        assert result is True

    def test_check_for_updates_blueprint_retrieval_error(self, service):
        """Test _check_for_updates when blueprint has invalid schema."""
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            "attributes": [],
        }

        # Invalid blueprint with malformed schema
        invalid_blueprint = {"schema": "invalid json"}

        # Should raise the exception
        with pytest.raises(json.JSONDecodeError):
            service._check_for_updates(custom_class, invalid_blueprint)

    def test_check_for_updates_empty_attributes(self, service):
        """Test _check_for_updates with empty attributes list."""
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            "attributes": [],  # Empty attributes
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {},
                }
            )
        }

        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return False (no updates needed for empty attributes)
        assert result is False

    def test_check_for_updates_missing_attributes_key(self, service):
        """Test _check_for_updates when attributes key is missing."""
        custom_class = {
            "name": "W-4",
            "description": "Employee's Withholding Certificate form",
            # Missing attributes key
        }

        existing_blueprint = {
            "schema": json.dumps(
                {
                    "class": "W-4",
                    "description": "Employee's Withholding Certificate form",
                    "definitions": {},
                }
            )
        }

        # Should handle missing attributes gracefully
        result = service._check_for_updates(custom_class, existing_blueprint)

        # Should return False when attributes is None
        assert result is False
