# Save Reporting Data Lambda

This Lambda function is responsible for saving document evaluation data to the reporting bucket in Parquet format. It's designed to be a standalone function that can be invoked by the EvaluationFunction or other components that need to save evaluation data.

## Purpose

The function takes a serialized Document object and saves its evaluation data to the reporting bucket in three separate Parquet files:

1. Document level metrics
2. Section level metrics
3. Attribute level metrics

## Input

The function expects an event with the following structure:

```json
{
  "document": {
    // Serialized Document object with evaluation results
  },
  "reporting_bucket": "reporting-bucket-name"
}
```

## Output

The function returns a response with the following structure:

```json
{
  "statusCode": 200,
  "body": "Successfully saved evaluation data to reporting bucket"
}
```

## Error Handling

If an error occurs, the function will return a response with a non-200 status code and an error message:

```json
{
  "statusCode": 500,
  "body": "Error saving evaluation results to reporting bucket: <error message>"
}
```

## Dependencies

- boto3: AWS SDK for Python
- pyarrow: Library for working with Arrow columnar format and Parquet files
