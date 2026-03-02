# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
import json
import logging
import os
import uuid
from copy import deepcopy
from typing import Optional

from botocore.exceptions import ClientError
from deepdiff import DeepDiff

from idp_common.bda.bda_blueprint_creator import BDABlueprintCreator
from idp_common.config.configuration_manager import ConfigurationManager
from idp_common.config.schema_constants import (
    DEFS_FIELD,
    ID_FIELD,
    REF_FIELD,
    SCHEMA_DESCRIPTION,
    SCHEMA_ITEMS,
    SCHEMA_PROPERTIES,
    SCHEMA_TYPE,
    TYPE_ARRAY,
    TYPE_OBJECT,
    X_AWS_IDP_DOCUMENT_TYPE,
)

logger = logging.getLogger(__name__)


class BdaBlueprintService:
    def __init__(self, dataAutomationProjectArn: Optional[str] = None):
        self.dataAutomationProjectArn = dataAutomationProjectArn
        self.blueprint_creator = BDABlueprintCreator()
        self.blueprint_name_prefix = os.environ.get("STACK_NAME", "")
        self.config_manager = ConfigurationManager()

        return

    def _retrieve_all_blueprints(self, project_arn: str):
        """
        Retrieve all blueprints from the Bedrock Data Automation service.
        If project_arn is provided, retrieves blueprints associated with that project.

        Args:
            project_arn (Optional[str]): ARN of the data automation project to filter blueprints

        Returns:
            list: List of blueprint names and ARNs
        """
        try:
            all_blueprints = []

            # If project ARN is provided, get blueprints from the project
            if project_arn:
                try:
                    blueprint_response = self.blueprint_creator.list_blueprints(
                        projectArn=project_arn, projectStage="LIVE"
                    )

                    blueprints = blueprint_response.get("blueprints", [])
                    for blueprint in blueprints:
                        blueprint_arn = blueprint.get("blueprintArn", None)
                        if "aws:blueprint" in blueprint_arn:
                            continue
                        response = self.blueprint_creator.get_blueprint(
                            blueprint_arn=blueprint_arn, stage="LIVE"
                        )
                        _blueprint = response.get("blueprint")
                        # Add blueprintVersion with default if missing
                        _blueprint["blueprintVersion"] = blueprint.get(
                            "blueprintVersion", "1"
                        )
                        all_blueprints.append(_blueprint)
                    logger.info(
                        f"{len(all_blueprints)} blueprints retrieved for {project_arn}"
                    )
                    logger.info(
                        f"blueprints retrieved {json.dumps(all_blueprints, default=str)}"
                    )
                    return all_blueprints

                except ClientError as e:
                    logger.warning(f"Could not retrieve project {project_arn}: {e}")
                    # Fall through to list all blueprints
                    return []

        except Exception as e:
            logger.error(f"Error retrieving blueprints: {e}")
            return []

    def _transform_json_schema_to_bedrock_blueprint(self, json_schema: dict) -> dict:
        """
        Transform JSON Schema (draft 2020-12) to BDA blueprint format (draft-07).

        BDA requirements based on working schemas:
        - Uses "definitions" (not "$defs") - JSON Schema draft-07
        - References use "#/definitions/" (not "#/$defs/")
        - Only LEAF properties get "inferenceType" and "instruction"
        - Object/array types do NOT get these fields

        Args:
            json_schema: JSON Schema from configuration

        Returns:
            Blueprint schema in BDA-compatible draft-07 format
        """
        # Extract $defs and convert to definitions
        defs = json_schema.get(DEFS_FIELD, {})

        # Start with BDA-expected structure
        blueprint = {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "class": json_schema.get(
                ID_FIELD, json_schema.get(X_AWS_IDP_DOCUMENT_TYPE, "Document")
            ),
            "description": json_schema.get(
                SCHEMA_DESCRIPTION, "Document schema for data extraction"
            ),
            "type": TYPE_OBJECT,
        }

        # Convert definitions and add BDA fields to leaf properties only
        if defs:
            blueprint["definitions"] = {}
            for def_name, def_value in defs.items():
                blueprint["definitions"][def_name] = self._add_bda_fields_to_schema(
                    def_value
                )

        # Transform properties and update $ref paths
        blueprint["properties"] = {}
        for prop_name, prop_value in json_schema.get(SCHEMA_PROPERTIES, {}).items():
            transformed = self._add_bda_fields_to_schema(prop_value)
            # Update $ref paths from #/$defs/ to #/definitions/
            if REF_FIELD in transformed:
                transformed[REF_FIELD] = transformed[REF_FIELD].replace(
                    "/$defs/", "/definitions/"
                )
            blueprint["properties"][prop_name] = transformed

        return blueprint

    def _add_bda_fields_to_schema(self, schema: dict) -> dict:
        """
        Add BDA fields (inferenceType, instruction) ONLY to leaf properties.

        Critical BDA requirements (based on working schemas):
        - Pure $ref properties: ONLY the $ref field
        - Object/array types: ONLY type and properties (NO description, inferenceType, instruction)
        - Leaf types: type, inferenceType, instruction (NO description)

        Args:
            schema: Property or definition schema

        Returns:
            Schema with BDA fields, description removed
        """
        if not isinstance(schema, dict):
            return schema

        # If this has a $ref, return ONLY the $ref (strip all other fields)
        if REF_FIELD in schema:
            # Pure $ref should have nothing else - this is critical for BDA
            return {REF_FIELD: schema[REF_FIELD].replace("/$defs/", "/definitions/")}

        # Make deep copy to avoid mutation
        result = deepcopy(schema)

        # Remove description field - BDA doesn't use it (only instruction)
        result.pop(SCHEMA_DESCRIPTION, None)

        prop_type = result.get(SCHEMA_TYPE, "string")

        # Add BDA fields ONLY for leaf/primitive types
        if prop_type not in [TYPE_OBJECT, TYPE_ARRAY]:
            # This is a leaf property - add BDA fields
            if "inferenceType" not in result:
                result["inferenceType"] = "inferred"

            if "instruction" not in result:
                # Use description if available before we removed it
                if SCHEMA_DESCRIPTION in schema:
                    result["instruction"] = schema[SCHEMA_DESCRIPTION]
                else:
                    result["instruction"] = "Extract this field from the document"

        # Recursively process nested structures
        if prop_type == TYPE_OBJECT and SCHEMA_PROPERTIES in result:
            result[SCHEMA_PROPERTIES] = {
                name: self._add_bda_fields_to_schema(value)
                for name, value in result[SCHEMA_PROPERTIES].items()
            }

        # Handle array items (but don't add BDA fields to the array itself)
        if prop_type == TYPE_ARRAY and SCHEMA_ITEMS in result:
            result[SCHEMA_ITEMS] = self._add_bda_fields_to_schema(result[SCHEMA_ITEMS])

        return result

    def _add_bedrock_fields_to_property(self, prop: dict) -> dict:
        """
        Add Bedrock-specific fields (instruction, inferenceType) to a property.
        """
        # If this node is a pure reference, return a safe copy without augmenting.
        if isinstance(prop, dict) and REF_FIELD in prop:
            return deepcopy(prop)

        # Make a deep copy to avoid modifying the original schema structure.
        result = deepcopy(prop)

        # Add instruction from description if not present
        if "instruction" not in result and SCHEMA_DESCRIPTION in result:
            result["instruction"] = result[SCHEMA_DESCRIPTION]
        elif "instruction" not in result:
            result["instruction"] = "Extract this field from the document"

        # Add inferenceType if not present
        if "inferenceType" not in result:
            result["inferenceType"] = "inferred"  # Default to inferred for most fields

        # Recursively handle nested objects
        if result.get(SCHEMA_TYPE) == TYPE_OBJECT and SCHEMA_PROPERTIES in result:
            for nested_name, nested_value in result[SCHEMA_PROPERTIES].items():
                result[SCHEMA_PROPERTIES][nested_name] = (
                    self._add_bedrock_fields_to_property(nested_value)
                )

        # Handle array items
        if result.get(SCHEMA_TYPE) == TYPE_ARRAY and SCHEMA_ITEMS in result:
            result[SCHEMA_ITEMS] = self._add_bedrock_fields_to_property(
                result[SCHEMA_ITEMS]
            )

        return result

    def _check_for_updates(self, custom_class: dict, blueprint: dict):
        """
        Check if the custom_class JSON Schema differs from the existing blueprint.
        Transform both to Bedrock format and then compare.
        """
        # Parse the blueprint schema
        blueprint_schema = blueprint["schema"]
        if isinstance(blueprint_schema, str):
            blueprint_schema = json.loads(blueprint_schema)

        # Transform the custom_class to Bedrock format for comparison
        transformed_custom = self._transform_json_schema_to_bedrock_blueprint(
            custom_class
        )

        # Use DeepDiff to compare the schemas
        diff = DeepDiff(blueprint_schema, transformed_custom, ignore_order=True)

        updates_found = bool(diff)

        if updates_found:
            logger.info("Schema changes detected between custom class and blueprint")
            # Log specific differences for debugging
            logger.info(f"Differences found: {diff}")

        return updates_found

    def _blueprint_lookup(self, existing_blueprints, doc_class):
        # Create a lookup dictionary for existing blueprints by name prefix
        _blueprint_prefix = f"{self.blueprint_name_prefix}-{doc_class}"
        logger.info(f"blueprint lookup using name {_blueprint_prefix}")
        for blueprint in existing_blueprints:
            blueprint_name = blueprint.get("blueprintName", "")
            if blueprint_name.startswith(_blueprint_prefix):
                return blueprint
        return None

    def create_blueprints_from_custom_configuration(self):
        """
        Create blueprint from custom configurations.
        Raises:
            Exception: If blueprint creation fails
        """
        logger.info("Creating blueprint for document ")

        try:
            config_item = self.config_manager.get_configuration(config_type="Custom")

            if (
                not config_item
                or not hasattr(config_item, "classes")
                or not config_item.classes
            ):
                logger.info("No Custom configuration to process")
                return {"status": "success", "message": "No classes to process"}

            classess = config_item.classes

            if not classess or len(classess) == 0:
                logger.info("No Custom configuration to process")
                return {"status": "success", "message": "No classes to process"}

            classess_status = []
            # retrieve all blueprints for this project.
            existing_blueprints = self._retrieve_all_blueprints(
                self.dataAutomationProjectArn
            )

            blueprints_updated = []

            for custom_class in classess:
                try:
                    blueprint_arn = custom_class.get("blueprint_arn", None)
                    blueprint_name = custom_class.get("blueprint_name", None)
                    docu_class = custom_class.get(
                        ID_FIELD, custom_class.get(X_AWS_IDP_DOCUMENT_TYPE, "")
                    )
                    blueprint_exists = self._blueprint_lookup(
                        existing_blueprints, docu_class
                    )
                    if blueprint_exists:
                        blueprint_arn = blueprint_exists.get("blueprintArn")
                        blueprint_name = blueprint_exists.get("blueprintName")
                        logger.info(
                            f"blueprint already exists for this class {docu_class} updating blueprint {blueprint_arn}"
                        )

                    if blueprint_arn:
                        # Use existing blueprint
                        # Note: We don't modify custom_class since it's a JSON Schema
                        logger.info(
                            f"Found existing blueprint for class {docu_class}: {blueprint_name}"
                        )
                        blueprints_updated.append(blueprint_arn)

                        # Check for updates on existing blueprint
                        if self._check_for_updates(
                            custom_class=custom_class, blueprint=blueprint_exists
                        ):
                            blueprint_schema = (
                                self._transform_json_schema_to_bedrock_blueprint(
                                    custom_class
                                )
                            )
                            logger.info(
                                f"Blueprint schema generate:: for {json.dumps(custom_class, indent=2)}"
                            )
                            logger.info(json.dumps(blueprint_schema, indent=2))
                            logger.info("Blueprint schema generate:: END")

                            result = self.blueprint_creator.update_blueprint(
                                blueprint_arn=blueprint_arn,
                                stage="LIVE",
                                schema=json.dumps(blueprint_schema),
                            )
                            result = self.blueprint_creator.create_blueprint_version(
                                blueprint_arn=blueprint_arn,
                                project_arn=self.dataAutomationProjectArn,
                            )
                            # Note: We don't store blueprint_version in custom_class since it's a JSON Schema
                            logger.info(
                                f"Updated existing blueprint for class {docu_class}"
                            )
                        else:
                            logger.info(
                                f"No updates needed for existing blueprint {blueprint_name}"
                            )

                    else:
                        # create new blueprint
                        # Call the create_blueprint method
                        blueprint_name = f"{self.blueprint_name_prefix}-{docu_class}-{uuid.uuid4().hex[:8]}"

                        blueprint_schema = (
                            self._transform_json_schema_to_bedrock_blueprint(
                                custom_class
                            )
                        )
                        logger.info(
                            f"Blueprint schema generate:: for {json.dumps(custom_class, indent=2)}"
                        )
                        logger.info(json.dumps(blueprint_schema, indent=2))
                        logger.info("Blueprint schema generate:: END")

                        result = self.blueprint_creator.create_blueprint(
                            document_type="DOCUMENT",
                            blueprint_name=blueprint_name,
                            schema=json.dumps(blueprint_schema),
                        )
                        status = result["status"]
                        logger.info(f"blueprint created status {status}")
                        if status != "success":
                            raise Exception(f"Failed to create blueprint: {result}")

                        blueprint_arn = result["blueprint"]["blueprintArn"]
                        blueprint_name = result["blueprint"]["blueprintName"]
                        # Note: We don't store blueprint metadata in custom_class since it's a JSON Schema
                        # update the project or create new project
                        # update the project with version
                        result = self.blueprint_creator.create_blueprint_version(
                            blueprint_arn=blueprint_arn,
                            project_arn=self.dataAutomationProjectArn,
                        )
                        blueprints_updated.append(blueprint_arn)
                        logger.info(
                            f"Created new blueprint for class {docu_class}: {blueprint_name}"
                        )
                    classess_status.append(
                        {
                            "class": docu_class,  # Use the docu_class we extracted earlier
                            "blueprint_arn": blueprint_arn,
                            "status": "success",
                        }
                    )

                except Exception as e:
                    class_name = (
                        custom_class.get(
                            ID_FIELD,
                            custom_class.get(X_AWS_IDP_DOCUMENT_TYPE, "unknown"),
                        )
                        if custom_class
                        else "unknown"
                    )
                    logger.error(
                        f"Error processing blueprint creation/update for class {class_name}: {e}"
                    )
                    classess_status.append(
                        {
                            "class": class_name,
                            "status": "failed",
                            "error_message": f"Exception - {str(e)}",
                        }
                    )
            self._synchronize_deletes(
                existing_blueprints=existing_blueprints,
                blueprints_updated=blueprints_updated,
            )
            self.config_manager.handle_update_custom_configuration(
                {"classes": classess}
            )

            return classess_status

        except Exception as e:
            logger.error(f"Error processing blueprint creation: {e}", exc_info=True)
            # Re-raise the exception to be handled by the caller
            raise Exception(f"Failed to process blueprint creation: {str(e)}")

    def _synchronize_deletes(self, existing_blueprints, blueprints_updated):
        # remove all blueprints which are not in custom class
        blueprints_to_delete = []
        blueprints_arn_to_delete = []
        for blueprint in existing_blueprints:
            blueprint_name = blueprint.get("blueprintName", "")
            blueprint_arn = blueprint.get("blueprintArn", "")
            blueprint_version = blueprint.get("blueprintVersion", "")
            if blueprint_arn in blueprints_updated:
                continue
            if blueprint_name.startswith(self.blueprint_name_prefix):
                # delete detected - remove the blueprint
                logger.info(f"deleting blueprint not in custom class {blueprint_name}")
                blueprints_to_delete.append(blueprint)
                blueprints_arn_to_delete.append(blueprint_arn)

        if len(blueprints_to_delete) > 0:
            # remove the blueprints marked for deletion for the project first before deleting them.
            response = self.blueprint_creator.list_blueprints(
                self.dataAutomationProjectArn, "LIVE"
            )
            custom_configurations = response.get("blueprints", [])
            new_custom_configurations = []
            for custom_blueprint in custom_configurations:
                if custom_blueprint.get("blueprintArn") not in blueprints_arn_to_delete:
                    new_custom_configurations.append(custom_blueprint)
            new_custom_configurations = {"blueprints": new_custom_configurations}
            response = self.blueprint_creator.update_project_with_custom_configurations(
                self.dataAutomationProjectArn,
                customConfiguration=new_custom_configurations,
            )

            try:
                for _blueprint_delete in blueprints_to_delete:
                    self.blueprint_creator.delete_blueprint(
                        _blueprint_delete.get("blueprintArn"),
                        _blueprint_delete.get("blueprintVersion"),
                    )
            except Exception:
                logger.error(
                    f"Error during deleting blueprint {blueprint_name} {blueprint_arn} {blueprint_version}"
                )
            try:
                for _blueprint_delete in blueprints_to_delete:
                    self.blueprint_creator.delete_blueprint(
                        _blueprint_delete.get("blueprintArn"), None
                    )
            except Exception:
                logger.error(
                    f"Error during deleting blueprint {blueprint_name} {blueprint_arn} {blueprint_version}"
                )
