# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for the DocumentAppSyncService class.
"""

import datetime
import json
from unittest.mock import MagicMock, patch

import pytest
from idp_common.appsync.service import DocumentAppSyncService
from idp_common.models import Document, Page, Section, Status


@pytest.mark.unit
class TestDocumentAppSyncService:
    """Tests for the DocumentAppSyncService class."""

    def test_init_with_client(self):
        """Test initialization with an existing client."""
        mock_client = MagicMock()
        service = DocumentAppSyncService(appsync_client=mock_client)
        assert service.client == mock_client

    @patch("idp_common.appsync.service.AppSyncClient")
    def test_init_without_client(self, mock_appsync_client):
        """Test initialization without a client."""
        mock_client_instance = MagicMock()
        mock_appsync_client.return_value = mock_client_instance

        service = DocumentAppSyncService(api_url="https://test-api.com/graphql")

        mock_appsync_client.assert_called_once_with(
            api_url="https://test-api.com/graphql"
        )
        assert service.client == mock_client_instance

    def test_document_to_create_input_basic(self):
        """Test conversion of Document to CreateDocumentInput with basic fields."""
        # Create a simple document
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            status=Status.QUEUED,
            initial_event_time="2025-05-08T14:30:00Z",
            queued_time="2025-05-08T14:31:00Z",
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_create_input(doc)

        # Verify conversion
        assert input_data["ObjectKey"] == "test-document.pdf"
        assert input_data["ObjectStatus"] == "QUEUED"
        assert input_data["InitialEventTime"] == "2025-05-08T14:30:00Z"
        assert input_data["QueuedTime"] == "2025-05-08T14:31:00Z"
        assert (
            input_data["ExpiresAfter"] is None
        )  # ExpiresAfter is included but set to None

    def test_document_to_create_input_with_ttl(self):
        """Test conversion of Document to CreateDocumentInput with TTL."""
        # Create a simple document
        doc = Document(
            id="test-doc", input_key="test-document.pdf", status=Status.QUEUED
        )

        # Create service and convert document with TTL
        service = DocumentAppSyncService(appsync_client=MagicMock())
        expires_after = 1715180318  # Example timestamp
        input_data = service._document_to_create_input(doc, expires_after)

        # Verify TTL is included
        assert input_data["ExpiresAfter"] == 1715180318

    def test_document_to_update_input_basic(self):
        """Test conversion of Document to UpdateDocumentInput with basic fields."""
        # Create a simple document
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            status=Status.RUNNING,
            queued_time="2025-05-08T14:31:00Z",
            start_time="2025-05-08T14:32:00Z",
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_update_input(doc)

        # Verify conversion
        assert input_data["ObjectKey"] == "test-document.pdf"
        assert input_data["ObjectStatus"] == "RUNNING"
        assert input_data["QueuedTime"] == "2025-05-08T14:31:00Z"
        assert input_data["WorkflowStartTime"] == "2025-05-08T14:32:00Z"
        assert input_data["WorkflowStatus"] == "RUNNING"

    def test_document_to_update_input_completed(self):
        """Test conversion of Document to UpdateDocumentInput with completed status."""
        # Create a completed document
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            status=Status.COMPLETED,
            queued_time="2025-05-08T14:31:00Z",
            start_time="2025-05-08T14:32:00Z",
            completion_time="2025-05-08T14:35:00Z",
            workflow_execution_arn="arn:aws:states:us-west-2:123456789012:execution:workflow:test-execution",
            num_pages=3,
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_update_input(doc)

        # Verify conversion
        assert input_data["ObjectKey"] == "test-document.pdf"
        assert input_data["ObjectStatus"] == "COMPLETED"
        assert input_data["WorkflowStatus"] == "SUCCEEDED"
        assert input_data["CompletionTime"] == "2025-05-08T14:35:00Z"
        assert (
            input_data["WorkflowExecutionArn"]
            == "arn:aws:states:us-west-2:123456789012:execution:workflow:test-execution"
        )
        assert input_data["PageCount"] == 3

    def test_document_to_update_input_with_pages(self):
        """Test conversion of Document to UpdateDocumentInput with pages."""
        # Create a document with pages
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            status=Status.COMPLETED,
            num_pages=2,
        )

        # Add pages
        doc.pages["1"] = Page(
            page_id="1",
            image_uri="s3://bucket/test-document.pdf/pages/1/image.jpg",
            raw_text_uri="s3://bucket/test-document.pdf/pages/1/rawText.json",
            classification="Invoice",
        )

        doc.pages["2"] = Page(
            page_id="2",
            image_uri="s3://bucket/test-document.pdf/pages/2/image.jpg",
            raw_text_uri="s3://bucket/test-document.pdf/pages/2/rawText.json",
            classification="Receipt",
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_update_input(doc)

        # Verify pages conversion
        assert "Pages" in input_data
        assert len(input_data["Pages"]) == 2

        # Check page 1
        page1 = next(p for p in input_data["Pages"] if p["Id"] == 1)
        assert page1["Class"] == "Invoice"
        assert page1["ImageUri"] == "s3://bucket/test-document.pdf/pages/1/image.jpg"
        assert page1["TextUri"] == "s3://bucket/test-document.pdf/pages/1/rawText.json"

        # Check page 2
        page2 = next(p for p in input_data["Pages"] if p["Id"] == 2)
        assert page2["Class"] == "Receipt"
        assert page2["ImageUri"] == "s3://bucket/test-document.pdf/pages/2/image.jpg"
        assert page2["TextUri"] == "s3://bucket/test-document.pdf/pages/2/rawText.json"

    def test_document_to_update_input_with_sections(self):
        """Test conversion of Document to UpdateDocumentInput with sections."""
        # Create a document with sections
        doc = Document(
            id="test-doc", input_key="test-document.pdf", status=Status.COMPLETED
        )

        # Add sections
        doc.sections.append(
            Section(
                section_id="section-1",
                classification="Invoice",
                page_ids=["1", "2"],
                extraction_result_uri="s3://bucket/test-document.pdf/sections/section-1/result.json",
            )
        )

        doc.sections.append(
            Section(
                section_id="section-2",
                classification="Receipt",
                page_ids=["3"],
                extraction_result_uri="s3://bucket/test-document.pdf/sections/section-2/result.json",
            )
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_update_input(doc)

        # Verify sections conversion
        assert "Sections" in input_data
        assert len(input_data["Sections"]) == 2

        # Check section 1
        section1 = next(s for s in input_data["Sections"] if s["Id"] == "section-1")
        assert section1["Class"] == "Invoice"
        assert section1["PageIds"] == [1, 2]
        assert (
            section1["OutputJSONUri"]
            == "s3://bucket/test-document.pdf/sections/section-1/result.json"
        )

        # Check section 2
        section2 = next(s for s in input_data["Sections"] if s["Id"] == "section-2")
        assert section2["Class"] == "Receipt"
        assert section2["PageIds"] == [3]
        assert (
            section2["OutputJSONUri"]
            == "s3://bucket/test-document.pdf/sections/section-2/result.json"
        )

    def test_document_to_update_input_with_metering(self):
        """Test conversion of Document to UpdateDocumentInput with metering data."""
        # Create a document with metering data
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            status=Status.COMPLETED,
            metering={
                "textract": {"pages": 3, "cost": 0.015},
                "bedrock": {"tokens": 5000, "cost": 0.025},
            },
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_update_input(doc)

        # Verify metering conversion
        assert "Metering" in input_data
        metering_data = json.loads(input_data["Metering"])
        assert metering_data["textract"]["pages"] == 3
        assert metering_data["textract"]["cost"] == 0.015
        assert metering_data["bedrock"]["tokens"] == 5000
        assert metering_data["bedrock"]["cost"] == 0.025

    def test_document_to_update_input_with_evaluation(self):
        """Test conversion of Document to UpdateDocumentInput with evaluation data."""
        # Create a document with evaluation data
        doc = Document(
            id="test-doc",
            input_key="test-document.pdf",
            status=Status.COMPLETED,
            evaluation_status="COMPLETED",
            evaluation_report_uri="s3://bucket/test-document.pdf/evaluation/report.md",
        )

        # Create service and convert document
        service = DocumentAppSyncService(appsync_client=MagicMock())
        input_data = service._document_to_update_input(doc)

        # Verify evaluation data conversion
        assert input_data["EvaluationStatus"] == "COMPLETED"
        assert (
            input_data["EvaluationReportUri"]
            == "s3://bucket/test-document.pdf/evaluation/report.md"
        )

    def test_appsync_to_document_basic(self):
        """Test conversion from AppSync data to Document with basic fields."""
        # Create AppSync data
        appsync_data = {
            "ObjectKey": "test-document.pdf",
            "ObjectStatus": "COMPLETED",
            "InitialEventTime": "2025-05-08T14:30:00Z",
            "QueuedTime": "2025-05-08T14:31:00Z",
            "WorkflowStartTime": "2025-05-08T14:32:00Z",
            "CompletionTime": "2025-05-08T14:35:00Z",
            "WorkflowExecutionArn": "arn:aws:states:us-west-2:123456789012:execution:workflow:test-execution",
            "PageCount": 3,
        }

        # Create service and convert data
        service = DocumentAppSyncService(appsync_client=MagicMock())
        doc = service._appsync_to_document(appsync_data)

        # Verify conversion
        assert doc.id == "test-document.pdf"
        assert doc.input_key == "test-document.pdf"
        assert doc.status == Status.COMPLETED
        assert doc.queued_time == "2025-05-08T14:31:00Z"
        assert doc.start_time == "2025-05-08T14:32:00Z"
        assert doc.completion_time == "2025-05-08T14:35:00Z"
        assert (
            doc.workflow_execution_arn
            == "arn:aws:states:us-west-2:123456789012:execution:workflow:test-execution"
        )
        assert doc.num_pages == 3

    def test_appsync_to_document_with_pages(self):
        """Test conversion from AppSync data to Document with pages."""
        # Create AppSync data with pages
        appsync_data = {
            "ObjectKey": "test-document.pdf",
            "ObjectStatus": "COMPLETED",
            "Pages": [
                {
                    "Id": 1,
                    "Class": "Invoice",
                    "ImageUri": "s3://bucket/test-document.pdf/pages/1/image.jpg",
                    "TextUri": "s3://bucket/test-document.pdf/pages/1/rawText.json",
                },
                {
                    "Id": 2,
                    "Class": "Receipt",
                    "ImageUri": "s3://bucket/test-document.pdf/pages/2/image.jpg",
                    "TextUri": "s3://bucket/test-document.pdf/pages/2/rawText.json",
                },
            ],
        }

        # Create service and convert data
        service = DocumentAppSyncService(appsync_client=MagicMock())
        doc = service._appsync_to_document(appsync_data)

        # Verify pages conversion
        assert len(doc.pages) == 2

        # Check page 1
        assert "1" in doc.pages
        assert doc.pages["1"].page_id == "1"
        assert doc.pages["1"].classification == "Invoice"
        assert (
            doc.pages["1"].image_uri
            == "s3://bucket/test-document.pdf/pages/1/image.jpg"
        )
        assert (
            doc.pages["1"].raw_text_uri
            == "s3://bucket/test-document.pdf/pages/1/rawText.json"
        )

        # Check page 2
        assert "2" in doc.pages
        assert doc.pages["2"].page_id == "2"
        assert doc.pages["2"].classification == "Receipt"
        assert (
            doc.pages["2"].image_uri
            == "s3://bucket/test-document.pdf/pages/2/image.jpg"
        )
        assert (
            doc.pages["2"].raw_text_uri
            == "s3://bucket/test-document.pdf/pages/2/rawText.json"
        )

    def test_appsync_to_document_with_sections(self):
        """Test conversion from AppSync data to Document with sections."""
        # Create AppSync data with sections
        appsync_data = {
            "ObjectKey": "test-document.pdf",
            "ObjectStatus": "COMPLETED",
            "Sections": [
                {
                    "Id": "section-1",
                    "Class": "Invoice",
                    "PageIds": [1, 2],
                    "OutputJSONUri": "s3://bucket/test-document.pdf/sections/section-1/result.json",
                },
                {
                    "Id": "section-2",
                    "Class": "Receipt",
                    "PageIds": [3],
                    "OutputJSONUri": "s3://bucket/test-document.pdf/sections/section-2/result.json",
                },
            ],
        }

        # Create service and convert data
        service = DocumentAppSyncService(appsync_client=MagicMock())
        doc = service._appsync_to_document(appsync_data)

        # Verify sections conversion
        assert len(doc.sections) == 2

        # Check section 1
        section1 = next(s for s in doc.sections if s.section_id == "section-1")
        assert section1.classification == "Invoice"
        assert section1.page_ids == ["1", "2"]
        assert (
            section1.extraction_result_uri
            == "s3://bucket/test-document.pdf/sections/section-1/result.json"
        )

        # Check section 2
        section2 = next(s for s in doc.sections if s.section_id == "section-2")
        assert section2.classification == "Receipt"
        assert section2.page_ids == ["3"]
        assert (
            section2.extraction_result_uri
            == "s3://bucket/test-document.pdf/sections/section-2/result.json"
        )

    def test_appsync_to_document_with_metering(self):
        """Test conversion from AppSync data to Document with metering data."""
        # Create AppSync data with metering
        metering_data = {
            "textract": {"pages": 3, "cost": 0.015},
            "bedrock": {"tokens": 5000, "cost": 0.025},
        }

        appsync_data = {
            "ObjectKey": "test-document.pdf",
            "ObjectStatus": "COMPLETED",
            "Metering": json.dumps(metering_data),
        }

        # Create service and convert data
        service = DocumentAppSyncService(appsync_client=MagicMock())
        doc = service._appsync_to_document(appsync_data)

        # Verify metering conversion
        assert doc.metering["textract"]["pages"] == 3
        assert doc.metering["textract"]["cost"] == 0.015
        assert doc.metering["bedrock"]["tokens"] == 5000
        assert doc.metering["bedrock"]["cost"] == 0.025

    @patch(
        "idp_common.appsync.service.DocumentAppSyncService._document_to_create_input"
    )
    def test_create_document(self, mock_to_create_input):
        """Test creating a document in AppSync."""
        # Setup
        mock_client = MagicMock()
        mock_client.execute_mutation.return_value = {
            "createDocument": {"ObjectKey": "test-document.pdf"}
        }

        mock_to_create_input.return_value = {
            "ObjectKey": "test-document.pdf",
            "ObjectStatus": "QUEUED",
        }

        # Create document and service
        doc = Document(id="test-doc", input_key="test-document.pdf")
        service = DocumentAppSyncService(appsync_client=mock_client)

        # Test
        result = service.create_document(doc)

        # Verify
        mock_to_create_input.assert_called_once_with(doc, None)
        mock_client.execute_mutation.assert_called_once()
        assert result == "test-document.pdf"

    @patch(
        "idp_common.appsync.service.DocumentAppSyncService._document_to_update_input"
    )
    @patch("idp_common.appsync.service.DocumentAppSyncService._appsync_to_document")
    def test_update_document(self, mock_to_document, mock_to_update_input):
        """Test updating a document in AppSync."""
        # Setup
        mock_client = MagicMock()
        mock_client.execute_mutation.return_value = {
            "updateDocument": {
                "ObjectKey": "test-document.pdf",
                "ObjectStatus": "COMPLETED",
            }
        }

        mock_to_update_input.return_value = {
            "ObjectKey": "test-document.pdf",
            "ObjectStatus": "COMPLETED",
        }

        updated_doc = Document(
            id="test-doc", input_key="test-document.pdf", status=Status.COMPLETED
        )
        mock_to_document.return_value = updated_doc

        # Create document and service
        doc = Document(id="test-doc", input_key="test-document.pdf")
        service = DocumentAppSyncService(appsync_client=mock_client)

        # Test
        result = service.update_document(doc)

        # Verify
        mock_to_update_input.assert_called_once_with(doc)
        mock_client.execute_mutation.assert_called_once()
        mock_to_document.assert_called_once_with(
            {"ObjectKey": "test-document.pdf", "ObjectStatus": "COMPLETED"}
        )
        assert result == updated_doc

    def test_calculate_ttl(self):
        """Test TTL calculation for document expiration."""
        # Setup
        service = DocumentAppSyncService(appsync_client=MagicMock())

        # Test with default 30 days
        with patch("idp_common.appsync.service.datetime") as mock_datetime:
            # Mock the datetime.now() call
            mock_now = datetime.datetime(2025, 5, 8, 14, 38, 0)
            mock_datetime.datetime.now.return_value = mock_now

            # Mock the timedelta calculation
            mock_datetime.timedelta.side_effect = lambda days: datetime.timedelta(
                days=days
            )

            # Calculate TTL
            ttl = service.calculate_ttl()

            # Expected expiration date: 2025-06-07 14:38:00
            expected_expiration = datetime.datetime(2025, 6, 7, 14, 38, 0)
            expected_timestamp = int(expected_expiration.timestamp())

            assert ttl == expected_timestamp

        # Test with custom days
        with patch("idp_common.appsync.service.datetime") as mock_datetime:
            # Mock the datetime.now() call
            mock_now = datetime.datetime(2025, 5, 8, 14, 38, 0)
            mock_datetime.datetime.now.return_value = mock_now

            # Mock the timedelta calculation
            mock_datetime.timedelta.side_effect = lambda days: datetime.timedelta(
                days=days
            )

            # Calculate TTL with 7 days
            ttl = service.calculate_ttl(days=7)

            # Expected expiration date: 2025-05-15 14:38:00
            expected_expiration = datetime.datetime(2025, 5, 15, 14, 38, 0)
            expected_timestamp = int(expected_expiration.timestamp())

            assert ttl == expected_timestamp
