#!/usr/bin/env python3
"""
Polls S3 until model.tar.gz actually exists before Terraform proceeds.
Terraform external data source passes query as JSON on stdin.
"""

import json
import sys
import time


def output(data):
    """Print JSON to stdout and flush — required by Terraform external data source."""
    print(json.dumps(data))
    sys.stdout.flush()


def fail(message, attempts=0):
    """Terraform external data source must always print JSON to stdout, never just exit."""
    output({'exists': 'false', 'attempts': str(attempts), 'message': message})
    sys.exit(1)


try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    fail('boto3 not installed. Run: pip install boto3')


def main():
    # Terraform external data source sends query as JSON on stdin
    try:
        query = json.load(sys.stdin)
    except Exception as e:
        fail(f'Failed to parse stdin JSON: {e}')

    bucket = query.get('bucket', '')
    key = query.get('key', '')
    max_attempts = int(query.get('max_attempts', '40'))
    region = "${region}"

    if not bucket or not key:
        fail('bucket and key are required inputs')

    try:
        s3 = boto3.client('s3', region_name=region)
    except Exception as e:
        fail(f'Failed to create S3 client: {e}')

    for attempt in range(1, max_attempts + 1):
        try:
            s3.head_object(Bucket=bucket, Key=key)
            output({
                'exists': 'true',
                'attempts': str(attempt),
                'message': f's3://{bucket}/{key} confirmed after {attempt} attempt(s)'
            })
            return
        except ClientError as e:
            code = e.response['Error']['Code']
            if code in ('404', 'NoSuchKey'):
                if attempt < max_attempts:
                    time.sleep(30)
            else:
                fail(f'Unexpected S3 error ({code}): {e}', attempt)
        except Exception as e:
            fail(f'Unexpected error: {e}', attempt)

    fail(
        f's3://{bucket}/{key} not found after {max_attempts * 30 // 60} min ({max_attempts} attempts)',
        max_attempts
    )


if __name__ == '__main__':
    main()
