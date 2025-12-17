// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import { gql } from 'graphql-tag';

export default gql`
  query ListAnalyticsJobs($limit: Int, $nextToken: String) {
    listAnalyticsJobs(limit: $limit, nextToken: $nextToken) {
      items {
        jobId
        status
        query
        createdAt
        completedAt
      }
      nextToken
    }
  }
`;
