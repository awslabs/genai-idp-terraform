// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import { gql } from 'graphql-tag';

export default gql`
  query ListAgentJobs($limit: Int, $nextToken: String) {
    listAgentJobs(limit: $limit, nextToken: $nextToken) {
      items {
        jobId
        status
        query
        agentIds
        createdAt
        completedAt
      }
      nextToken
    }
  }
`;
