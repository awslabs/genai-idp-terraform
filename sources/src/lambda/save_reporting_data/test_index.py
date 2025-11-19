"""
Unit tests for the save_reporting_data Lambda function.
"""

import pytest
import json
import datetime
import boto3
import io
from unittest.mock import patch, MagicMock
import pyarrow as pa
import pyarrow.parquet as pq

from index import handler, _serialize_value, _save_records_as_parquet

@pytest.mark.unit
def test_serialize_value_none():
    """Test serializing None value."""
    assert _serialize_value(None) is None

@pytest.mark.unit
def test_serialize_value_string():
    """Test serializing string value."""
    assert _serialize_value("test") == "test"

@pytest.mark.unit
def test_serialize_value_numeric():
    """Test serializing numeric values."""
    assert _serialize_value(123) == "123"
    assert _serialize_value(123.45) == "123.45"

@pytest.mark.unit
def test_serialize_value_boolean():
    """Test serializing boolean values."""
    assert _serialize_value(True) == "True"
    assert _serialize_value(False) == "False"

@pytest.mark.unit
def test_serialize_value_list():
    """Test serializing list value."""
    assert _serialize_value([1, 2, 3]) == "[1, 2, 3]"

@pytest.mark.unit
def test_serialize_value_dict():
    """Test serializing dictionary value."""
    assert _serialize_value({"key": "value"}) == '{"key": "value"}'

@pytest.mark.unit
def test_serialize_value_other():
    """Test serializing other types."""
    class TestClass:
        def __str__(self):
            return "TestClass"
    
    assert _serialize_value(TestClass()) == "TestClass"

@pytest.mark.unit
@patch('boto3.client')
def test_save_records_as_parquet(mock_boto3_client):
    """Test saving records as Parquet."""
    # Mock S3 client
    mock_s3_client = MagicMock()
    mock_boto3_client.return_value = mock_s3_client
    
    # Test data
    records = [{"id": 1, "name": "Test"}]
    schema = pa.schema([('id', pa.int64()), ('name', pa.string())])
    
    # Call function
    _save_records_as_parquet(records, "test-bucket", "test-key", mock_s3_client, schema)
    
    # Verify S3 put_object was called
    mock_s3_client.put_object.assert_called_once()
    call_args = mock_s3_client.put_object.call_args[1]
    assert call_args["Bucket"] == "test-bucket"
    assert call_args["Key"] == "test-key"
    assert call_args["ContentType"] == "application/octet-stream"
    assert isinstance(call_args["Body"], bytes)

@pytest.mark.unit
@patch('boto3.client')
def test_save_records_as_parquet_empty_records(mock_boto3_client, caplog):
    """Test saving empty records list."""
    # Mock S3 client
    mock_s3_client = MagicMock()
    mock_boto3_client.return_value = mock_s3_client
    
    # Test data
    records = []
    schema = pa.schema([('id', pa.int64()), ('name', pa.string())])
    
    # Call function
    _save_records_as_parquet(records, "test-bucket", "test-key", mock_s3_client, schema)
    
    # Verify S3 put_object was not called
    mock_s3_client.put_object.assert_not_called()
    assert "No records to save" in caplog.text

@pytest.mark.unit
@patch('boto3.client')
def test_handler_success(mock_boto3_client):
    """Test successful handler execution."""
    # Mock S3 client
    mock_s3_client = MagicMock()
    mock_boto3_client.return_value = mock_s3_client
    
    # Create test event
    event = {
        "document": {
            "id": "test-doc",
            "input_key": "test.pdf",
            "evaluation_result": {
                "overall_metrics": {
                    "accuracy": 0.9,
                    "precision": 0.8,
                    "recall": 0.7,
                    "f1_score": 0.75,
                    "false_alarm_rate": 0.1,
                    "false_discovery_rate": 0.2
                },
                "execution_time": 1.5,
                "section_results": [
                    {
                        "section_id": "section1",
                        "document_class": "invoice",
                        "metrics": {
                            "accuracy": 0.95,
                            "precision": 0.85,
                            "recall": 0.75,
                            "f1_score": 0.8,
                            "false_alarm_rate": 0.05,
                            "false_discovery_rate": 0.15
                        },
                        "attributes": [
                            {
                                "name": "total",
                                "expected": "100.00",
                                "actual": "100.00",
                                "matched": True,
                                "score": 1.0,
                                "reason": "Exact match",
                                "evaluation_method": "exact",
                                "confidence": "high"
                            }
                        ]
                    }
                ]
            }
        },
        "reporting_bucket": "test-reporting-bucket"
    }
    
    # Call handler
    with patch('pyarrow.Table.from_pylist') as mock_from_pylist:
        mock_table = MagicMock()
        mock_from_pylist.return_value = mock_table
        
        with patch('pyarrow.parquet.write_table') as mock_write_table:
            response = handler(event, {})
            
            # Verify response
            assert response["statusCode"] == 200
            assert "Successfully saved" in response["body"]
            
            # Verify S3 put_object was called at least once
            assert mock_s3_client.put_object.call_count >= 1

@pytest.mark.unit
def test_handler_missing_document():
    """Test handler with missing document."""
    event = {
        "reporting_bucket": "test-reporting-bucket"
    }
    
    response = handler(event, {})
    
    assert response["statusCode"] == 400
    assert "No document data provided" in response["body"]

@pytest.mark.unit
def test_handler_missing_reporting_bucket():
    """Test handler with missing reporting bucket."""
    event = {
        "document": {
            "id": "test-doc"
        }
    }
    
    response = handler(event, {})
    
    assert response["statusCode"] == 400
    assert "No reporting bucket specified" in response["body"]

@pytest.mark.unit
def test_handler_no_evaluation_result():
    """Test handler with document that has no evaluation result."""
    event = {
        "document": {
            "id": "test-doc",
            "input_key": "test.pdf"
        },
        "reporting_bucket": "test-reporting-bucket"
    }
    
    response = handler(event, {})
    
    assert response["statusCode"] == 200
    assert "No evaluation results to save" in response["body"]

@pytest.mark.unit
@patch('boto3.client')
def test_handler_exception(mock_boto3_client):
    """Test handler with exception."""
    # Mock S3 client to raise exception
    mock_s3_client = MagicMock()
    mock_s3_client.put_object.side_effect = Exception("Test exception")
    mock_boto3_client.return_value = mock_s3_client
    
    # Create test event
    event = {
        "document": {
            "id": "test-doc",
            "input_key": "test.pdf",
            "evaluation_result": {
                "overall_metrics": {
                    "accuracy": 0.9
                },
                "section_results": []
            }
        },
        "reporting_bucket": "test-reporting-bucket"
    }
    
    # Call handler
    response = handler(event, {})
    
    # Verify response
    assert response["statusCode"] == 500
    assert "Error saving evaluation results" in response["body"]
