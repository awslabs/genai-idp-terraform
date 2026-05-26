# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Lambda function for user management operations with DynamoDB storage and Cognito sync."""

import logging
import os
import re
import uuid
from datetime import datetime

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

dynamodb = boto3.resource("dynamodb")
cognito = boto3.client("cognito-idp")

USERS_TABLE_NAME = os.environ.get("USERS_TABLE_NAME", "")
USER_POOL_ID = os.environ.get("USER_POOL_ID", "")
ADMIN_GROUP = os.environ.get("ADMIN_GROUP", "Admin")
REVIEWER_GROUP = os.environ.get("REVIEWER_GROUP", "Reviewer")
ALLOWED_SIGNUP_EMAIL_DOMAINS = os.environ.get("ALLOWED_SIGNUP_EMAIL_DOMAINS", "")


def handler(event, context):
    """Handle user management operations from AppSync."""
    logger.info(f"Received event: {event}")

    field = event.get("info", {}).get("fieldName", "")
    arguments = event.get("arguments", {})

    if field == "createUser":
        return create_user(arguments)
    elif field == "deleteUser":
        return delete_user(arguments)
    elif field == "listUsers":
        return list_users()

    raise ValueError(f"Unknown operation: {field}")


def create_user(args):
    """Create user in DynamoDB and sync to Cognito."""
    email = args["email"]
    persona = args["persona"]
    user_id = str(uuid.uuid4())

    # Validate email format
    email_pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if not re.match(email_pattern, email):
        raise ValueError(f"Invalid email format: {email}")

    # Validate email domain if restrictions are configured
    if ALLOWED_SIGNUP_EMAIL_DOMAINS and ALLOWED_SIGNUP_EMAIL_DOMAINS.strip():
        allowed_domains = [
            d.strip().lower() for d in ALLOWED_SIGNUP_EMAIL_DOMAINS.split(",") if d.strip()
        ]
        if allowed_domains:  # Only validate if there are actual domains configured
            if "@" not in email:
                raise ValueError(f"Invalid email format: {email}")
            email_domain = email.split("@")[1].lower()
            if email_domain not in allowed_domains:
                raise ValueError(
                    f"Email domain '{email_domain}' is not allowed. "
                    f"Allowed domains: {', '.join(allowed_domains)}"
                )

    # Validate persona
    if persona not in ["Admin", "Reviewer"]:
        raise ValueError(f"Invalid persona: {persona}. Must be 'Admin' or 'Reviewer'")

    logger.info(f"Creating user with email {email} and persona {persona}")

    table = dynamodb.Table(USERS_TABLE_NAME)

    # Check if user already exists
    existing_users = table.query(
        IndexName="EmailIndex", KeyConditionExpression=Key("email").eq(email)
    )

    if existing_users.get("Items"):
        raise ValueError(f"User with email {email} already exists")

    # Create user record in DynamoDB
    user_record = {
        "PK": f"USER#{user_id}",
        "SK": f"USER#{user_id}",
        "userId": user_id,
        "email": email,
        "persona": persona,
        "status": "active",
        "createdAt": datetime.utcnow().isoformat() + "Z",
        "updatedAt": datetime.utcnow().isoformat() + "Z",
    }

    table.put_item(Item=user_record)

    # Sync to Cognito
    try:
        sync_user_to_cognito(user_id, email, persona, "create")
    except Exception as e:
        logger.error(f"Failed to sync user to Cognito: {e}")
        # Rollback DynamoDB record
        table.delete_item(Key={"PK": f"USER#{user_id}", "SK": f"USER#{user_id}"})
        raise e

    logger.info(f"User {email} created successfully")
    return {
        "userId": user_id,
        "email": email,
        "persona": persona,
        "status": "active",
        "createdAt": user_record["createdAt"],
    }


def delete_user(args):
    """Delete user from DynamoDB and sync to Cognito."""
    user_id = args["userId"]

    logger.info(f"Deleting user {user_id}")

    table = dynamodb.Table(USERS_TABLE_NAME)

    # Get user record
    response = table.get_item(Key={"PK": f"USER#{user_id}", "SK": f"USER#{user_id}"})

    if not response.get("Item"):
        raise ValueError(f"User {user_id} not found")

    user_record = response["Item"]
    email = user_record["email"]

    # Delete from DynamoDB
    table.delete_item(Key={"PK": f"USER#{user_id}", "SK": f"USER#{user_id}"})

    # Sync to Cognito
    try:
        sync_user_to_cognito(user_id, email, user_record["persona"], "delete")
    except Exception as e:
        logger.warning(f"Failed to sync user deletion to Cognito: {e}")
        # Continue with deletion as DynamoDB is the source of truth

    logger.info(f"User {user_id} deleted successfully")
    return True


