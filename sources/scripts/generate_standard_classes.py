#!/usr/bin/env python3
"""
Generate standard class catalog from BDA standard blueprints.

This script fetches all AWS standard blueprints from the BDA API using
resourceOwner=SERVICE, converts them to IDP JSON Schema class definitions,
and saves the result as a static JSON catalog file for the UI.

Only DOCUMENT modality blueprints are included.

Usage:
    python scripts/generate_standard_classes.py [--region us-east-1] [--output src/ui/src/data/standard-classes.json]
    make classes-from-bda

Requirements:
    - AWS credentials configured with BDA API access
    - boto3 >= 1.42 installed (pip install --upgrade boto3)
"""

import argparse
import json
import logging
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

import boto3

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def fetch_standard_blueprints(region: str) -> list:
    """Fetch all AWS standard DOCUMENT blueprints from the BDA API.

    Uses resourceOwner=SERVICE to list AWS-managed standard blueprints,
    then fetches full details for each one with DOCUMENT type.
    """
    client = boto3.client("bedrock-data-automation", region_name=region)
    paginator = client.get_paginator("list_blueprints")

    standard_blueprints = []
    logger.info("Listing BDA standard blueprints (resourceOwner=SERVICE)...")

    # Non-document blueprint names to skip (audio, video, image modalities)
    non_document_names = {
        "Keynote-Highlight",
        "Media-Search",
        "General-Audio",
        "Conversational-Analytics",
        "General-Image",
    }

    for page in paginator.paginate(
        resourceOwner="SERVICE",
    ):
        for bp in page.get("blueprints", []):
            arn = bp.get("blueprintArn", "")
            name = bp.get("blueprintName", "")

            # Skip known non-document blueprints
            if name in non_document_names:
                logger.info(f"  Skipping {name} (non-document modality)")
                continue

            try:
                response = client.get_blueprint(
                    blueprintArn=arn, blueprintStage="LIVE"
                )
                blueprint = response.get("blueprint", {})
                bp_type = blueprint.get("type", "DOCUMENT")

                # Double-check type from detail response
                if bp_type and bp_type not in ("DOCUMENT", ""):
                    logger.info(f"  Skipping {name} (type={bp_type})")
                    continue

                standard_blueprints.append(blueprint)
                logger.info(f"  Fetched: {name}")
            except Exception as e:
                logger.warning(f"  Failed to fetch {name}: {e}")

    return standard_blueprints


# ============================================================================
# Self-contained BDA blueprint → IDP JSON Schema conversion
# (Mirrors the logic in idp_common.bda.bda_blueprint_service but without
#  importing the full package and its transitive dependencies)
# ============================================================================


def _transform_bda_definition_to_idp(definition: dict) -> dict:
    """Transform a BDA definition to IDP format."""
    result = {}
    if "type" in definition:
        result["type"] = definition["type"]
    if "description" in definition:
        result["description"] = definition["description"]

    if "properties" in definition:
        result["properties"] = {}
        for prop_name, prop_value in definition["properties"].items():
            result["properties"][prop_name] = _transform_bda_property_to_idp(
                prop_value
            )

    if "required" in definition:
        result["required"] = definition["required"]

    return result


def _transform_bda_property_to_idp(prop: dict) -> dict:
    """Transform a BDA property to IDP format."""
    result = {}

    if "type" in prop:
        result["type"] = prop["type"]
    if "description" in prop:
        result["description"] = prop["description"]
    if "inferenceType" in prop:
        result["x-aws-idp-inference-type"] = prop["inferenceType"]

    # Handle array items
    if "items" in prop:
        items = prop["items"]
        if "$ref" in items:
            result["items"] = {
                "$ref": items["$ref"].replace("#/definitions/", "#/$defs/")
            }
        else:
            result["items"] = _transform_bda_property_to_idp(items)

    # Handle $ref
    if "$ref" in prop:
        result["$ref"] = prop["$ref"].replace("#/definitions/", "#/$defs/")

    # Handle nested properties (inline objects)
    if "properties" in prop:
        result["properties"] = {}
        for sub_name, sub_value in prop["properties"].items():
            result["properties"][sub_name] = _transform_bda_property_to_idp(sub_value)

    if "required" in prop:
        result["required"] = prop["required"]

    return result


