# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Code interpreter tools for analytics agents.
"""

import json
import logging

import boto3
from bedrock_agentcore.tools.code_interpreter_client import CodeInterpreter
from strands import tool

logger = logging.getLogger(__name__)


class CodeInterpreterTools:
    """Tools for managing code interpreter operations."""

    def __init__(self, session: boto3.Session, region: str = "us-west-2"):
        """
        Initialize the code interpreter tools.

        Args:
            session: Boto3 session for AWS operations
            region: AWS region for code interpreter
        """
        self.session = session
        self.region = region
        self._code_client = None

    def _get_code_interpreter_client(self):
        """Get or create the code interpreter client."""
        if self._code_client is None:
            self._code_client = CodeInterpreter(self.region)
            self._code_client.start()
            logger.info(f"Started code interpreter client in region {self.region}")
        return self._code_client

    def _invoke_code_interpreter_tool(self, tool_name: str, arguments: dict) -> dict:
        """Invoke a code interpreter tool and return the result."""
        client = self._get_code_interpreter_client()
        response = client.invoke(tool_name, arguments)
        for event in response["stream"]:
            return json.loads(json.dumps(event["result"], indent=2))

    def cleanup(self):
        """Clean up the code interpreter session."""
        if self._code_client:
            logger.info("Cleaning up code interpreter session...")
            self._code_client.stop()
            self._code_client = None

    @tool
    def write_query_results_to_code_sandbox(self, s3_uri: str) -> str:
        """
        Download CSV from S3 and write it to the code interpreter environment.
        Must always be called before any execute_python functions can be called.

        Args:
            s3_uri: S3 URI of the CSV file to download

        Returns:
            Success message indicating the file was written to the sandbox
        """
        filename = "query_results.csv"
        logger.info(
            f"Downloading CSV from S3 and writing to code interpreter: {filename}"
        )

        # Parse S3 URI
        if not s3_uri.startswith("s3://"):
            raise ValueError("Invalid S3 URI format")

        # Remove s3:// prefix and split bucket and key
        s3_path = s3_uri[5:]  # Remove 's3://'
        bucket_name, key = s3_path.split("/", 1)

        logger.debug(f"Bucket: {bucket_name}, Key: {key}")

        # Download from S3 using boto3
        s3_client = self.session.client("s3")

        try:
            # Download the CSV content
            response = s3_client.get_object(Bucket=bucket_name, Key=key)
            csv_content = response["Body"].read().decode("utf-8")

            logger.debug(f"Successfully downloaded CSV ({len(csv_content)} characters)")

            # Prepare files to create in code interpreter
            files_to_create = [{"path": filename, "text": csv_content}]

            # Write the file to the code interpreter environment
            writing_files = self._invoke_code_interpreter_tool(
                "writeFiles", {"content": files_to_create}
            )
            logger.debug(f"Writing files result: {writing_files}")

            # List files to verify
            listing_files = self._invoke_code_interpreter_tool(
                "listFiles", {"path": ""}
            )
            logger.debug(f"Files in code interpreter: {listing_files}")

            return f"CSV file '{filename}' successfully written to code interpreter environment"

        except Exception as e:
            logger.error(
                f"Error downloading from S3 or writing to code interpreter: {str(e)}"
            )
            raise

    @tool
    def execute_python(self, code: str, description: str = "") -> str:
        """
        Execute Python code in the code interpreter sandbox.

        Args:
            code: Python code to execute
            description: Optional description of what the code does

        Returns:
            JSON string containing the execution result
        """
        if description:
            code = f"# {description}\n{code}"

        logger.debug(f"Executing Python code: {description}")
        logger.debug(f"Code:\n{code}")

        try:
            # Execute code using the invoke_code_interpreter_tool helper
            result = self._invoke_code_interpreter_tool(
                "executeCode",
                {"code": code, "language": "python", "clearContext": False},
            )

            return json.dumps(result, indent=2)

        except Exception as e:
            logger.error(f"Error executing code: {str(e)}")
            raise
