# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""Unit tests for S3Util.s3_url_to_bucket_key URI parsing."""

import pytest
from idp_common.utils.s3util import S3Util


class TestS3UrlToBucketKey:
    """Parsing s3:// URIs into (bucket, key)."""

    def test_simple_key(self):
        bucket, key = S3Util.s3_url_to_bucket_key("s3://my-bucket/path/to/file.json")
        assert bucket == "my-bucket"
        assert key == "path/to/file.json"

    def test_hash_in_key_is_preserved(self):
        """Regression: keys containing '#' must not be truncated.

        s3_url_to_bucket_key previously used urllib.parse.urlparse, which treats
        '#' as a fragment delimiter and dropped everything after it — turning
        's3://bkt/Borrowing_Notice_#2.pdf/pages/1/result.json' into key
        'Borrowing_Notice_' and causing NoSuchKey on GetObject.
        """
        bucket, key = S3Util.s3_url_to_bucket_key(
            "s3://bkt/Borrowing_Notice_#2.pdf/pages/1/result.json"
        )
        assert bucket == "bkt"
        assert key == "Borrowing_Notice_#2.pdf/pages/1/result.json"

    def test_other_special_chars_preserved(self):
        # '?' (query delimiter) and spaces are also mishandled by urlparse.
        bucket, key = S3Util.s3_url_to_bucket_key(
            "s3://bkt/dir/file with spaces #1 (v2)?.pdf/result.json"
        )
        assert bucket == "bkt"
        assert key == "dir/file with spaces #1 (v2)?.pdf/result.json"

    def test_invalid_scheme_raises(self):
        with pytest.raises(ValueError):
            S3Util.s3_url_to_bucket_key("https://bkt/key.json")

    def test_missing_key_raises(self):
        with pytest.raises(ValueError):
            S3Util.s3_url_to_bucket_key("s3://bkt")
