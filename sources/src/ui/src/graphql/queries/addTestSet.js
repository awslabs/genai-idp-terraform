// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

const ADD_TEST_SET = `
  mutation AddTestSet($name: String!, $filePattern: String!, $bucketType: String!, $fileCount: Int!) {
    addTestSet(name: $name, filePattern: $filePattern, bucketType: $bucketType, fileCount: $fileCount) {
      id
      name
      filePattern
      fileCount
      createdAt
    }
  }
`;

export default ADD_TEST_SET;