def format_datetime(dt_str):
    """Ensure datetime string is valid ISO 8601 with Z suffix for AppSync."""
    if not dt_str:
        return None
    # Remove any existing timezone offset (+00:00) and trailing Z
    dt_str = dt_str.replace("+00:00", "").rstrip("Z")
    return dt_str + "Z"


def list_users():
    """List all users - sync from Cognito first, then return from DynamoDB."""
    logger.info("Listing all users")

    # First, sync Cognito users to DynamoDB
    sync_cognito_users_to_dynamodb()

    table = dynamodb.Table(USERS_TABLE_NAME)

    # Scan for all user records
    response = table.scan(
        FilterExpression="begins_with(PK, :pk_prefix)",
        ExpressionAttributeValues={":pk_prefix": "USER#"},
    )

    users = []
    for item in response.get("Items", []):
        users.append(
            {
                "userId": item["userId"],
                "email": item["email"],
                "persona": item["persona"],
                "status": item.get("status", "active"),
                "createdAt": format_datetime(item.get("createdAt")),
            }
        )

    # Sort by creation date (newest first)
    users.sort(key=lambda x: x.get("createdAt") or "", reverse=True)

    logger.info(f"Found {len(users)} users")
    return {"users": users}


def sync_cognito_users_to_dynamodb():
    """Sync existing Cognito users to DynamoDB table."""
    logger.info("Syncing Cognito users to DynamoDB")

    table = dynamodb.Table(USERS_TABLE_NAME)

    # Get existing emails in DynamoDB for quick lookup
    existing_response = table.scan(
        FilterExpression="begins_with(PK, :pk_prefix)",
        ExpressionAttributeValues={":pk_prefix": "USER#"},
        ProjectionExpression="email",
    )
    existing_emails = {item["email"] for item in existing_response.get("Items", [])}

    # List all Cognito users
    paginator = cognito.get_paginator("list_users")

    for page in paginator.paginate(UserPoolId=USER_POOL_ID):
        for user in page.get("Users", []):
            username = user["Username"]

            # Get email from attributes
            email = username
            for attr in user.get("Attributes", []):
                if attr["Name"] == "email":
                    email = attr["Value"]
                    break

            # Skip if already in DynamoDB
            if email in existing_emails:
                continue

            # Get user's groups to determine persona
            try:
                groups_response = cognito.admin_list_groups_for_user(
                    Username=username, UserPoolId=USER_POOL_ID
                )
                persona = "Reviewer"
                for group in groups_response.get("Groups", []):
                    if group["GroupName"] == ADMIN_GROUP:
                        persona = "Admin"
                        break
            except Exception as e:
                logger.warning(f"Could not get groups for user {username}: {e}")
                persona = "Reviewer"

            # Create user record in DynamoDB
            user_id = str(uuid.uuid4())
            if user.get("UserCreateDate"):
                # Convert to UTC and format without timezone offset
                dt = user["UserCreateDate"]
                created_at = dt.strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"
            else:
                created_at = datetime.utcnow().isoformat() + "Z"

            user_record = {
                "PK": f"USER#{user_id}",
                "SK": f"USER#{user_id}",
                "userId": user_id,
                "email": email,
                "persona": persona,
                "status": "active",
                "createdAt": created_at,
                "updatedAt": datetime.utcnow().isoformat() + "Z",
            }

            table.put_item(Item=user_record)
            logger.info(f"Synced Cognito user {email} to DynamoDB")


def sync_user_to_cognito(user_id, email, persona, operation):
    """Sync user operations to Cognito."""
    if operation == "create":
        # Create user in Cognito
        cognito.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=email,
            UserAttributes=[
                {"Name": "email", "Value": email},
                {"Name": "email_verified", "Value": "true"},
            ],
            DesiredDeliveryMediums=["EMAIL"],
        )

        # Add to appropriate group
        group_name = ADMIN_GROUP if persona.lower() == "admin" else REVIEWER_GROUP
        cognito.admin_add_user_to_group(
            UserPoolId=USER_POOL_ID, Username=email, GroupName=group_name
        )

        logger.info(f"User {email} synced to Cognito and added to group {group_name}")

    elif operation == "delete":
        # Delete user from Cognito
        try:
            cognito.admin_delete_user(UserPoolId=USER_POOL_ID, Username=email)
            logger.info(f"User {email} deleted from Cognito")
        except cognito.exceptions.UserNotFoundException:
            logger.warning(f"User {email} not found in Cognito during deletion")
