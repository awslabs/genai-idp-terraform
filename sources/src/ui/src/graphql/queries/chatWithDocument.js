// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import gql from 'graphql-tag';

export default gql`
  query Query($s3Uri: String!, $prompt: String!) {
    chatWithDocument(s3Uri: $s3Uri, prompt: $prompt)
  }
`;
