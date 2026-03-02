// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

// Generic Agent Chat Queries
export const SEND_AGENT_MESSAGE = /* GraphQL */ `
  mutation SendAgentChatMessage($prompt: String!, $sessionId: String, $method: String, $enableCodeIntelligence: Boolean) {
    sendAgentChatMessage(prompt: $prompt, sessionId: $sessionId, method: $method, enableCodeIntelligence: $enableCodeIntelligence) {
      role
      content
      timestamp
      isProcessing
      sessionId
      messageType
      toolMetadata {
        toolName
        toolUseId
      }
    }
  }
`;

export const ON_AGENT_MESSAGE_UPDATE = /* GraphQL */ `
  subscription OnAgentChatMessageUpdate($sessionId: String!) {
    onAgentChatMessageUpdate(sessionId: $sessionId) {
      role
      content
      timestamp
      isProcessing
      sessionId
      messageType
      toolMetadata {
        toolName
        toolUseId
      }
    }
  }
`;

// Agent management queries
export const LIST_AVAILABLE_AGENTS = /* GraphQL */ `
  query ListAvailableAgents {
    listAvailableAgents {
      agent_id
      agent_name
      agent_description
      sample_queries
    }
  }
`;

export const SUBMIT_AGENT_QUERY = /* GraphQL */ `
  mutation SubmitAgentQuery($query: String!, $agentIds: [String!]!) {
    submitAgentQuery(query: $query, agentIds: $agentIds) {
      jobId
      status
      query
      agentIds
      createdAt
    }
  }
`;

export const GET_AGENT_JOB_STATUS = /* GraphQL */ `
  query GetAgentJobStatus($jobId: ID!) {
    getAgentJobStatus(jobId: $jobId) {
      jobId
      status
      query
      agentIds
      createdAt
      completedAt
      result
      error
      agent_messages
    }
  }
`;

export const ON_AGENT_JOB_COMPLETE = /* GraphQL */ `
  subscription OnAgentJobComplete($jobId: ID!) {
    onAgentJobComplete(jobId: $jobId)
  }
`;
