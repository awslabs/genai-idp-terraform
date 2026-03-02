# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Stickler-based Evaluation Service for document extraction results.

This module provides a service for evaluating extraction results using
the Stickler library for structured object comparison.
"""

import concurrent.futures
import logging
import os
import time
import traceback
from concurrent.futures import ThreadPoolExecutor
from typing import TYPE_CHECKING, Any, Dict, Optional, Tuple, Type, Union

if TYPE_CHECKING:
    from stickler import StructuredModel

from idp_common import s3
from idp_common.config.models import IDPConfig
from idp_common.evaluation.doc_split_classification_metrics import (
    DocSplitClassificationMetrics,
)
from idp_common.evaluation.metrics import calculate_metrics
from idp_common.evaluation.models import (
    AttributeEvaluationResult,
    DocSplitMetrics,
    DocumentEvaluationResult,
    SectionEvaluationResult,
)
from idp_common.evaluation.stickler_mapper import SticklerConfigMapper
from idp_common.models import Document, Section, Status

logger = logging.getLogger(__name__)


def _normalize_comparator_name(comparator: str) -> str:
    """
    Map Stickler comparator names to UI picklist values (PascalCase).

    Args:
        comparator: Internal Stickler comparator name

    Returns:
        Normalized UI-friendly method name
    """
    mapping = {
        "FuzzyComparator": "Fuzzy",
        "ExactComparator": "Exact",
        "NumericComparator": "NumericExact",
        "LevenshteinComparator": "Levenshtein",
        "SemanticComparator": "Semantic",
        "LLMComparator": "LLM",
    }
    return mapping.get(comparator, comparator)


def _convert_numpy_types(obj: Any) -> Any:
    """
    Recursively convert numpy types to Python native types for JSON serialization.

    Args:
        obj: Object that may contain numpy types

    Returns:
        Object with numpy types converted to Python native types
    """
    import numpy as np

    if isinstance(obj, np.bool_):
        return bool(obj)
    elif isinstance(obj, np.integer):
        return int(obj)
    elif isinstance(obj, np.floating):
        return float(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, dict):
        return {key: _convert_numpy_types(value) for key, value in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [_convert_numpy_types(item) for item in obj]
    else:
        return obj


class EvaluationService:
    """
    Stickler-based evaluation service for document extraction results.

    This service maintains the same API as the legacy implementation but uses
    Stickler internally for comparison logic, providing enhanced features like
    field weighting and optimized list matching.
    """

    def __init__(
        self,
        region: Optional[str] = None,
        config: Optional[Union[Dict[str, Any], IDPConfig]] = None,
        max_workers: int = 10,
    ):
        """
        Initialize the evaluation service.

        Args:
            region: AWS region
            config: Configuration dictionary or IDPConfig model containing evaluation settings
            max_workers: Maximum number of concurrent workers for section evaluation
        """
        # Convert dict to IDPConfig if needed
        if config is not None and isinstance(config, dict):
            config_model: IDPConfig = IDPConfig(**config)
        elif config is None:
            config_model = IDPConfig()
        else:
            config_model = config

        self.config = config_model
        self.region = region or os.environ.get("AWS_REGION")
        self.max_workers = max_workers

        # Import and check Stickler availability
        try:
            from stickler import StructuredModel

            self._StructuredModel = StructuredModel

            # Set up global LLM configuration for LLMComparator
            # This must be done BEFORE building Stickler models
            try:
                from stickler.structured_object_evaluator.models.comparator_registry import (
                    _global_registry,
                    register_comparator,
                )

                from idp_common.evaluation.llm_comparator import (
                    LLMComparator,  # noqa: F401
                    set_global_llm_config,
                )

                # Build config dict for extraction
                if hasattr(config_model, "model_dump"):
                    config_dict = config_model.model_dump()
                elif hasattr(config_model, "dict"):
                    config_dict = config_model.dict()
                else:
                    config_dict = (
                        dict(config_model)
                        if not isinstance(config_model, dict)
                        else config_model
                    )

                # Extract and set global LLM config if present
                evaluation_config = config_dict.get("evaluation", {})
                if isinstance(evaluation_config, dict):
                    llm_config = evaluation_config.get("llm_method")
                    if llm_config:
                        set_global_llm_config(llm_config)

                # Register our LLMComparator with Stickler
                # Force-replace Stickler's built-in LLMComparator with ours
                if _global_registry.is_registered("LLMComparator"):
                    # Directly replace in registry (no unregister method available)
                    _global_registry._registry["LLMComparator"] = LLMComparator  # type: ignore[assignment]
                    logger.info(
                        "Replaced Stickler's LLMComparator with IDP LLMComparator in registry"
                    )
                else:
                    register_comparator("LLMComparator", LLMComparator)  # type: ignore[arg-type]
                    logger.info(
                        "Registered IDP LLMComparator with Stickler comparator registry"
                    )

            except ImportError as e:
                logger.warning(f"LLMComparator setup failed: {e}")
                config_dict = None

        except ImportError:
            raise ImportError(
                "Stickler library is required for evaluation. "
                "Install with: pip install -e '.[evaluation]'"
            )

        # Build Stickler configurations using mapper
        # Reuse config_dict if already built, otherwise build it now
        if config_dict is None:
            if hasattr(config_model, "model_dump"):
                config_dict = config_model.model_dump()
            elif hasattr(config_model, "dict"):
                config_dict = config_model.dict()
            else:
                config_dict = (
                    dict(config_model)
                    if not isinstance(config_model, dict)
                    else config_model
                )

        self.stickler_models = SticklerConfigMapper.build_all_stickler_configs(
            config_dict
        )

        # Cache for Stickler model classes
        self._model_cache: Dict[str, Type["StructuredModel"]] = {}

        # Track which models were auto-generated (for annotation in results)
        self._auto_generated_models: set = set()

        logger.info(
            f"Initialized Stickler-based evaluation service with "
            f"{len(self.stickler_models)} document classes, max_workers={max_workers}"
        )

    def _infer_schema_from_data(
        self, data: Dict[str, Any], document_class: str
    ) -> Dict[str, Any]:
        """
        Infer JSON Schema from data structure using genson library.

        Uses the production-ready genson library for robust schema generation,
        then adds IDP-specific evaluation extensions.

        Args:
            data: Dictionary containing the expected extraction results
            document_class: Name of the document class

        Returns:
            Generated JSON Schema with IDP evaluation extensions
        """
        from genson import SchemaBuilder

        from idp_common.config.schema_constants import (
            X_AWS_IDP_DOCUMENT_TYPE,
            X_AWS_IDP_EVALUATION_MATCH_THRESHOLD,
        )

        # Use genson to generate base schema
        builder = SchemaBuilder()
        builder.add_object(data)
        schema = builder.to_schema()

        # Add IDP-specific metadata
        schema["$id"] = f"autogenerated_{document_class.lower().replace(' ', '_')}"
        schema[X_AWS_IDP_DOCUMENT_TYPE] = document_class
        schema[X_AWS_IDP_EVALUATION_MATCH_THRESHOLD] = 0.8

        # Add evaluation method extensions recursively
        self._add_evaluation_extensions_recursive(schema)

        # Count properties for logging
        num_properties = len(schema.get("properties", {}))

        logger.warning(
            f"Auto-generated schema for document class '{document_class}' using genson library. "
            f"For production use, please define an explicit configuration. "
            f"Generated {num_properties} properties."
        )

        return schema

    def _add_evaluation_extensions_recursive(self, schema: Dict[str, Any]) -> None:
        """
        Recursively add IDP evaluation method extensions to schema.

        Adds x-aws-idp-evaluation-method and x-aws-idp-evaluation-threshold
        based on the inferred JSON Schema types.

        Args:
            schema: Schema object to modify in-place
        """
        from idp_common.config.schema_constants import (
            EVALUATION_METHOD_EXACT,
            EVALUATION_METHOD_FUZZY,
            EVALUATION_METHOD_HUNGARIAN,
            EVALUATION_METHOD_NUMERIC_EXACT,
            SCHEMA_ITEMS,
            SCHEMA_PROPERTIES,
            SCHEMA_TYPE,
            TYPE_ARRAY,
            TYPE_BOOLEAN,
            TYPE_INTEGER,
            TYPE_NUMBER,
            TYPE_OBJECT,
            TYPE_STRING,
            X_AWS_IDP_EVALUATION_METHOD,
            X_AWS_IDP_EVALUATION_THRESHOLD,
        )

        schema_type = schema.get(SCHEMA_TYPE)

        # Handle union types from genson (e.g., ["string", "integer"])
        if isinstance(schema_type, list):
            # Use first type for evaluation method
            schema_type = schema_type[0] if schema_type else TYPE_STRING

        # Add evaluation method based on type
        if schema_type == TYPE_STRING:
            schema[X_AWS_IDP_EVALUATION_METHOD] = EVALUATION_METHOD_FUZZY
            schema[X_AWS_IDP_EVALUATION_THRESHOLD] = 0.85
        elif schema_type in [TYPE_NUMBER, TYPE_INTEGER]:
            schema[X_AWS_IDP_EVALUATION_METHOD] = EVALUATION_METHOD_NUMERIC_EXACT
            schema[X_AWS_IDP_EVALUATION_THRESHOLD] = 0.01
        elif schema_type == TYPE_BOOLEAN:
            schema[X_AWS_IDP_EVALUATION_METHOD] = EVALUATION_METHOD_EXACT
        elif schema_type == TYPE_ARRAY:
            # Recursively process array items
            items = schema.get(SCHEMA_ITEMS, {})
            if isinstance(items, dict):
                items_type = items.get(SCHEMA_TYPE)
                # Array of objects gets Hungarian matching
                if items_type == TYPE_OBJECT:
                    schema[X_AWS_IDP_EVALUATION_METHOD] = EVALUATION_METHOD_HUNGARIAN
                # Recurse into items
                self._add_evaluation_extensions_recursive(items)
        elif schema_type == TYPE_OBJECT:
            # Recursively process object properties
            properties = schema.get(SCHEMA_PROPERTIES, {})
            for prop_schema in properties.values():
                self._add_evaluation_extensions_recursive(prop_schema)

    def _get_stickler_model(
        self, document_class: str, expected_data: Optional[Dict[str, Any]] = None
    ) -> Type["StructuredModel"]:
        """
        Get or create Stickler model for document class.

        Uses Stickler's JsonSchemaFieldConverter to handle JSON Schema natively,
        including $ref resolution, required fields, and nested structures.

        If no configuration exists and expected_data is provided, automatically
        generates a schema from the expected data structure.

        Args:
            document_class: Document class name
            expected_data: Optional expected data for auto-generating schema

        Returns:
            Stickler StructuredModel class for this document type

        Raises:
            ValueError: If no configuration found and no expected_data provided
        """
        # Check cache
        cache_key = document_class.lower()
        if cache_key in self._model_cache:
            logger.debug(f"Using cached Stickler model for class: {document_class}")
            return self._model_cache[cache_key]

        # Get Stickler config for this class
        stickler_config = self.stickler_models.get(cache_key)
        if not stickler_config:
            # Try to auto-generate schema from expected data
            if expected_data:
                logger.info(
                    f"No configuration found for '{document_class}'. "
                    f"Auto-generating schema from expected data structure."
                )

                # Infer schema from data
                inferred_schema = self._infer_schema_from_data(
                    expected_data, document_class
                )

                # Build Stickler config from inferred schema
                stickler_config = SticklerConfigMapper.build_stickler_model_config(
                    inferred_schema
                )

                # Cache the auto-generated config for this session
                self.stickler_models[cache_key] = stickler_config

                # Mark this model as auto-generated
                self._auto_generated_models.add(cache_key)
            else:
                raise ValueError(
                    f"No schema configuration found for document class: {document_class}. "
                    f"Cannot auto-generate schema without expected data."
                )

        # Extract the schema and model info
        schema = stickler_config["schema"]
        model_name = stickler_config["model_name"]

        # Enhanced logging: Log schema details before creating model
        logger.info(
            f"Creating Stickler model for class: {document_class}\n"
            f"  Schema summary:\n"
            f"    - Properties: {list(schema.get('properties', {}).keys())}\n"
            f"    - Required fields: {schema.get('required', [])}\n"
            f"    - Schema ID: {schema.get('$id', 'N/A')}\n"
            f"    - Model name: {model_name}"
        )

        # Log expected and actual data structure for troubleshooting
        if expected_data:
            logger.info(
                f"  Expected data keys for {document_class}: {list(expected_data.keys())}"
            )

        # DEBUG: Log full JSON Schema for detailed troubleshooting
        if logger.isEnabledFor(logging.DEBUG):
            import json

            logger.debug(
                f"Full JSON Schema for {document_class}: "
                f"{json.dumps(schema, default=str)}"
            )

        try:
            # Use JsonSchemaFieldConverter to handle the full JSON Schema natively
            from stickler.structured_object_evaluator.models.json_schema_field_converter import (
                JsonSchemaFieldConverter,
            )

            logger.debug(f"Converting schema properties for {document_class}")

            converter = JsonSchemaFieldConverter(schema)
            field_definitions = converter.convert_properties_to_fields(
                schema.get("properties", {}), schema.get("required", [])
            )

            logger.info(
                f"Successfully converted schema for {document_class} with {len(field_definitions)} fields"
            )

            # DEBUG: Log converted field definitions with detailed type information
            if logger.isEnabledFor(logging.DEBUG):
                properties = schema.get("properties", {})
                field_details = []
                for name, field_info in field_definitions.items():
                    prop_schema = properties.get(name, {})
                    comparator = prop_schema.get(
                        "x-aws-stickler-comparator", "inferred"
                    )
                    threshold = prop_schema.get("x-aws-stickler-threshold")
                    weight = prop_schema.get("x-aws-stickler-weight")

                    detail = f"  - {name}: {field_info[0].__name__ if hasattr(field_info[0], '__name__') else field_info[0]}"
                    if comparator != "inferred":
                        detail += f" (comparator={comparator}"
                        if threshold is not None:
                            detail += f", threshold={threshold}"
                        if weight is not None:
                            detail += f", weight={weight}"
                        detail += ")"

                    field_details.append(detail)

                logger.debug(
                    f"Converted field definitions for {document_class}:\n"
                    + "\n".join(field_details)
                )

        except Exception as e:
            # Enhanced error handling with user guidance
            import json
            import re

            error_message = str(e)

            # Check if it's a JSON Schema validation error
            if (
                "jsonschema.exceptions.SchemaError" in str(type(e))
                or "Invalid JSON Schema" in error_message
            ):
                # Try to extract the problematic field from the error
                field_match = re.search(
                    r"On schema\['properties'\]\['([^']+)'\]", error_message
                )
                field_name = field_match.group(1) if field_match else "unknown"

                # Parse for constraint information
                constraint_match = re.search(
                    r"\['([^']+)'\]\s*:\s*'([^']+)'", error_message
                )
                constraint = (
                    constraint_match.group(1) if constraint_match else "unknown"
                )
                bad_value = constraint_match.group(2) if constraint_match else "unknown"

                # Build helpful error message
                helpful_message = (
                    f"Invalid JSON Schema for document class '{document_class}'.\n\n"
                    f"Problem detected:\n"
                    f"  Field: {field_name}\n"
                    f"  Constraint: {constraint}\n"
                    f"  Current value: '{bad_value}' (type: {type(bad_value).__name__})\n\n"
                    f"Common fixes:\n"
                    f"  1. If '{constraint}' should be a number, remove quotes in your config:\n"
                    f"     {constraint}: '{bad_value}' → {constraint}: {bad_value}\n"
                    f"  2. Check your config YAML for field '{field_name}' in class '{document_class}'\n"
                    f"  3. Ensure all numeric constraints (maxItems, minItems, minimum, maximum, etc.) are numbers, not strings\n\n"
                    f"Original error: {error_message}"
                )

                logger.error(helpful_message)
                logger.error(
                    f"Full schema that caused the error:\n{json.dumps(schema, indent=2, default=str)}"
                )
                raise ValueError(helpful_message) from e
            else:
                # Re-raise other errors with schema details
                logger.error(
                    f"Unexpected error creating Stickler model for {document_class}: {error_message}"
                )
                logger.error(
                    f"Schema being processed:\n{json.dumps(schema, indent=2, default=str)}"
                )
                raise

        # Create the model using Pydantic's create_model
        from pydantic import create_model

        # Type checker can't understand dynamic field unpacking - this is expected
        model_class = create_model(  # type: ignore  # pyright: reportArgumentType=false
            model_name, **field_definitions, __base__=self._StructuredModel
        )

        # Cache for reuse
        self._model_cache[cache_key] = model_class
        logger.debug(f"Cached Stickler model: {model_class.__name__}")

        # DEBUG: Log Pydantic model structure for verification
        if logger.isEnabledFor(logging.DEBUG):
            model_fields_info = (
                model_class.model_fields if hasattr(model_class, "model_fields") else {}
            )
            field_types = [
                f"    {k}: {v.annotation}" for k, v in model_fields_info.items()
            ]
            logger.debug(
                f"Created Pydantic model structure for {document_class}:\n"
                f"  Model: {model_class.__name__}\n"
                f"  Base classes: {[base.__name__ for base in model_class.__bases__]}\n"
                f"  Field count: {len(model_fields_info)}\n"
                f"  Field types:\n" + "\n".join(field_types)
                if field_types
                else "    (no fields)"
            )

        # DEBUG: Test instantiation with expected data (if available)
        if expected_data and logger.isEnabledFor(logging.DEBUG):
            try:
                # Clean and coerce data before test instantiation
                cleaned_data = self._remove_none_values(expected_data)
                coerced_data = self._coerce_data_to_schema(cleaned_data, model_class)
                test_instance = model_class(**coerced_data)

                # Serialize the instance to show what Stickler will work with
                if hasattr(test_instance, "model_dump"):
                    serialized = test_instance.model_dump()
                elif hasattr(test_instance, "dict"):
                    serialized = test_instance.dict()
                else:
                    serialized = dict(test_instance)

                import json

                logger.debug(
                    f"Test instantiation successful for {document_class}: "
                    f"{json.dumps(serialized, default=str)}"
                )
            except Exception as e:
                logger.debug(
                    f"Test instantiation failed for {document_class} "
                    f"(this is informational only): {str(e)}"
                )

        return model_class

    def _prepare_stickler_data(self, uri: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        """
        Load extraction results and confidence scores from S3.

        Args:
            uri: S3 URI to the extraction results

        Returns:
            Tuple of (extraction_data, confidence_scores)
        """
        try:
            content = s3.get_json_content(uri)

            # Extract inference result
            if isinstance(content, dict) and "inference_result" in content:
                extraction_data = content["inference_result"]
            else:
                extraction_data = content

            # Extract confidence scores from explainability_info
            confidence_scores = {}
            if isinstance(content, dict) and "explainability_info" in content:
                explainability_info = content["explainability_info"]
                if (
                    isinstance(explainability_info, list)
                    and len(explainability_info) > 0
                ):
                    confidence_scores = explainability_info[0]

            return extraction_data, confidence_scores

        except Exception as e:
            logger.error(
                f"Error loading extraction results from {uri}: {str(e)}", exc_info=True
            )
            return {}, {}

    def _get_nested_value(self, obj: Any, path: str) -> Any:
        """
        Get value from nested dict using dot notation path.

        Args:
            obj: Dict to extract value from (already serialized by Pydantic)
            path: Dot-notation path (e.g., "address.city" or "items[0].name")

        Returns:
            Value at the specified path, or None if not found.
        """
        import re

        try:
            # Handle list indices in path (e.g., "items[0].name")
            parts = []
            for part in path.split("."):
                # Check for list index notation
                match = re.match(r"^([^\[]+)\[(\d+)\]$", part)
                if match:
                    parts.append(("field", match.group(1)))
                    parts.append(("index", int(match.group(2))))
                else:
                    parts.append(("field", part))

            # Navigate through the path
            current = obj
            for part_type, part_value in parts:
                if part_type == "field":
                    if isinstance(current, dict):
                        current = current.get(part_value)
                    elif hasattr(current, part_value):
                        # Handle objects with attributes (e.g., Pydantic models, MagicMock)
                        current = getattr(current, part_value)
                    else:
                        return None
                elif part_type == "index":
                    if isinstance(current, (list, tuple)):
                        if part_value < len(current):
                            current = current[part_value]
                        else:
                            return None
                    else:
                        return None

            return current

        except Exception as e:
            logger.debug(f"Error getting nested value for path '{path}': {str(e)}")
            return None

    def _get_confidence_for_field(
        self, confidence_scores: Dict[str, Any], field_name: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get confidence information for a specific field.

        Args:
            confidence_scores: Nested confidence scores dictionary
            field_name: Field name (may use dot notation or list indices)

        Returns:
            Dictionary with confidence and confidence_threshold, or None
        """
        try:
            # Try to get confidence using the same path logic
            confidence_value = self._get_nested_value(confidence_scores, field_name)

            if isinstance(confidence_value, dict) and "confidence" in confidence_value:
                conf_threshold = confidence_value.get("confidence_threshold")
                return {
                    "confidence": float(confidence_value["confidence"]),
                    "confidence_threshold": float(conf_threshold)
                    if conf_threshold is not None
                    else None,
                }

            return None

        except Exception as e:
            logger.debug(
                f"Error extracting confidence for field '{field_name}': {str(e)}"
            )
            return None

    def _generate_reason(
        self,
        field_name: str,
        expected_value: Any,
        actual_value: Any,
        score: float,
        matched: bool,
        comparator: Optional[str],
        is_auto_generated: bool = False,
    ) -> str:
        """
        Generate a reason explanation for the comparison result.

        Args:
            field_name: Name of the field
            expected_value: Expected value
            actual_value: Actual value
            score: Comparison score
            matched: Whether the values matched
            comparator: Comparator type used
            is_auto_generated: Whether the schema was auto-generated

        Returns:
            Reason string explaining the result
        """
        # Check for empty values
        exp_empty = expected_value is None or (
            isinstance(expected_value, str) and not expected_value.strip()
        )
        act_empty = actual_value is None or (
            isinstance(actual_value, str) and not actual_value.strip()
        )

        # Build base reason
        if exp_empty and act_empty:
            base_reason = "Both values are empty"
        elif matched:
            if score >= 0.99:
                base_reason = "Exact match"
            elif score >= 0.9:
                base_reason = f"Very close match (score: {score:.2f})"
            else:
                base_reason = f"Match above threshold (score: {score:.2f})"
        else:
            if exp_empty:
                base_reason = "Expected value missing but actual value present"
            elif act_empty:
                base_reason = "Actual value missing but expected value present"
            else:
                base_reason = f"Values do not match (score: {score:.2f}, comparator: {comparator or 'default'})"

        # Append auto-generation notice if applicable
        if is_auto_generated:
            return f"{base_reason}. Note: Schema inferred (no config)"
        else:
            return base_reason

    def _transform_stickler_result(
        self,
        section: Section,
        expected_instance: "StructuredModel",
        actual_instance: "StructuredModel",
        stickler_result: Dict[str, Any],
        confidence_scores: Dict[str, Any],
    ) -> SectionEvaluationResult:
        """
        Transform Stickler comparison result to IDP SectionEvaluationResult.

        Extracts field scores from Stickler, creates AttributeEvaluationResult
        objects, injects confidence scores, and calculates metrics.

        Args:
            section: Document section being evaluated
            expected_instance: Stickler model instance with expected values
            actual_instance: Stickler model instance with actual values
            stickler_result: Result from Stickler's compare_with() method
            confidence_scores: Confidence scores from assessment

        Returns:
            SectionEvaluationResult with all attribute results and metrics
        """
        attribute_results = []

        # Convert Pydantic model instances to dicts upfront using Pydantic's serialization
        # This handles nested models and lists automatically
        if hasattr(expected_instance, "model_dump"):
            expected_dict = expected_instance.model_dump()
        elif hasattr(expected_instance, "dict"):
            expected_dict = expected_instance.dict()
        else:
            expected_dict = dict(expected_instance)

        if hasattr(actual_instance, "model_dump"):
            actual_dict = actual_instance.model_dump()
        elif hasattr(actual_instance, "dict"):
            actual_dict = actual_instance.dict()
        else:
            actual_dict = dict(actual_instance)

        # Get field scores from Stickler result
        field_scores = stickler_result.get("field_scores", {})

        # Get Stickler configuration for this document class
        stickler_config = self.stickler_models.get(section.classification.lower(), {})
        match_threshold = stickler_config.get("match_threshold", 0.8)

        # Check if this model was auto-generated
        is_auto_generated = (
            section.classification.lower() in self._auto_generated_models
        )

        # Extract field configs from schema properties
        schema = stickler_config.get("schema", {})
        properties = schema.get("properties", {})

        # Build a field config map from the schema
        field_configs = {}
        for field_name, field_schema in properties.items():
            field_configs[field_name] = {
                "threshold": field_schema.get("x-aws-stickler-threshold"),
                "match_threshold": field_schema.get("x-aws-stickler-match-threshold"),
                "comparator": field_schema.get("x-aws-stickler-comparator"),
                "weight": field_schema.get("x-aws-stickler-weight"),
            }

        # Track metrics
        tp = fp = fn = tn = fp1 = fp2 = 0

        for field_name, score in field_scores.items():
            # Get field configuration
            field_config = field_configs.get(field_name, {})

            # Extract expected and actual values from dicts (already plain data)
            expected_value = self._get_nested_value(expected_dict, field_name)
            actual_value = self._get_nested_value(actual_dict, field_name)

            # Get confidence from assessment if available
            confidence_info = self._get_confidence_for_field(
                confidence_scores, field_name
            )

            # Determine threshold for matching decision
            # IMPORTANT: Never use match_threshold for field comparisons - it's only for Hungarian
            field_specific_threshold = field_config.get("threshold")

            # Determine appropriate threshold based on method and data type
            comparator_method = field_config.get("comparator")
            if comparator_method:
                # Use field-specific or method default
                method_name = _normalize_comparator_name(comparator_method)
                method_defaults = {
                    "Fuzzy": 0.7,
                    "Semantic": 0.7,
                    "Levenshtein": 0.7,
                }
                field_threshold = (
                    field_specific_threshold
                    if field_specific_threshold is not None
                    else method_defaults.get(method_name, 0.8)
                )
            elif isinstance(expected_value, list) or isinstance(actual_value, list):
                # Arrays use match_threshold for Hungarian item pairing
                field_threshold = field_config.get("match_threshold") or match_threshold
            elif isinstance(expected_value, str) or isinstance(actual_value, str):
                # Inferred string comparison - use field-specific or Fuzzy default
                field_threshold = (
                    field_specific_threshold
                    if field_specific_threshold is not None
                    else 0.7
                )
            else:
                # Other types (numbers, booleans, objects) - use field-specific or high default
                field_threshold = (
                    field_specific_threshold
                    if field_specific_threshold is not None
                    else 0.99
                )

            matched = score >= field_threshold

            # Check for empty values
            exp_empty = expected_value is None or (
                isinstance(expected_value, str) and not str(expected_value).strip()
            )
            act_empty = actual_value is None or (
                isinstance(actual_value, str) and not str(actual_value).strip()
            )

            # Update metrics
            if exp_empty and act_empty:
                tn += 1
                matched = True  # Both empty is considered a match
            elif exp_empty and not act_empty:
                fp += 1
                fp1 += 1
                matched = False
            elif not exp_empty and act_empty:
                fn += 1
                matched = False
            elif matched:
                tp += 1
            else:
                fp += 1
                fp2 += 1

            # Generate reason (include auto-generation notice if applicable)
            reason = self._generate_reason(
                field_name,
                expected_value,
                actual_value,
                score,
                matched,
                field_config.get("comparator"),
                is_auto_generated=is_auto_generated,
            )

            # Build formatted evaluation method string that matches markdown display
            comparator_method = field_config.get("comparator")

            # Only these methods use similarity thresholds
            # Note: NumericExact uses tolerance (not threshold), LLM returns binary match
            THRESHOLD_BASED_METHODS = {
                "Fuzzy": 0.7,
                "Semantic": 0.7,
                "Levenshtein": 0.7,
            }

            if comparator_method:
                # Normalize comparator name to UI-friendly format
                evaluation_method_value = _normalize_comparator_name(comparator_method)

                # Show threshold ONLY for methods that use similarity thresholds
                if evaluation_method_value in THRESHOLD_BASED_METHODS:
                    # Use field-specific threshold if set, else use method default
                    display_threshold = (
                        field_specific_threshold
                        if field_specific_threshold is not None
                        else THRESHOLD_BASED_METHODS[evaluation_method_value]
                    )
                    evaluation_method_value = f"{evaluation_method_value} (threshold: {display_threshold:.2f})"
                # Exact, NumericExact, LLM, AggregateObject don't show thresholds

            elif isinstance(expected_value, list) or isinstance(actual_value, list):
                # Arrays use Hungarian matching - show field-specific or document-level match_threshold
                display_threshold = (
                    field_config.get("match_threshold") or match_threshold
                )
                evaluation_method_value = (
                    f"Hungarian (threshold: {display_threshold:.2f})"
                )

            elif isinstance(expected_value, dict) or isinstance(actual_value, dict):
                # Nested objects - no threshold
                evaluation_method_value = "AggregateObject"

            else:
                # Infer method based on data types when no explicit comparator
                if isinstance(expected_value, bool) or isinstance(actual_value, bool):
                    # Booleans use exact matching - no threshold
                    evaluation_method_value = "Exact"
                elif isinstance(expected_value, (int, float)) or isinstance(
                    actual_value, (int, float)
                ):
                    # Numbers use tolerance-based comparison - no threshold display
                    evaluation_method_value = "NumericExact"
                elif isinstance(expected_value, str) or isinstance(actual_value, str):
                    # Strings use fuzzy matching - show threshold
                    display_threshold = (
                        field_specific_threshold
                        if field_specific_threshold is not None
                        else THRESHOLD_BASED_METHODS["Fuzzy"]
                    )
                    evaluation_method_value = (
                        f"Fuzzy (threshold: {display_threshold:.2f})"
                    )
                else:
                    # Safe default for any other types
                    evaluation_method_value = "Exact"

            # Create AttributeEvaluationResult
            attribute_result = AttributeEvaluationResult(
                name=field_name,
                expected=expected_value,
                actual=actual_value,
                matched=matched,
                score=score,
                reason=reason,
                evaluation_method=evaluation_method_value,
                evaluation_threshold=field_threshold,
                comparator_type=field_config.get("comparator"),
                confidence=confidence_info.get("confidence")
                if confidence_info
                else None,
                confidence_threshold=confidence_info.get("confidence_threshold")
                if confidence_info
                else None,
                weight=field_config.get("weight"),  # Stickler field weight
            )

            attribute_results.append(attribute_result)

        # Sort attribute results for consistent output
        attribute_results.sort(key=lambda ar: ar.name)

        # Calculate metrics
        metrics = calculate_metrics(tp=tp, fp=fp, fn=fn, tn=tn, fp1=fp1, fp2=fp2)

        # Add Stickler's weighted overall score to metrics
        weighted_score = stickler_result.get("overall_score", 0.0)
        metrics["weighted_overall_score"] = weighted_score

        return SectionEvaluationResult(
            section_id=section.section_id,
            document_class=section.classification,
            attributes=attribute_results,
            metrics=metrics,
        )

    def _remove_none_values(self, data: Any) -> Any:
        """
        Recursively remove None values from data structure.

        None in extraction results means the field wasn't extracted,
        so we remove it to let Pydantic use field defaults/optional behavior.

        Args:
            data: Data structure to clean

        Returns:
            Cleaned data structure without None values
        """
        if isinstance(data, dict):
            return {
                k: self._remove_none_values(v) for k, v in data.items() if v is not None
            }
        elif isinstance(data, list):
            return [self._remove_none_values(item) for item in data if item is not None]
        else:
            return data

    def _coerce_data_to_schema(
        self, data: Dict[str, Any], model_class: Type["StructuredModel"]
    ) -> Dict[str, Any]:
        """
        Coerce data values to match the Pydantic model's expected types.

        This prevents validation errors when baseline data has different types
        than the schema expects (e.g., float values when schema expects strings).

        Args:
            data: Dictionary of extraction data
            model_class: Pydantic model class with field type annotations

        Returns:
            Data dictionary with values coerced to match schema types
        """
        try:
            # Get the model's field information
            model_fields = (
                model_class.model_fields if hasattr(model_class, "model_fields") else {}
            )

            coerced_data = {}

            for key, value in data.items():
                if key not in model_fields:
                    # Field not in schema, keep as-is
                    coerced_data[key] = value
                    continue

                field_info = model_fields[key]

                # Get the field's annotation (expected type)
                field_annotation = field_info.annotation

                # Handle Optional types by extracting the inner type
                # Check if it's a Union type (which Optional creates)
                origin = getattr(field_annotation, "__origin__", None)
                if origin is Union:
                    # Get the non-None type from Union
                    args = getattr(field_annotation, "__args__", ())
                    field_annotation = next(
                        (arg for arg in args if arg is not type(None)), field_annotation
                    )

                # Coerce the value based on expected type
                coerced_data[key] = self._coerce_value_to_type(
                    value, field_annotation, key
                )

            return coerced_data

        except Exception as e:
            logger.warning(
                f"Error during type coercion: {str(e)}. Returning original data."
            )
            return data

    def _coerce_value_to_type(
        self, value: Any, expected_type: Any, field_name: str = ""
    ) -> Any:
        """
        Coerce a single value to match the expected type.

        Args:
            value: The value to coerce
            expected_type: The expected type annotation
            field_name: Name of the field (for logging)

        Returns:
            Coerced value matching expected type
        """
        if value is None:
            return None

        # Get the origin of the type (e.g., list, dict) for generic types
        origin = getattr(expected_type, "__origin__", None)

        try:
            # Handle string types
            if expected_type is str:
                if not isinstance(value, str):
                    return str(value)
                return value

            # Handle numeric types
            elif (
                expected_type in (int, float)
                or expected_type is int
                or expected_type is float
            ):
                if isinstance(value, str):
                    # Try to convert string to number
                    try:
                        return float(value) if expected_type is float else int(value)
                    except ValueError:
                        logger.warning(
                            f"Could not convert '{value}' to {expected_type} for field {field_name}"
                        )
                        return value
                return value

            # Handle boolean
            elif expected_type is bool:
                if isinstance(value, str):
                    return value.lower() in ("true", "1", "yes")
                return bool(value)

            # Handle list types
            elif origin is list:
                if not isinstance(value, list):
                    return value

                # Get the item type if specified
                args = getattr(expected_type, "__args__", ())
                if args:
                    item_type = args[0]
                    # Recursively coerce list items
                    return [
                        self._coerce_value_to_type(item, item_type, f"{field_name}[]")
                        for item in value
                    ]
                return value

            # Handle dict/object types - recursion needed for nested Pydantic models
            elif origin is dict or (hasattr(expected_type, "model_fields")):
                if not isinstance(value, dict):
                    return value

                # If it's a Pydantic model, recursively coerce
                if hasattr(expected_type, "model_fields"):
                    return self._coerce_data_to_schema(value, expected_type)
                return value

            # Default: return as-is
            else:
                return value

        except Exception as e:
            logger.warning(
                f"Error coercing value for field {field_name}: {str(e)}. Returning original value."
            )
            return value

    def evaluate_section(
        self,
        section: Section,
        expected_results: Dict[str, Any],
        actual_results: Dict[str, Any],
        confidence_scores: Optional[Dict[str, Any]] = None,
    ) -> SectionEvaluationResult:
        """
        Evaluate extraction results for a document section using Stickler.

        Args:
            section: Document section
            expected_results: Expected extraction results
            actual_results: Actual extraction results
            confidence_scores: Confidence scores for actual values from assessment

        Returns:
            Evaluation results for the section
        """
        class_name = section.classification
        logger.debug(
            f"Evaluating Section {section.section_id} - class: {class_name} using Stickler"
        )

        try:
            # Get Stickler model for this document class
            # Pass expected_results to enable auto-generation if needed
            ModelClass = self._get_stickler_model(
                class_name, expected_data=expected_results
            )

            # Clean data by removing None values (None means field not extracted)
            cleaned_expected = self._remove_none_values(expected_results)
            cleaned_actual = self._remove_none_values(actual_results)

            # Coerce data types to match schema expectations
            # This prevents Pydantic validation errors from type mismatches
            coerced_expected = self._coerce_data_to_schema(cleaned_expected, ModelClass)
            coerced_actual = self._coerce_data_to_schema(cleaned_actual, ModelClass)

            # Create model instances from coerced data
            # Stickler handles validation and structure
            expected_instance = ModelClass(**coerced_expected)
            actual_instance = ModelClass(**coerced_actual)

            # Compare using Stickler
            stickler_result = expected_instance.compare_with(actual_instance)

            logger.debug(
                f"Stickler comparison complete. Overall score: {stickler_result.get('overall_score', 'N/A'):.3f}"
            )

            # Transform Stickler result to IDP format
            section_result = self._transform_stickler_result(
                section,
                expected_instance,
                actual_instance,
                stickler_result,
                confidence_scores or {},
            )

            return section_result

        except ValueError as ve:
            # Schema configuration missing - this is a configuration issue
            logger.error(
                f"Configuration error for section {section.section_id}: {str(ve)}",
                exc_info=True,
            )
            failure_reason = (
                f"No schema configuration found for document class: {class_name}. "
                f"Cannot evaluate without configuration or baseline data. "
                f"Please add configuration for this document class or provide baseline data."
            )

            return SectionEvaluationResult(
                section_id=section.section_id,
                document_class=class_name,
                attributes=[
                    AttributeEvaluationResult(
                        name="__EVALUATION_FAILURE__",
                        expected=None,
                        actual=None,
                        matched=False,
                        score=0.0,
                        reason=failure_reason,
                        evaluation_method="N/A",
                    )
                ],
                metrics={
                    "precision": 0.0,
                    "recall": 0.0,
                    "f1_score": 0.0,
                    "accuracy": 0.0,
                    "false_alarm_rate": 0.0,
                    "false_discovery_rate": 0.0,
                    "weighted_overall_score": 0.0,
                    "evaluation_failed": True,
                },
            )

        except Exception as e:
            # Data validation error or other issues
            logger.error(
                f"Error evaluating section {section.section_id}: {str(e)}",
                exc_info=True,
            )

            # Check if it's a Pydantic validation error
            error_type = type(e).__name__
            if "ValidationError" in error_type:
                failure_reason = (
                    f"Data validation error: The baseline data format doesn't match the schema for document class '{class_name}'. "
                    f"This typically means the baseline data has different types than expected. "
                    f"Details: {str(e)}"
                )
            else:
                failure_reason = f"Unexpected error during evaluation: {str(e)}"

            return SectionEvaluationResult(
                section_id=section.section_id,
                document_class=class_name,
                attributes=[
                    AttributeEvaluationResult(
                        name="__EVALUATION_FAILURE__",
                        expected=None,
                        actual=None,
                        matched=False,
                        score=0.0,
                        reason=failure_reason,
                        evaluation_method="N/A",
                    )
                ],
                metrics={
                    "precision": 0.0,
                    "recall": 0.0,
                    "f1_score": 0.0,
                    "accuracy": 0.0,
                    "false_alarm_rate": 0.0,
                    "false_discovery_rate": 0.0,
                    "weighted_overall_score": 0.0,
                    "evaluation_failed": True,  # Flag to identify failed evaluations
                },
            )

    def _process_section(
        self, actual_section: Section, expected_section: Section
    ) -> Tuple[Optional[SectionEvaluationResult], Dict[str, int]]:
        """
        Process a single section for evaluation.

        Args:
            actual_section: Section with actual extraction results
            expected_section: Section with expected extraction results

        Returns:
            Tuple of (section_result, metrics_count)
        """
        # Load extraction results from S3
        actual_uri = actual_section.extraction_result_uri
        expected_uri = expected_section.extraction_result_uri

        if not actual_uri or not expected_uri:
            logger.warning(
                f"Missing extraction URI for section: {actual_section.section_id}"
            )
            return None, {}

        # Load data and confidence scores
        actual_results, confidence_scores = self._prepare_stickler_data(actual_uri)
        expected_results, _ = self._prepare_stickler_data(expected_uri)

        # Evaluate section using Stickler
        section_result = self.evaluate_section(
            section=actual_section,
            expected_results=expected_results,
            actual_results=actual_results,
            confidence_scores=confidence_scores,
        )

        # Extract metrics from section result
        metrics = {
            "tp": 0,
            "fp": 0,
            "fn": 0,
            "tn": 0,
            "fp1": 0,
            "fp2": 0,
        }

        # Check if evaluation failed for this section
        if section_result.metrics.get("evaluation_failed", False):
            # For failed evaluations, count based on expected data
            # If we have expected data, count as false negatives (expected but not evaluated)
            # This represents complete failure to evaluate
            if expected_results:
                num_expected_fields = len(expected_results)
                # Conservative approach: count each expected field as a false negative
                metrics["fn"] = num_expected_fields if num_expected_fields > 0 else 1
            else:
                # If no expected data, still count as at least 1 failure
                metrics["fn"] = 1

            logger.warning(
                f"Section {section_result.section_id} evaluation failed. "
                f"Counted {metrics['fn']} false negatives for document-level metrics."
            )
            return section_result, metrics

        # Normal processing: Count matches and mismatches in the attributes
        for attr in section_result.attributes:
            # Check if both are None/Empty
            is_expected_empty = attr.expected is None or (
                isinstance(attr.expected, str) and not str(attr.expected).strip()
            )
            is_actual_empty = attr.actual is None or (
                isinstance(attr.actual, str) and not str(attr.actual).strip()
            )

            if is_expected_empty and is_actual_empty:
                metrics["tn"] += 1
            elif attr.matched:
                metrics["tp"] += 1
            else:
                # Handle different error cases
                if is_expected_empty:
                    metrics["fp"] += 1
                    metrics["fp1"] += 1
                elif is_actual_empty:
                    metrics["fn"] += 1
                else:
                    metrics["fp"] += 1
                    metrics["fp2"] += 1

        return section_result, metrics

    def evaluate_document(
        self,
        actual_document: Document,
        expected_document: Document,
        store_results: bool = True,
    ) -> Document:
        """
        Evaluate extraction results for an entire document using Stickler.

        This method maintains the same API as the legacy implementation but uses
        Stickler for comparison logic.

        Args:
            actual_document: Document with actual extraction results
            expected_document: Document with expected extraction results
            store_results: Whether to store results in S3 (default: True)

        Returns:
            Updated actual document with evaluation results
        """
        try:
            # Start timing
            start_time = time.time()

            # Calculate document split classification metrics FIRST
            doc_split_metrics_obj = None
            try:
                logger.info("Calculating document split classification metrics...")
                doc_split_calculator = DocSplitClassificationMetrics()
                doc_split_calculator.load_sections(
                    ground_truth_sections=expected_document.sections,
                    predicted_sections=actual_document.sections,
                )

                # Calculate all metrics
                doc_split_results = doc_split_calculator.calculate_all_metrics()

                # Create DocSplitMetrics object
                page_level = doc_split_results["page_level_accuracy"]
                split_no_order = doc_split_results["split_accuracy_without_order"]
                split_with_order = doc_split_results["split_accuracy_with_order"]

                doc_split_metrics_obj = DocSplitMetrics(
                    page_level_accuracy=page_level["accuracy"],
                    split_accuracy_without_order=split_no_order["accuracy"],
                    split_accuracy_with_order=split_with_order["accuracy"],
                    total_pages=page_level["total_pages"],
                    total_splits=split_no_order["total_sections"],
                    correctly_classified_pages=page_level["correct_pages"],
                    correctly_split_without_order=split_no_order["correct_sections"],
                    correctly_split_with_order=split_with_order["correct_sections"],
                    page_details=page_level["page_details"],
                    section_details_without_order=split_no_order["section_details"],
                    section_details_with_order=split_with_order["section_details"],
                    predicted_sections=doc_split_calculator.sections_pred,  # Add predicted sections for unmatched display
                    errors=doc_split_results.get("errors", []),
                )

                logger.info(
                    f"Doc split metrics calculated - Page accuracy: {page_level['accuracy']:.3f}, "
                    f"Split accuracy (no order): {split_no_order['accuracy']:.3f}, "
                    f"Split accuracy (with order): {split_with_order['accuracy']:.3f}"
                )

            except Exception as e:
                logger.error(
                    f"Error calculating doc split metrics: {str(e)}", exc_info=True
                )
                actual_document.errors.append(f"Doc split metrics error: {str(e)}")

            # Track overall metrics for extraction evaluation
            total_tp = total_fp = total_fn = total_tn = total_fp1 = total_fp2 = 0

            # Create a list of section pairs to evaluate
            section_pairs = []
            for actual_section in actual_document.sections:
                section_id = actual_section.section_id

                # Find corresponding section in expected document
                expected_section = next(
                    (
                        s
                        for s in expected_document.sections
                        if s.section_id == section_id
                    ),
                    None,
                )

                if not expected_section:
                    logger.warning(
                        f"No matching section found for section_id: {section_id}"
                    )
                    continue

                section_pairs.append((actual_section, expected_section))

            section_results = []

            # Track weighted scores for document-level aggregation
            total_weighted_score = 0.0
            weighted_section_count = 0

            # Process sections in parallel using ThreadPoolExecutor
            with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                # Submit all section evaluations to the executor
                future_to_section = {
                    executor.submit(
                        self._process_section, actual_section, expected_section
                    ): actual_section.section_id
                    for actual_section, expected_section in section_pairs
                }

                # Collect results as they complete
                for future in concurrent.futures.as_completed(future_to_section):
                    section_id = future_to_section[future]
                    try:
                        result, metrics = future.result()
                        if result is None:
                            logger.warning(
                                f"Section {section_id} evaluation returned no result"
                            )
                            continue

                        # Add to section results
                        section_results.append(result)

                        # Update overall metrics
                        total_tp += metrics["tp"]
                        total_fp += metrics["fp"]
                        total_fn += metrics["fn"]
                        total_tn += metrics["tn"]
                        total_fp1 += metrics["fp1"]
                        total_fp2 += metrics["fp2"]

                        # Track weighted score from section
                        section_weighted_score = result.metrics.get(
                            "weighted_overall_score", 0.0
                        )
                        if section_weighted_score > 0:
                            total_weighted_score += section_weighted_score
                            weighted_section_count += 1

                    except Exception as e:
                        logger.error(
                            f"Error evaluating section {section_id}: {traceback.format_exc()}"
                        )
                        actual_document.errors.append(
                            f"Error evaluating section {section_id}: {str(e)}"
                        )

            # Sort section results by section_id for consistent output
            section_results.sort(key=lambda x: x.section_id)

            # Calculate overall metrics
            overall_metrics = calculate_metrics(
                tp=total_tp,
                fp=total_fp,
                fn=total_fn,
                tn=total_tn,
                fp1=total_fp1,
                fp2=total_fp2,
            )

            # Calculate document-level weighted overall score (average of section scores)
            if weighted_section_count > 0:
                document_weighted_score = total_weighted_score / weighted_section_count
            else:
                document_weighted_score = 0.0
            overall_metrics["weighted_overall_score"] = document_weighted_score

            execution_time = time.time() - start_time

            # Validate required document fields
            if not actual_document.id:
                raise ValueError("Document ID is required for evaluation")
            if not actual_document.output_bucket:
                raise ValueError("Output bucket is required for storing results")
            if not actual_document.input_key:
                raise ValueError("Input key is required for storing results")

            # Create evaluation result with doc split metrics
            evaluation_result = DocumentEvaluationResult(
                document_id=actual_document.id,
                section_results=section_results,
                overall_metrics=overall_metrics,
                execution_time=execution_time,
                doc_split_metrics=doc_split_metrics_obj,
            )

            # Store results if requested
            if store_results:
                # Generate output path
                output_bucket = actual_document.output_bucket
                output_key = f"{actual_document.input_key}/evaluation/results.json"

                # Store evaluation results in S3
                result_dict = evaluation_result.to_dict()
                # Convert numpy types to native Python types for JSON serialization
                result_dict = _convert_numpy_types(result_dict)
                s3.write_content(
                    content=result_dict,
                    bucket=output_bucket,
                    key=output_key,
                    content_type="application/json",
                )

                # Generate Markdown report
                markdown_report = evaluation_result.to_markdown()
                report_key = f"{actual_document.input_key}/evaluation/report.md"
                s3.write_content(
                    content=markdown_report,
                    bucket=output_bucket,
                    key=report_key,
                    content_type="text/markdown",
                )

                # Update document with evaluation report and results URIs
                actual_document.evaluation_report_uri = (
                    f"s3://{output_bucket}/{report_key}"
                )
                actual_document.evaluation_results_uri = (
                    f"s3://{output_bucket}/{output_key}"
                )
                actual_document.status = Status.COMPLETED

                logger.info(
                    f"Evaluation complete for document {actual_document.id} in {execution_time:.2f} seconds"
                )

            # Attach evaluation result to document for immediate use
            actual_document.evaluation_result = evaluation_result

            return actual_document

        except Exception as e:
            logger.error(f"Error evaluating document: {traceback.format_exc()}")
            actual_document.errors.append(f"Evaluation error: {str(e)}")
            return actual_document
