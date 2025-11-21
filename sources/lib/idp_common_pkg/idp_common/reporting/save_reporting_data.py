# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Module for saving document data to reporting storage.
"""

import datetime
import io
import json
import logging
import re
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import boto3
import pyarrow as pa
import pyarrow.parquet as pq

from idp_common.models import Document
from idp_common.s3 import get_json_content

# Configure logging
logger = logging.getLogger(__name__)


class SaveReportingData:
    """
    Class for saving document data to reporting storage.

    This class provides methods to save different types of document data
    to a reporting bucket in Parquet format for analytics.
    """

    def __init__(self, reporting_bucket: str):
        """
        Initialize the SaveReportingData class.

        Args:
            reporting_bucket: S3 bucket name for reporting data
        """
        self.reporting_bucket = reporting_bucket
        self.s3_client = boto3.client("s3")

    def _serialize_value(self, value: Any) -> str:
        """
        Serialize complex values for Parquet storage as strings.

        Args:
            value: The value to serialize

        Returns:
            Serialized value as string, or None if input is None
        """
        if value is None:
            return None
        elif isinstance(value, str):
            return value
        elif isinstance(value, (int, float, bool)):
            # Convert numeric/boolean values to strings
            return str(value)
        elif isinstance(value, (list, dict)):
            # Convert complex types to JSON strings
            return json.dumps(value)
        else:
            # Convert other types to string
            return str(value)

    def _save_records_as_parquet(
        self, records: List[Dict], s3_key: str, schema: pa.Schema
    ) -> None:
        """
        Save a list of records as a Parquet file to S3 with explicit schema.

        Args:
            records: List of dictionaries to save
            s3_key: S3 key path
            schema: PyArrow schema for the table
        """
        if not records:
            logger.warning("No records to save")
            return

        # Create PyArrow table from records with explicit schema
        table = pa.Table.from_pylist(records, schema=schema)

        # Create in-memory buffer
        buffer = io.BytesIO()

        # Write parquet data to buffer
        pq.write_table(table, buffer, compression="snappy")

        # Upload to S3
        buffer.seek(0)
        self.s3_client.put_object(
            Bucket=self.reporting_bucket,
            Key=s3_key,
            Body=buffer.getvalue(),
            ContentType="application/octet-stream",
        )
        logger.info(
            f"Saved {len(records)} records as Parquet to s3://{self.reporting_bucket}/{s3_key}"
        )

    def _parse_s3_uri(self, uri: str) -> tuple:
        """
        Parse an S3 URI into bucket and key.

        Args:
            uri: S3 URI in the format s3://bucket/key

        Returns:
            Tuple of (bucket, key)
        """
        parsed = urlparse(uri)
        if parsed.scheme != "s3":
            raise ValueError(f"Not an S3 URI: {uri}")

        bucket = parsed.netloc
        # Remove leading slash from key
        key = parsed.path.lstrip("/")

        return bucket, key

    def _infer_pyarrow_type(self, value: Any) -> pa.DataType:
        """
        Infer PyArrow data type from a Python value.

        Args:
            value: The value to infer type from

        Returns:
            PyArrow data type
        """
        if value is None:
            return pa.string()  # Default to string for null values
        elif isinstance(value, bool):
            return pa.bool_()
        elif isinstance(value, int):
            return pa.int64()
        elif isinstance(value, float):
            return pa.float64()
        elif isinstance(value, str):
            return pa.string()
        elif isinstance(value, (list, dict)):
            return pa.string()  # Store complex types as JSON strings
        else:
            return pa.string()  # Default to string for unknown types

    def _convert_value_to_string(self, value: Any) -> Optional[str]:
        """
        Convert any value to string, handling special cases for robust type compatibility.

        Args:
            value: The value to convert

        Returns:
            String representation of the value, or None if input is None
        """
        if value is None:
            return None
        elif isinstance(value, bytes):
            # Handle binary data
            try:
                return value.decode("utf-8")
            except UnicodeDecodeError:
                # If can't decode, convert to hex string
                return value.hex()
        elif isinstance(value, (list, dict)):
            return json.dumps(value)
        elif isinstance(value, datetime.datetime):
            return value.isoformat()
        elif isinstance(value, (int, float, bool)):
            return str(value)
        else:
            return str(value)

    def _flatten_json_data(
        self, data: Dict[str, Any], prefix: str = ""
    ) -> Dict[str, Any]:
        """
        Flatten nested JSON data with dot notation and convert all values to strings
        for robust type compatibility.

        Args:
            data: The JSON data to flatten
            prefix: Prefix for nested keys

        Returns:
            Flattened dictionary with all values converted to strings
        """
        flattened = {}

        for key, value in data.items():
            new_key = f"{prefix}.{key}" if prefix else key

            if isinstance(value, dict) and value:
                # Recursively flatten nested dictionaries
                flattened.update(self._flatten_json_data(value, new_key))
            elif isinstance(value, list):
                # Convert lists to JSON strings
                flattened[new_key] = json.dumps(value) if value else None
            else:
                # Convert all values to strings for type consistency
                flattened[new_key] = self._convert_value_to_string(value)

        return flattened

    def _create_dynamic_schema(self, records: List[Dict[str, Any]]) -> pa.Schema:
        """
        Create a PyArrow schema dynamically from a list of records.
        Uses conservative typing - all fields default to string unless whitelisted.
        This prevents Athena type compatibility issues.

        Args:
            records: List of dictionaries to analyze

        Returns:
            PyArrow schema with conservative string typing
        """
        # Define fields that should maintain specific types
        TIMESTAMP_FIELDS = {
            "timestamp",
            "evaluation_date",
        }

        if not records:
            # Return a minimal schema with just section_id
            return pa.schema([("section_id", pa.string())])

        # Collect all unique field names
        all_fields = set()
        for record in records:
            all_fields.update(record.keys())

        # Create schema with conservative typing
        schema_fields = []
        for field_name in sorted(all_fields):  # Sort for consistent ordering
            if field_name in TIMESTAMP_FIELDS:
                # Keep timestamps as timestamps for proper time-based queries
                pa_type = pa.timestamp("ms")
            else:
                # Default everything else to string to prevent type conflicts
                pa_type = pa.string()

            schema_fields.append((field_name, pa_type))

        return pa.schema(schema_fields)

    def _sanitize_records_for_schema(
        self, records: List[Dict[str, Any]], schema: pa.Schema
    ) -> List[Dict[str, Any]]:
        """
        Sanitize records to ensure they conform to the schema and handle type compatibility issues.

        Args:
            records: List of record dictionaries
            schema: PyArrow schema to conform to

        Returns:
            List of sanitized records
        """
        sanitized_records = []

        for record in records:
            sanitized_record = {}

            # Process each field in the schema
            for field in schema:
                field_name = field.name
                value = record.get(field_name)

                if value is None:
                    sanitized_record[field_name] = None
                elif field.type == pa.string():
                    # Convert all values to strings for string fields
                    sanitized_record[field_name] = self._convert_value_to_string(value)
                elif field.type == pa.timestamp("ms"):
                    # Handle timestamp fields
                    if isinstance(value, datetime.datetime):
                        sanitized_record[field_name] = value
                    else:
                        # Try to parse string timestamps
                        try:
                            if isinstance(value, str):
                                sanitized_record[field_name] = (
                                    datetime.datetime.fromisoformat(
                                        value.replace("Z", "+00:00")
                                    )
                                )
                            else:
                                sanitized_record[field_name] = None
                        except (ValueError, TypeError):
                            sanitized_record[field_name] = None
                else:
                    # For any other types, convert to string as fallback
                    sanitized_record[field_name] = self._convert_value_to_string(value)

            # Add any fields from the record that aren't in the schema (shouldn't happen with dynamic schema)
            for field_name, value in record.items():
                if field_name not in sanitized_record:
                    sanitized_record[field_name] = self._convert_value_to_string(value)

            sanitized_records.append(sanitized_record)

        return sanitized_records

    def save(self, document: Document, data_to_save: List[str]) -> List[Dict[str, Any]]:
        """
        Save document data based on the data_to_save list.

        Args:
            document: Document object containing data to save
            data_to_save: List of data types to save

        Returns:
            List of results from each save operation
        """
        results = []

        # Process each data type based on data_to_save
        if "evaluation_results" in data_to_save:
            logger.info("Processing evaluation results")
            result = self.save_evaluation_results(document)
            if result:
                results.append(result)

        if "metering" in data_to_save:
            logger.info("Processing metering data")
            result = self.save_metering_data(document)
            if result:
                results.append(result)

        if "sections" in data_to_save:
            logger.info("Processing document sections")
            result = self.save_document_sections(document)
            if result:
                results.append(result)

        # Add more data types here as needed
        # if 'document_metadata' in data_to_save:
        #     logger.info("Processing document metadata")
        #     result = self.save_document_metadata(document)
        #     if result:
        #         results.append(result)

        return results

    def save_evaluation_results(self, document: Document) -> Optional[Dict[str, Any]]:
        """
        Save evaluation results for a document to the reporting bucket.

        Args:
            document: Document object containing evaluation results URI

        Returns:
            Dict with status and message, or None if no evaluation results
        """
        if not document.evaluation_results_uri:
            warning_msg = (
                f"No evaluation_results_uri available for document {document.id}"
            )
            logger.warning(warning_msg)
            return None

        try:
            # Load evaluation results from S3
            logger.info(
                f"Loading evaluation results from {document.evaluation_results_uri}"
            )
            eval_result = get_json_content(document.evaluation_results_uri)

            if not eval_result:
                warning_msg = f"Empty evaluation results for document {document.id}"
                logger.warning(warning_msg)
                return None

        except Exception as e:
            error_msg = f"Error loading evaluation results from {document.evaluation_results_uri}: {str(e)}"
            logger.error(error_msg)
            return {"statusCode": 500, "body": error_msg}

        # Define schemas specific to evaluation results
        document_schema = pa.schema(
            [
                ("document_id", pa.string()),
                ("input_key", pa.string()),
                ("evaluation_date", pa.timestamp("ms")),
                ("accuracy", pa.float64()),
                ("precision", pa.float64()),
                ("recall", pa.float64()),
                ("f1_score", pa.float64()),
                ("false_alarm_rate", pa.float64()),
                ("false_discovery_rate", pa.float64()),
                ("execution_time", pa.float64()),
            ]
        )

        section_schema = pa.schema(
            [
                ("document_id", pa.string()),
                ("section_id", pa.string()),
                ("section_type", pa.string()),
                ("accuracy", pa.float64()),
                ("precision", pa.float64()),
                ("recall", pa.float64()),
                ("f1_score", pa.float64()),
                ("false_alarm_rate", pa.float64()),
                ("false_discovery_rate", pa.float64()),
                ("evaluation_date", pa.timestamp("ms")),
            ]
        )

        attribute_schema = pa.schema(
            [
                ("document_id", pa.string()),
                ("section_id", pa.string()),
                ("section_type", pa.string()),
                ("attribute_name", pa.string()),
                ("expected", pa.string()),
                ("actual", pa.string()),
                ("matched", pa.bool_()),
                ("score", pa.float64()),
                ("reason", pa.string()),
                ("evaluation_method", pa.string()),
                ("confidence", pa.string()),
                ("confidence_threshold", pa.string()),
                ("evaluation_date", pa.timestamp("ms")),
            ]
        )

        # Use document.initial_event_time if available, otherwise use current time
        if document.initial_event_time:
            try:
                # Try to parse the initial_event_time string into a datetime object
                doc_time = datetime.datetime.fromisoformat(
                    document.initial_event_time.replace("Z", "+00:00")
                )
                evaluation_date = doc_time
                date_partition = doc_time.strftime("%Y-%m-%d")
                logger.info(
                    f"Using document initial_event_time: {document.initial_event_time} for partitioning"
                )
            except (ValueError, TypeError) as e:
                logger.warning(
                    f"Could not parse document.initial_event_time: {document.initial_event_time}, using current time instead. Error: {str(e)}"
                )
                evaluation_date = datetime.datetime.now()
                date_partition = evaluation_date.strftime("%Y-%m-%d")
        else:
            logger.warning(
                "Document initial_event_time not available, using current time instead"
            )
            evaluation_date = datetime.datetime.now()
            date_partition = evaluation_date.strftime("%Y-%m-%d")

        # Escape document ID by replacing slashes with underscores
        document_id = document.id
        escaped_doc_id = re.sub(r"[/\\]", "_", document_id)

        # Create timestamp string for unique filenames (to avoid overwrites if same doc processed multiple times)
        timestamp_str = evaluation_date.strftime("%Y%m%d_%H%M%S_%f")[
            :-3
        ]  # Include milliseconds

        # 1. Document level metrics
        document_record = {
            "document_id": document_id,
            "input_key": document.input_key,
            "evaluation_date": evaluation_date,  # Use document's initial_event_time
            "accuracy": eval_result.get("overall_metrics", {}).get("accuracy", 0.0),
            "precision": eval_result.get("overall_metrics", {}).get("precision", 0.0),
            "recall": eval_result.get("overall_metrics", {}).get("recall", 0.0),
            "f1_score": eval_result.get("overall_metrics", {}).get("f1_score", 0.0),
            "false_alarm_rate": eval_result.get("overall_metrics", {}).get(
                "false_alarm_rate", 0.0
            ),
            "false_discovery_rate": eval_result.get("overall_metrics", {}).get(
                "false_discovery_rate", 0.0
            ),
            "execution_time": eval_result.get("execution_time", 0.0),
        }

        # Save document metrics in Parquet format
        doc_key = f"evaluation_metrics/document_metrics/date={date_partition}/{escaped_doc_id}_{timestamp_str}_results.parquet"
        self._save_records_as_parquet([document_record], doc_key, document_schema)

        # 2. Section level metrics
        section_records = []
        # 3. Attribute level records
        attribute_records = []

        # Log section results count
        section_results = eval_result.get("section_results", [])
        logger.info(f"Processing {len(section_results)} section results")

        for section_result in section_results:
            section_id = section_result.get("section_id")
            section_type = section_result.get("document_class", "")

            # Section record
            section_record = {
                "document_id": document_id,
                "section_id": section_id,
                "section_type": section_type,
                "accuracy": section_result.get("metrics", {}).get("accuracy", 0.0),
                "precision": section_result.get("metrics", {}).get("precision", 0.0),
                "recall": section_result.get("metrics", {}).get("recall", 0.0),
                "f1_score": section_result.get("metrics", {}).get("f1_score", 0.0),
                "false_alarm_rate": section_result.get("metrics", {}).get(
                    "false_alarm_rate", 0.0
                ),
                "false_discovery_rate": section_result.get("metrics", {}).get(
                    "false_discovery_rate", 0.0
                ),
                "evaluation_date": evaluation_date,  # Use document's initial_event_time
            }
            section_records.append(section_record)

            # Log section metrics
            logger.debug(
                f"Added section record for section_id={section_id}, section_type={section_type}"
            )

            # Attribute records
            attributes = section_result.get("attributes", [])
            logger.debug(f"Section {section_id} has {len(attributes)} attributes")

            for attr in attributes:
                attribute_record = {
                    "document_id": document_id,
                    "section_id": section_id,
                    "section_type": section_type,
                    "attribute_name": self._serialize_value(attr.get("name", "")),
                    "expected": self._serialize_value(attr.get("expected", "")),
                    "actual": self._serialize_value(attr.get("actual", "")),
                    "matched": attr.get("matched", False),
                    "score": attr.get("score", 0.0),
                    "reason": self._serialize_value(attr.get("reason", "")),
                    "evaluation_method": self._serialize_value(
                        attr.get("evaluation_method", "")
                    ),
                    "confidence": self._serialize_value(attr.get("confidence")),
                    "confidence_threshold": self._serialize_value(
                        attr.get("confidence_threshold")
                    ),
                    "evaluation_date": evaluation_date,  # Use document's initial_event_time
                }
                attribute_records.append(attribute_record)
                logger.debug(
                    f"Added attribute record for attribute_name={attr.get('name', '')}"
                )

        # Log counts
        logger.info(
            f"Collected {len(section_records)} section records and {len(attribute_records)} attribute records"
        )

        # Save section metrics in Parquet format
        if section_records:
            section_key = f"evaluation_metrics/section_metrics/date={date_partition}/{escaped_doc_id}_{timestamp_str}_results.parquet"
            self._save_records_as_parquet(section_records, section_key, section_schema)
        else:
            logger.warning("No section records to save")

        # Save attribute metrics in Parquet format
        if attribute_records:
            attr_key = f"evaluation_metrics/attribute_metrics/date={date_partition}/{escaped_doc_id}_{timestamp_str}_results.parquet"
            self._save_records_as_parquet(attribute_records, attr_key, attribute_schema)
        else:
            logger.warning("No attribute records to save")

        logger.info(
            f"Completed saving evaluation results to s3://{self.reporting_bucket}"
        )

        return {
            "statusCode": 200,
            "body": "Successfully saved evaluation results to reporting bucket",
        }

    def save_metering_data(self, document: Document) -> Optional[Dict[str, Any]]:
        """
        Save metering data for a document to the reporting bucket.

        Args:
            document: Document object containing metering data

        Returns:
            Dict with status and message, or None if no metering data
        """
        if not document.metering:
            warning_msg = f"No metering data to save for document {document.id}"
            logger.warning(warning_msg)
            return None

        # Define schema for metering data
        metering_schema = pa.schema(
            [
                ("document_id", pa.string()),
                ("context", pa.string()),
                ("service_api", pa.string()),
                ("unit", pa.string()),
                ("value", pa.float64()),
                ("number_of_pages", pa.int32()),
                ("timestamp", pa.timestamp("ms")),
            ]
        )

        # Use document.initial_event_time if available, otherwise use current time
        if document.initial_event_time:
            try:
                # Try to parse the initial_event_time string into a datetime object
                doc_time = datetime.datetime.fromisoformat(
                    document.initial_event_time.replace("Z", "+00:00")
                )
                timestamp = doc_time
                date_partition = doc_time.strftime("%Y-%m-%d")
                logger.info(
                    f"Using document initial_event_time: {document.initial_event_time} for partitioning"
                )
            except (ValueError, TypeError) as e:
                logger.warning(
                    f"Could not parse document.initial_event_time: {document.initial_event_time}, using current time instead. Error: {str(e)}"
                )
                timestamp = datetime.datetime.now()
                date_partition = timestamp.strftime("%Y-%m-%d")
        else:
            logger.warning(
                "Document initial_event_time not available, using current time instead"
            )
            timestamp = datetime.datetime.now()
            date_partition = timestamp.strftime("%Y-%m-%d")

        # Escape document ID by replacing slashes with underscores
        document_id = document.id
        escaped_doc_id = re.sub(r"[/\\]", "_", document_id)

        # Create timestamp string for unique filenames (to avoid overwrites if same doc processed multiple times)
        timestamp_str = timestamp.strftime("%Y%m%d_%H%M%S_%f")[
            :-3
        ]  # Include milliseconds

        # Process metering data
        metering_records = []

        for key, metrics in document.metering.items():
            # Split the key into context and service_api
            parts = key.split("/", 1)
            if len(parts) == 2:
                context, service_api = parts
            else:
                context = ""
                service_api = key

            # Process each unit and value
            for unit, value in metrics.items():
                # Convert value to float if possible
                try:
                    float_value = float(value)
                except (ValueError, TypeError):
                    # If conversion fails, use 1.0 as default
                    float_value = 1.0
                    logger.warning(
                        f"Could not convert metering value to float: {value}, using 1.0 instead"
                    )

                # Get the number of pages from the document
                num_pages = document.num_pages if document.num_pages is not None else 0

                metering_record = {
                    "document_id": document_id,
                    "context": context,
                    "service_api": service_api,
                    "unit": unit,
                    "value": float_value,
                    "number_of_pages": num_pages,
                    "timestamp": timestamp,
                }
                metering_records.append(metering_record)

        # Save metering data in Parquet format
        if metering_records:
            metering_key = f"metering/date={date_partition}/{escaped_doc_id}_{timestamp_str}_results.parquet"
            self._save_records_as_parquet(
                metering_records, metering_key, metering_schema
            )
            logger.info(f"Saved {len(metering_records)} metering records")
        else:
            logger.warning("No metering records to save")

        return {
            "statusCode": 200,
            "body": "Successfully saved metering data to reporting bucket",
        }

    def save_document_sections(self, document: Document) -> Optional[Dict[str, Any]]:
        """
        Save document sections data to the reporting bucket.

        This method processes each section in the document, loads the extraction
        results from S3, and saves them as Parquet files with dynamic schema
        inference and the specified partition structure.

        Args:
            document: Document object containing sections with extraction results

        Returns:
            Dict with status and message, or None if no sections to process
        """
        if not document.sections:
            warning_msg = f"No sections to save for document {document.id}"
            logger.warning(warning_msg)
            return None

        # Use document.initial_event_time if available, otherwise use current time
        if document.initial_event_time:
            try:
                # Try to parse the initial_event_time string into a datetime object
                doc_time = datetime.datetime.fromisoformat(
                    document.initial_event_time.replace("Z", "+00:00")
                )
                timestamp = doc_time
                date_partition = doc_time.strftime("%Y-%m-%d")
                logger.info(
                    f"Using document initial_event_time: {document.initial_event_time} for partitioning"
                )
            except (ValueError, TypeError) as e:
                logger.warning(
                    f"Could not parse document.initial_event_time: {document.initial_event_time}, using current time instead. Error: {str(e)}"
                )
                current_time = datetime.datetime.now()
                timestamp = current_time
                date_partition = current_time.strftime("%Y-%m-%d")
        else:
            logger.warning(
                "Document initial_event_time not available, using current time instead"
            )
            current_time = datetime.datetime.now()
            timestamp = current_time
            date_partition = current_time.strftime("%Y-%m-%d")

        # Escape document ID by replacing slashes with underscores
        document_id = document.id
        escaped_doc_id = re.sub(r"[/\\]", "_", document_id)

        sections_processed = 0
        sections_with_errors = 0
        total_records_saved = 0

        logger.info(
            f"Processing {len(document.sections)} sections for document {document_id}"
        )

        for section in document.sections:
            try:
                # Skip sections without extraction results
                if not section.extraction_result_uri:
                    logger.warning(
                        f"Section {section.section_id} has no extraction_result_uri, skipping"
                    )
                    continue

                logger.info(
                    f"Processing section {section.section_id} with classification '{section.classification}'"
                )

                # Load extraction results from S3
                try:
                    extraction_data = get_json_content(section.extraction_result_uri)
                    if not extraction_data:
                        logger.warning(
                            f"Empty extraction results for section {section.section_id}, skipping"
                        )
                        continue
                except Exception as e:
                    logger.error(
                        f"Error loading extraction results from {section.extraction_result_uri}: {str(e)}"
                    )
                    sections_with_errors += 1
                    continue

                # Prepare records for this section
                section_records = []

                # Handle different data structures
                if isinstance(extraction_data, dict):
                    # Flatten the JSON data
                    flattened_data = self._flatten_json_data(extraction_data)

                    # Add section metadata
                    flattened_data["section_id"] = section.section_id
                    flattened_data["document_id"] = document_id
                    flattened_data["section_classification"] = section.classification
                    flattened_data["section_confidence"] = section.confidence
                    flattened_data["timestamp"] = timestamp

                    section_records.append(flattened_data)

                elif isinstance(extraction_data, list):
                    # Handle list of records
                    for i, item in enumerate(extraction_data):
                        if isinstance(item, dict):
                            flattened_item = self._flatten_json_data(item)
                        else:
                            flattened_item = {"value": str(item)}

                        # Add section metadata and record index
                        flattened_item["section_id"] = section.section_id
                        flattened_item["document_id"] = document_id
                        flattened_item["section_classification"] = (
                            section.classification
                        )
                        flattened_item["section_confidence"] = section.confidence
                        flattened_item["record_index"] = i

                        section_records.append(flattened_item)
                else:
                    # Handle primitive types
                    record = {
                        "section_id": section.section_id,
                        "document_id": document_id,
                        "section_classification": section.classification,
                        "section_confidence": section.confidence,
                        "value": str(extraction_data),
                    }
                    section_records.append(record)

                if not section_records:
                    logger.warning(
                        f"No records to save for section {section.section_id}"
                    )
                    continue

                # Create dynamic schema for this section's data
                schema = self._create_dynamic_schema(section_records)

                # Sanitize all records to ensure robust type compatibility
                section_records = self._sanitize_records_for_schema(
                    section_records, schema
                )

                # Create S3 key with separate tables for each section type
                # document_sections/{section_type}/date={date}/{escaped_doc_id}_section_{section_id}.parquet
                section_type = (
                    section.classification if section.classification else "unknown"
                )
                # Escape section_type to make it filesystem-safe
                escaped_section_type = re.sub(r"[/\\:*?\"<>|]", "_", section_type)

                s3_key = (
                    f"document_sections/"
                    f"{escaped_section_type}/"
                    f"date={date_partition}/"
                    f"{escaped_doc_id}_section_{section.section_id}.parquet"
                )

                # Save the section data as Parquet
                self._save_records_as_parquet(section_records, s3_key, schema)

                sections_processed += 1
                total_records_saved += len(section_records)

                logger.info(
                    f"Saved {len(section_records)} records for section {section.section_id} "
                    f"to s3://{self.reporting_bucket}/{s3_key}"
                )

            except Exception as e:
                logger.error(f"Error processing section {section.section_id}: {str(e)}")
                sections_with_errors += 1
                continue

        # Log summary
        logger.info(
            f"Document sections processing complete for {document_id}: "
            f"{sections_processed} sections processed successfully, "
            f"{sections_with_errors} sections had errors, "
            f"{total_records_saved} total records saved"
        )

        if sections_processed == 0:
            return {
                "statusCode": 200,
                "body": f"No sections with extraction results found for document {document_id}",
            }

        return {
            "statusCode": 200,
            "body": f"Successfully saved {sections_processed} document sections "
            f"with {total_records_saved} total records to reporting bucket",
        }
