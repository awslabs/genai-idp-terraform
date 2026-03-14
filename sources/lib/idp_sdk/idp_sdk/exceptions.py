# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
IDP SDK Exceptions

Custom exception classes for the IDP SDK.
"""


class IDPError(Exception):
    """Base exception for all IDP SDK errors."""

    pass


class IDPConfigurationError(IDPError):
    """
    Raised when SDK is misconfigured.

    Examples:
        - stack_name required but not provided
        - Invalid region
        - Missing credentials
    """

    pass


class IDPStackError(IDPError):
    """
    Raised when there's an issue with the CloudFormation stack.

    Examples:
        - Stack not found
        - Stack in invalid state
        - Stack operation failed
    """

    pass


class IDPProcessingError(IDPError):
    """
    Raised when document processing fails.

    Examples:
        - Batch processing failure
        - Document upload failure
        - S3 operation failure
    """

    pass


class IDPValidationError(IDPError):
    """
    Raised when validation fails.

    Examples:
        - Invalid manifest format
        - Invalid configuration
        - Missing required fields
    """

    pass


class IDPResourceNotFoundError(IDPError):
    """
    Raised when a requested resource is not found.

    Examples:
        - Batch not found
        - Document not found
        - Test set not found
    """

    pass


class IDPTimeoutError(IDPError):
    """
    Raised when an operation times out.

    Examples:
        - Stack deployment timeout
        - Monitoring timeout
    """

    pass
