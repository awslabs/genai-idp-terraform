// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import { gql } from 'graphql-tag';

export default gql`
  subscription OnAgentJobComplete($jobId: ID!) {
    onAgentJobComplete(jobId: $jobId)
  }
`;
