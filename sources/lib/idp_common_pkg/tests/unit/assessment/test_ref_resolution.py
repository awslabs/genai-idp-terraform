# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for JSON Schema $ref resolution in GranularAssessmentService.

This test file specifically tests that properties using $ref references are
correctly classified by type (object vs array vs simple) in the granular
assessment service.

Issue: Properties using $ref were being classified as "simple" types because
the code checked prop_schema.get(SCHEMA_TYPE) which returns None for $ref
properties, causing them to fall through to the simple_props list.
"""

# ruff: noqa: E402, I001
import sys
from unittest.mock import MagicMock

# Mock PIL before importing modules that depend on it
sys.modules["PIL"] = MagicMock()
sys.modules["PIL.Image"] = MagicMock()

import pytest

from idp_common.assessment.granular_service import GranularAssessmentService


@pytest.mark.unit
class TestRefResolution:
    """Tests for $ref resolution in GranularAssessmentService."""

    @pytest.fixture
    def discharge_summary_schema(self):
        """
        Fixture providing a JSON Schema with $ref references.
        This mirrors the real DischargeSummary schema structure.
        """
        return {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": "DischargeSummary",
            "x-aws-idp-document-type": "DischargeSummary",
            "type": "object",
            "description": "Summary of patient's hospital discharge",
            "$defs": {
                "PatientInformationDischargeDef": {
                    "type": "object",
                    "description": "Information about the patient",
                    "properties": {
                        "Patient": {
                            "type": "string",
                            "description": "Name of the patient",
                        },
                        "Providers-Pt-ID": {
                            "type": "string",
                            "description": "Provider's patient ID",
                        },
                        "Patient-Gender": {
                            "type": "string",
                            "description": "Gender of the patient",
                        },
                    },
                },
                "VisitDetailsDef": {
                    "type": "object",
                    "description": "Details about the patient's visit",
                    "properties": {
                        "Admitted": {
                            "type": "string",
                            "format": "date",
                            "description": "Date of admission",
                        },
                        "Discharged": {
                            "type": "string",
                            "format": "date",
                            "description": "Date of discharge",
                        },
                    },
                },
                "HeaderDef": {
                    "type": "object",
                    "description": "Header information",
                    "properties": {
                        "HospitalName": {
                            "type": "string",
                            "description": "Name of the hospital",
                        },
                        "DocumentTitle": {
                            "type": "string",
                            "description": "Title of the document",
                        },
                    },
                },
            },
            "properties": {
                "PatientInformation": {
                    "$ref": "#/$defs/PatientInformationDischargeDef",
                    "description": "Information about the patient",
                },
                "VisitDetails": {
                    "$ref": "#/$defs/VisitDetailsDef",
                    "description": "Details about the patient's visit",
                },
                "Header": {
                    "$ref": "#/$defs/HeaderDef",
                    "description": "Header information",
                },
            },
        }

    @pytest.fixture
    def config_with_ref_schema(self, discharge_summary_schema):
        """Fixture providing config with the $ref-based schema."""
        return {
            "classes": [discharge_summary_schema],
            "assessment": {
                "model": "us.amazon.nova-pro-v1:0",
                "temperature": 0,
                "top_k": 5,
                "default_confidence_threshold": 0.8,
                "system_prompt": "You are an assessment expert.",
                "task_prompt": "Assess {DOCUMENT_CLASS}. Attributes: {ATTRIBUTE_NAMES_AND_DESCRIPTIONS}. Results: {EXTRACTION_RESULTS}",
                "granular": {
                    "enabled": True,
                    "simple_batch_size": 3,
                    "list_batch_size": 1,
                    "max_workers": 1,
                },
            },
        }

    @pytest.fixture
    def service(self, config_with_ref_schema):
        """Fixture providing a GranularAssessmentService instance."""
        return GranularAssessmentService(
            region="us-west-2", config=config_with_ref_schema
        )

    @pytest.fixture
    def extraction_results(self):
        """Sample extraction results for DischargeSummary."""
        return {
            "PatientInformation": {
                "Patient": "John Doe",
                "Providers-Pt-ID": "12345",
                "Patient-Gender": "Male",
            },
            "VisitDetails": {
                "Admitted": "01/15/2025",
                "Discharged": "01/20/2025",
            },
            "Header": {
                "HospitalName": "General Hospital",
                "DocumentTitle": "Discharge Summary",
            },
        }

    def test_ref_properties_classified_as_groups(
        self, service, discharge_summary_schema, extraction_results
    ):
        """
        Test that properties using $ref to object definitions are classified as 'group' tasks.

        This is the core test for the bug: properties with $ref were being classified as
        'simple_batch' because prop_schema.get(SCHEMA_TYPE) returns None for $ref properties.
        """
        properties = discharge_summary_schema["properties"]
        default_threshold = 0.8

        # Create assessment tasks - pass the full schema as root_schema for $ref resolution
        tasks = service._create_assessment_tasks(
            extraction_results,
            properties,
            default_threshold,
            root_schema=discharge_summary_schema,
        )

        # Collect task types by attribute name
        task_types = {}
        for task in tasks:
            for attr in task.attributes:
                task_types[attr] = task.task_type

        # All three top-level properties use $ref to object definitions
        # They should ALL be classified as 'group', NOT 'simple_batch'
        assert task_types.get("PatientInformation") == "group", (
            f"PatientInformation should be 'group' but got '{task_types.get('PatientInformation')}'. "
            f"$ref resolution is not working - properties are being classified as simple types."
        )
        assert task_types.get("VisitDetails") == "group", (
            f"VisitDetails should be 'group' but got '{task_types.get('VisitDetails')}'. "
            f"$ref resolution is not working."
        )
        assert task_types.get("Header") == "group", (
            f"Header should be 'group' but got '{task_types.get('Header')}'. "
            f"$ref resolution is not working."
        )

    def test_ref_properties_have_correct_confidence_thresholds(
        self, service, discharge_summary_schema, extraction_results
    ):
        """
        Test that confidence thresholds for $ref properties are properly resolved.
        """
        properties = discharge_summary_schema["properties"]
        default_threshold = 0.8

        tasks = service._create_assessment_tasks(
            extraction_results,
            properties,
            default_threshold,
            root_schema=discharge_summary_schema,
        )

        # Find the group task for PatientInformation
        patient_info_task = None
        for task in tasks:
            if "PatientInformation" in task.attributes and task.task_type == "group":
                patient_info_task = task
                break

        # If $ref is resolved correctly, we should have a group task with confidence thresholds
        # for the nested properties (Patient, Providers-Pt-ID, Patient-Gender)
        assert patient_info_task is not None, (
            "PatientInformation should have a 'group' task, but none found. "
            "This indicates $ref resolution is not working."
        )

        # The confidence_thresholds dict should contain the nested property names
        assert "Patient" in patient_info_task.confidence_thresholds, (
            "confidence_thresholds should include 'Patient' from resolved $ref schema"
        )
        assert "Providers-Pt-ID" in patient_info_task.confidence_thresholds, (
            "confidence_thresholds should include 'Providers-Pt-ID' from resolved $ref schema"
        )

    def test_schema_with_mixed_ref_and_inline(self):
        """
        Test schema with both $ref properties and inline properties.
        """
        mixed_schema = {
            "$defs": {
                "AddressDef": {
                    "type": "object",
                    "properties": {
                        "street": {"type": "string"},
                        "city": {"type": "string"},
                    },
                },
            },
            "properties": {
                # Inline object definition (no $ref)
                "PersonName": {
                    "type": "object",
                    "properties": {
                        "first": {"type": "string"},
                        "last": {"type": "string"},
                    },
                },
                # $ref to object definition
                "Address": {
                    "$ref": "#/$defs/AddressDef",
                },
                # Simple string property
                "PhoneNumber": {
                    "type": "string",
                },
            },
        }

        config = {
            "classes": [
                {
                    **mixed_schema,
                    "x-aws-idp-document-type": "ContactInfo",
                }
            ],
            "assessment": {
                "model": "us.amazon.nova-pro-v1:0",
                "default_confidence_threshold": 0.8,
                "granular": {
                    "enabled": True,
                    "simple_batch_size": 3,
                    "list_batch_size": 1,
                    "max_workers": 1,
                },
            },
        }

        service = GranularAssessmentService(region="us-west-2", config=config)

        extraction_results = {
            "PersonName": {"first": "John", "last": "Doe"},
            "Address": {"street": "123 Main St", "city": "Springfield"},
            "PhoneNumber": "555-1234",
        }

        full_schema = {**mixed_schema, "x-aws-idp-document-type": "ContactInfo"}
        tasks = service._create_assessment_tasks(
            extraction_results, mixed_schema["properties"], 0.8, root_schema=full_schema
        )

        task_types = {
            attr: task.task_type for task in tasks for attr in task.attributes
        }

        # Inline object should be group
        assert task_types.get("PersonName") == "group", (
            f"PersonName (inline object) should be 'group' but got '{task_types.get('PersonName')}'"
        )

        # $ref object should also be group
        assert task_types.get("Address") == "group", (
            f"Address ($ref object) should be 'group' but got '{task_types.get('Address')}'"
        )

        # Simple string should be in simple_batch
        assert task_types.get("PhoneNumber") == "simple_batch", (
            f"PhoneNumber should be 'simple_batch' but got '{task_types.get('PhoneNumber')}'"
        )

    def test_ref_to_array_definition(self):
        """
        Test that $ref to array definitions are classified as 'list_item' tasks.
        """
        array_ref_schema = {
            "$defs": {
                "TransactionItem": {
                    "type": "object",
                    "properties": {
                        "date": {"type": "string"},
                        "amount": {"type": "string"},
                    },
                },
                "TransactionsList": {
                    "type": "array",
                    "items": {"$ref": "#/$defs/TransactionItem"},
                },
            },
            "properties": {
                "Transactions": {
                    "$ref": "#/$defs/TransactionsList",
                },
            },
        }

        config = {
            "classes": [
                {
                    **array_ref_schema,
                    "x-aws-idp-document-type": "BankStatement",
                }
            ],
            "assessment": {
                "model": "us.amazon.nova-pro-v1:0",
                "default_confidence_threshold": 0.8,
                "granular": {
                    "enabled": True,
                    "simple_batch_size": 3,
                    "list_batch_size": 1,
                    "max_workers": 1,
                },
            },
        }

        service = GranularAssessmentService(region="us-west-2", config=config)

        extraction_results = {
            "Transactions": [
                {"date": "01/15/2025", "amount": "$100.00"},
                {"date": "01/16/2025", "amount": "$50.00"},
            ],
        }

        full_schema = {**array_ref_schema, "x-aws-idp-document-type": "BankStatement"}
        tasks = service._create_assessment_tasks(
            extraction_results,
            array_ref_schema["properties"],
            0.8,
            root_schema=full_schema,
        )

        # Should have list_item tasks for each transaction
        list_item_tasks = [t for t in tasks if t.task_type == "list_item"]
        assert len(list_item_tasks) == 2, (
            f"Expected 2 list_item tasks for Transactions array, got {len(list_item_tasks)}. "
            f"$ref to array type may not be resolving correctly."
        )

    def test_confidence_alerts_with_ref_schema(self, service, discharge_summary_schema):
        """
        Test that confidence alerts are correctly generated for $ref properties.

        The original bug caused alerts to be generated with confidence=0 because
        group properties were treated as simple, and .get("confidence", 0.0) was
        called on the group dict which doesn't have a direct "confidence" key.
        """
        # Simulate assessment data returned by LLM for group properties
        assessment_data = {
            "PatientInformation": {
                "Patient": {
                    "confidence": 0.99,
                    "confidence_reason": "Clear text",
                },
                "Providers-Pt-ID": {
                    "confidence": 0.75,  # Below threshold of 0.8
                    "confidence_reason": "Partially visible",
                },
                "Patient-Gender": {
                    "confidence": 0.95,
                    "confidence_reason": "Clear text",
                },
            },
        }

        # Create a mock task that should be a "group" task
        from idp_common.assessment.granular_service import AssessmentTask

        # This is what the task SHOULD look like after proper $ref resolution
        group_task = AssessmentTask(
            task_id="group_0",
            task_type="group",  # CORRECT: should be group
            attributes=["PatientInformation"],
            extraction_data={
                "PatientInformation": {"Patient": "John", "Providers-Pt-ID": "123"}
            },
            confidence_thresholds={
                "Patient": 0.8,
                "Providers-Pt-ID": 0.8,
                "Patient-Gender": 0.8,
            },
        )

        # Check confidence alerts for the group task
        alerts = []
        service._check_confidence_alerts_for_task(group_task, assessment_data, alerts)

        # Should have exactly 1 alert for Providers-Pt-ID (0.75 < 0.8)
        assert len(alerts) == 1, (
            f"Expected 1 alert (for Providers-Pt-ID), got {len(alerts)}. "
            f"Alerts: {alerts}"
        )
        assert alerts[0]["attribute_name"] == "PatientInformation.Providers-Pt-ID"
        assert alerts[0]["confidence"] == 0.75
        assert alerts[0]["confidence_threshold"] == 0.8

    def test_simple_batch_documents_false_alerts_bug(self):
        """
        Test documents that when $ref properties are INCORRECTLY classified as simple_batch,
        false alerts with confidence=0 are generated.

        This is a DOCUMENTATION test showing the secondary bug in _check_confidence_alerts_for_task.
        The PRIMARY fix (classifying $ref properties correctly) prevents this scenario.

        NOTE: This test documents existing alert-checking behavior - the fix for the main issue
        ensures $ref properties are never classified as simple_batch, so this scenario won't occur.
        """
        from idp_common.assessment.granular_service import AssessmentTask

        # Simulate the INCORRECT task classification where a group is treated as simple
        # This simulates what happens when $ref resolution fails or is skipped
        incorrectly_classified_task = AssessmentTask(
            task_id="simple_batch_0",
            task_type="simple_batch",  # WRONG: should be "group" for object properties
            attributes=["PatientInformation"],
            extraction_data={"PatientInformation": {"Patient": "John"}},
            confidence_thresholds={
                "PatientInformation": 0.8
            },  # Wrong: threshold should be for nested props
        )

        # Assessment data from LLM (correct structure with nested confidence)
        assessment_data = {
            "PatientInformation": {
                "Patient": {
                    "confidence": 0.99,
                    "confidence_reason": "Clear text",
                },
            },
        }

        config = {
            "assessment": {
                "model": "us.amazon.nova-pro-v1:0",
                "default_confidence_threshold": 0.8,
                "granular": {
                    "enabled": True,
                    "simple_batch_size": 3,
                    "list_batch_size": 1,
                    "max_workers": 1,
                },
            },
        }
        service = GranularAssessmentService(region="us-west-2", config=config)

        alerts = []
        service._check_confidence_alerts_for_task(
            incorrectly_classified_task, assessment_data, alerts
        )

        # DOCUMENTED BEHAVIOR: When a group is incorrectly classified as simple_batch,
        # a false positive alert is generated because:
        # - assessment_data["PatientInformation"] is a dict {"Patient": {...}}
        # - .get("confidence", 0.0) returns 0.0 (no direct "confidence" key)
        # - 0.0 < 0.8 threshold → alert created with confidence=0
        #
        # The PRIMARY FIX (resolving $ref and classifying correctly) prevents this scenario.
        # This test documents the behavior for understanding purposes.
        assert len(alerts) == 1, (
            f"Expected 1 false positive alert when group incorrectly classified as simple_batch. "
            f"Got {len(alerts)} alerts: {alerts}"
        )
        assert alerts[0]["confidence"] == 0.0, (
            f"Expected confidence=0.0 (false positive), got {alerts[0]['confidence']}"
        )
        assert alerts[0]["attribute_name"] == "PatientInformation", (
            f"Expected alert for PatientInformation, got {alerts[0]['attribute_name']}"
        )
