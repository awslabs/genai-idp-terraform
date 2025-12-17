# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Unit tests for nested geometry conversion in AssessmentService.
Tests the recursive processing of group attributes with bounding boxes.
"""

from idp_common.assessment.service import AssessmentService


class TestNestedGeometryConversion:
    """Test nested geometry conversion for group and list attributes."""

    def test_simple_attribute_geometry_conversion(self):
        """Test that simple attributes still work correctly."""
        service = AssessmentService()

        assessment_data = {
            "YTDCityTax": {
                "confidence": 1.0,
                "confidence_reason": "Clear text with high OCR confidence",
                "bbox": [449, 450, 507, 462],
                "page": 1,
            }
        }

        result = service._extract_geometry_from_assessment(assessment_data)

        # Check conversion worked
        assert "geometry" in result["YTDCityTax"]
        assert "bbox" not in result["YTDCityTax"]
        assert "page" not in result["YTDCityTax"]

        # Verify geometry structure
        geometry = result["YTDCityTax"]["geometry"][0]
        assert geometry["page"] == 1
        assert "boundingBox" in geometry

        bbox = geometry["boundingBox"]
        assert bbox["top"] == 0.45  # 450/1000
        assert bbox["left"] == 0.449  # 449/1000
        assert bbox["width"] == 0.058  # (507-449)/1000
        assert bbox["height"] == 0.012  # (462-450)/1000

    def test_nested_group_attribute_geometry_conversion(self):
        """Test that nested group attributes are processed recursively."""
        service = AssessmentService()

        assessment_data = {
            "CompanyAddress": {
                "State": {
                    "confidence": 0.99,
                    "confidence_reason": "Clear text with high OCR confidence",
                    "bbox": [230, 116, 259, 126],
                    "page": 1,
                },
                "ZipCode": {
                    "confidence": 0.99,
                    "confidence_reason": "Clear text with high OCR confidence",
                    "bbox": [261, 116, 298, 126],
                    "page": 1,
                },
            }
        }

        result = service._extract_geometry_from_assessment(assessment_data)

        # Check that nested attributes were processed
        company_address = result["CompanyAddress"]

        # State should be converted
        assert "geometry" in company_address["State"]
        assert "bbox" not in company_address["State"]
        assert "page" not in company_address["State"]

        state_geometry = company_address["State"]["geometry"][0]
        assert state_geometry["page"] == 1
        assert state_geometry["boundingBox"]["top"] == 0.116  # 116/1000
        assert state_geometry["boundingBox"]["left"] == 0.23  # 230/1000

        # ZipCode should be converted
        assert "geometry" in company_address["ZipCode"]
        assert "bbox" not in company_address["ZipCode"]
        assert "page" not in company_address["ZipCode"]

        zip_geometry = company_address["ZipCode"]["geometry"][0]
        assert zip_geometry["page"] == 1
        assert zip_geometry["boundingBox"]["left"] == 0.261  # 261/1000

    def test_mixed_attributes_with_and_without_geometry(self):
        """Test processing of mixed attributes - some with geometry, some without."""
        service = AssessmentService()

        assessment_data = {
            "currency": {
                "confidence": 0.0,
                "confidence_reason": "No clear evidence found",
                # No bbox data
            },
            "CompanyAddress": {
                "State": {
                    "confidence": 0.99,
                    "confidence_reason": "Clear text",
                    "bbox": [230, 116, 259, 126],
                    "page": 1,
                },
                "Country": {
                    "confidence": 0.85,
                    "confidence_reason": "Good evidence",
                    # No bbox data for this sub-attribute
                },
            },
            "YTDCityTax": {
                "confidence": 1.0,
                "confidence_reason": "Clear text",
                "bbox": [449, 450, 507, 462],
                "page": 1,
            },
        }

        result = service._extract_geometry_from_assessment(assessment_data)

        # currency should pass through unchanged (no geometry)
        assert "geometry" not in result["currency"]
        assert "bbox" not in result["currency"]
        assert result["currency"]["confidence"] == 0.0

        # CompanyAddress.State should have geometry
        assert "geometry" in result["CompanyAddress"]["State"]
        assert "bbox" not in result["CompanyAddress"]["State"]

        # CompanyAddress.Country should not have geometry
        assert "geometry" not in result["CompanyAddress"]["Country"]
        assert "bbox" not in result["CompanyAddress"]["Country"]
        assert result["CompanyAddress"]["Country"]["confidence"] == 0.85

        # YTDCityTax should have geometry
        assert "geometry" in result["YTDCityTax"]
        assert "bbox" not in result["YTDCityTax"]

    def test_list_attributes_with_nested_geometry(self):
        """Test processing of list attributes where each item may have geometry."""
        service = AssessmentService()

        assessment_data = {
            "Transactions": [
                {
                    "Date": {
                        "confidence": 0.95,
                        "confidence_reason": "Clear date format",
                        "bbox": [100, 200, 150, 220],
                        "page": 1,
                    },
                    "Amount": {
                        "confidence": 0.88,
                        "confidence_reason": "Good number format",
                        "bbox": [200, 200, 250, 220],
                        "page": 1,
                    },
                },
                {
                    "Date": {
                        "confidence": 0.92,
                        "confidence_reason": "Clear date",
                        "bbox": [100, 225, 150, 245],
                        "page": 1,
                    },
                    "Amount": {
                        "confidence": 0.75,
                        "confidence_reason": "Decent format",
                        # No bbox for this item
                    },
                },
            ]
        }

        result = service._extract_geometry_from_assessment(assessment_data)

        transactions = result["Transactions"]
        assert len(transactions) == 2

        # First transaction - both Date and Amount should have geometry processed
        first_txn = transactions[0]
        assert "geometry" in first_txn["Date"]
        assert "bbox" not in first_txn["Date"]
        assert "geometry" in first_txn["Amount"]
        assert "bbox" not in first_txn["Amount"]

        # Second transaction - Date has geometry, Amount doesn't
        second_txn = transactions[1]
        assert "geometry" in second_txn["Date"]
        assert "bbox" not in second_txn["Date"]
        assert "geometry" not in second_txn["Amount"]
        assert "bbox" not in second_txn["Amount"]

    def test_deeply_nested_group_attributes(self):
        """Test deeply nested group attributes."""
        service = AssessmentService()

        assessment_data = {
            "EmployeeInfo": {
                "PersonalDetails": {
                    "Name": {
                        "confidence": 0.95,
                        "confidence_reason": "Clear name",
                        "bbox": [100, 100, 200, 120],
                        "page": 1,
                    }
                },
                "Address": {
                    "Street": {
                        "confidence": 0.88,
                        "confidence_reason": "Good street info",
                        "bbox": [100, 150, 300, 170],
                        "page": 1,
                    },
                    "City": {
                        "confidence": 0.92,
                        "confidence_reason": "Clear city",
                        # No bbox
                    },
                },
            }
        }

        result = service._extract_geometry_from_assessment(assessment_data)

        employee_info = result["EmployeeInfo"]

        # Check PersonalDetails.Name
        name = employee_info["PersonalDetails"]["Name"]
        assert "geometry" in name
        assert "bbox" not in name
        assert name["geometry"][0]["page"] == 1

        # Check Address.Street
        street = employee_info["Address"]["Street"]
        assert "geometry" in street
        assert "bbox" not in street

        # Check Address.City (no geometry)
        city = employee_info["Address"]["City"]
        assert "geometry" not in city
        assert "bbox" not in city
        assert city["confidence"] == 0.92

    def test_invalid_nested_bbox_data(self):
        """Test handling of invalid bbox data in nested attributes."""
        service = AssessmentService()

        assessment_data = {
            "CompanyAddress": {
                "State": {
                    "confidence": 0.99,
                    "confidence_reason": "Clear text",
                    "bbox": "invalid_format",  # Invalid
                    "page": 1,
                },
                "ZipCode": {
                    "confidence": 0.85,
                    "confidence_reason": "Good text",
                    "bbox": [261, 116, 298, 126],
                    # Missing page
                },
            }
        }

        result = service._extract_geometry_from_assessment(assessment_data)

        # Both should have invalid bbox data removed but confidence preserved
        state = result["CompanyAddress"]["State"]
        assert "geometry" not in state
        assert "bbox" not in state
        assert "page" not in state
        assert state["confidence"] == 0.99

        zip_code = result["CompanyAddress"]["ZipCode"]
        assert "geometry" not in zip_code
        assert "bbox" not in zip_code
        assert zip_code["confidence"] == 0.85

    def test_process_single_assessment_geometry_method(self):
        """Test the helper method for processing single assessments."""
        service = AssessmentService()

        # Test valid geometry conversion
        assessment = {
            "confidence": 0.95,
            "confidence_reason": "Clear text",
            "bbox": [100, 200, 300, 400],
            "page": 1,
        }

        result = service._process_single_assessment_geometry(assessment, "test_field")

        assert "geometry" in result
        assert "bbox" not in result
        assert "page" not in result
        assert result["confidence"] == 0.95

        # Verify geometry conversion
        geometry = result["geometry"][0]
        assert geometry["page"] == 1
        assert geometry["boundingBox"]["top"] == 0.2
        assert geometry["boundingBox"]["left"] == 0.1
        assert geometry["boundingBox"]["width"] == 0.2
        assert geometry["boundingBox"]["height"] == 0.2
