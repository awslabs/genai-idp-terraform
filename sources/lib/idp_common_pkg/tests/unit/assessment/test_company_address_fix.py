# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Test to verify the specific CompanyAddress nested geometry conversion issue is fixed.
"""

import json

from idp_common.assessment.service import AssessmentService


def test_company_address_geometry_conversion():
    """Test the exact CompanyAddress case provided by the user."""
    service = AssessmentService()

    # This is the exact data structure from the user's example
    assessment_data = {
        "YTDCityTax": {
            "confidence": 1.0,
            "confidence_reason": "Clear text with high OCR confidence, easily identifiable location",
            "bbox": [449, 450, 507, 462],
            "page": 1,
        },
        "currency": {
            "confidence": 0.0,
            "confidence_reason": "No clear evidence or text found for this attribute in the document",
            # No bbox data
        },
        "is_gross_pay_valid": {
            "confidence": 0.0,
            "confidence_reason": "No clear evidence or text found for this attribute in the document",
            # No bbox data
        },
        "CompanyAddress": {
            "State": {
                "confidence": 0.99,
                "confidence_reason": "Clear text with high OCR confidence, easily identifiable location",
                "bbox": [230, 116, 259, 126],
                "page": 1,
            },
            "ZipCode": {
                "confidence": 0.99,
                "confidence_reason": "Clear text with high OCR confidence, easily identifiable location",
                "bbox": [261, 116, 298, 126],
                "page": 1,
            },
        },
    }

    # Process the assessment data
    result = service._extract_geometry_from_assessment(assessment_data)

    print("=== Before/After Comparison ===")
    print("\nBEFORE (with bbox):")
    print(json.dumps(assessment_data["CompanyAddress"], indent=2))

    print("\nAFTER (with geometry):")
    print(json.dumps(result["CompanyAddress"], indent=2))

    # Verify the fix worked
    company_address = result["CompanyAddress"]

    # State should be converted from bbox to geometry
    state = company_address["State"]
    assert "geometry" in state, "State should have geometry field"
    assert "bbox" not in state, "State should not have raw bbox field"
    assert "page" not in state, "State should not have raw page field"
    assert state["confidence"] == 0.99

    state_geometry = state["geometry"][0]
    assert state_geometry["page"] == 1
    assert state_geometry["boundingBox"]["top"] == 0.116  # 116/1000
    assert state_geometry["boundingBox"]["left"] == 0.23  # 230/1000
    assert state_geometry["boundingBox"]["width"] == 0.029  # (259-230)/1000
    assert state_geometry["boundingBox"]["height"] == 0.01  # (126-116)/1000

    # ZipCode should be converted from bbox to geometry
    zip_code = company_address["ZipCode"]
    assert "geometry" in zip_code, "ZipCode should have geometry field"
    assert "bbox" not in zip_code, "ZipCode should not have raw bbox field"
    assert "page" not in zip_code, "ZipCode should not have raw page field"
    assert zip_code["confidence"] == 0.99

    zip_geometry = zip_code["geometry"][0]
    assert zip_geometry["page"] == 1
    assert zip_geometry["boundingBox"]["left"] == 0.261  # 261/1000
    assert zip_geometry["boundingBox"]["width"] == 0.037  # (298-261)/1000

    # YTDCityTax (top-level) should still work
    ytd_tax = result["YTDCityTax"]
    assert "geometry" in ytd_tax
    assert "bbox" not in ytd_tax
    assert ytd_tax["confidence"] == 1.0

    # currency (no bbox) should pass through unchanged
    currency = result["currency"]
    assert "geometry" not in currency
    assert "bbox" not in currency
    assert currency["confidence"] == 0.0

    print("\n✅ CompanyAddress nested geometry conversion works correctly!")
    print("✅ State and ZipCode now have proper geometry format")
    print("✅ All other attributes processed correctly")

    return True


if __name__ == "__main__":
    test_company_address_geometry_conversion()
