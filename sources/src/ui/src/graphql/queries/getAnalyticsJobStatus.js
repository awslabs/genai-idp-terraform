// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import { gql } from 'graphql-tag';

export default gql`
  query GetAnalyticsJobStatus($jobId: ID!) {
    getAnalyticsJobStatus(jobId: $jobId) {
      jobId
      status
      query
      createdAt
      completedAt
      result
      error
      agent_messages
    }
  }
`;