def transform_blueprint_to_idp_class(blueprint_schema: dict) -> dict:
    """Convert a BDA blueprint schema to an IDP JSON Schema class definition."""
    schema_copy = deepcopy(blueprint_schema)

    idp_schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": schema_copy.get("class", "Document"),
        "x-aws-idp-document-type": schema_copy.get("class", "Document"),
        "type": "object",
    }

    if "description" in schema_copy:
        idp_schema["description"] = schema_copy["description"]

    if "definitions" in schema_copy:
        idp_schema["$defs"] = {}
        for def_name, def_value in schema_copy["definitions"].items():
            idp_schema["$defs"][def_name] = _transform_bda_definition_to_idp(def_value)

    if "properties" in schema_copy:
        idp_schema["properties"] = {}
        for prop_name, prop_value in schema_copy["properties"].items():
            idp_schema["properties"][prop_name] = _transform_bda_property_to_idp(
                prop_value
            )

    if "required" in schema_copy:
        idp_schema["required"] = schema_copy["required"]

    return idp_schema


def convert_to_catalog(blueprints: list, region: str) -> dict:
    """Convert BDA standard blueprints to IDP class catalog format."""
    catalog_classes = []
    for bp in blueprints:
        try:
            # Get the blueprint schema
            schema_str = bp.get("schema", "{}")
            if isinstance(schema_str, str):
                schema = json.loads(schema_str)
            else:
                schema = schema_str

            # Convert to IDP class schema
            idp_class = transform_blueprint_to_idp_class(schema)

            # Count attributes
            properties = idp_class.get("properties", {})
            has_lists = any(
                prop.get("type") == "array" for prop in properties.values()
            )
            has_nested = bool(idp_class.get("$defs", {}))

            # Enrich with catalog metadata
            catalog_entry = {
                "schema": idp_class,
                "metadata": {
                    "source": "bda-standard-blueprint",
                    "blueprintArn": bp.get("blueprintArn", ""),
                    "blueprintName": bp.get("blueprintName", ""),
                    "description": idp_class.get("description", ""),
                    "attributeCount": len(properties),
                    "hasListTypes": has_lists,
                    "hasNestedTypes": has_nested,
                },
            }
            catalog_classes.append(catalog_entry)
            logger.info(
                f"Converted: {idp_class.get('$id', 'Unknown')} "
                f"({len(properties)} attributes)"
            )

        except Exception as e:
            logger.warning(
                f"Failed to convert blueprint {bp.get('blueprintName', '?')}: {e}"
            )

    return {
        "version": "1.0",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "region": region,
        "description": "Standard document class definitions derived from AWS BDA standard blueprints. Regenerate with: make classes-from-bda",
        "classes": catalog_classes,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate standard class catalog from BDA standard blueprints"
    )
    parser.add_argument(
        "--region", default="us-east-1", help="AWS region (default: us-east-1)"
    )
    parser.add_argument(
        "--output",
        default="src/ui/src/data/standard-classes.json",
        help="Output file path",
    )
    args = parser.parse_args()

    logger.info(f"Fetching BDA standard blueprints from {args.region}...")
    blueprints = fetch_standard_blueprints(args.region)
    logger.info(f"Found {len(blueprints)} standard DOCUMENT blueprints")

    if not blueprints:
        logger.warning(
            "No standard blueprints found. "
            "Ensure boto3 >= 1.42 is installed (pip install --upgrade boto3) "
            "and AWS credentials have BDA access."
        )
        output_path = Path(args.output)
        if output_path.exists():
            logger.info(
                f"Keeping existing catalog at {output_path} (not overwriting with empty)."
            )
        else:
            logger.warning("No existing catalog found. Creating empty catalog.")
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "w") as f:
                json.dump(
                    {
                        "version": "1.0",
                        "generatedAt": datetime.now(timezone.utc).isoformat(),
                        "region": args.region,
                        "classes": [],
                    },
                    f,
                    indent=2,
                )
        return

    catalog = convert_to_catalog(blueprints, args.region)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(catalog, f, indent=2)

    logger.info(f"Catalog written to {output_path}")
    logger.info(f"Total classes: {len(catalog['classes'])}")


if __name__ == "__main__":
    main()
