// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React, { useState, useEffect, useRef } from 'react';
import PropTypes from 'prop-types';
import { generateClient } from 'aws-amplify/api';
import { ConsoleLogger } from 'aws-amplify/utils';
import { ButtonDropdown, Button, Box } from '@cloudscape-design/components';

import {
  LIST_AGENT_CHAT_SESSIONS,
  DELETE_AGENT_CHAT_SESSION,
  GET_AGENT_CHAT_MESSAGES,
} from '../../graphql/queries/agentChatSessionQueries';

const client = generateClient();
const logger = new ConsoleLogger('AgentChatHistoryDropdown');

const AgentChatHistoryDropdown = ({ onSessionSelect, disabled = false, onSessionDeleted = () => {} }) => {
  const [chatSessions, setChatSessions] = useState([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [selectedOption, setSelectedOption] = useState(null);
  const [isDeletingSession, setIsDeletingSession] = useState(false);
  const lastFetchTimeRef = useRef(0);

  const fetchChatSessions = async (force = false) => {
    // Don't fetch if we're already loading
    if (isLoadingHistory) return;

    // Don't fetch too frequently unless forced
    const now = Date.now();
    if (!force && now - lastFetchTimeRef.current < 5000) {
      // 5 second cooldown
      logger.debug('Skipping fetch due to cooldown');
      return;
    }

    try {
      setIsLoadingHistory(true);
      lastFetchTimeRef.current = now;

      let response;
      try {
        response = await client.graphql({
          query: LIST_AGENT_CHAT_SESSIONS,
          variables: { limit: 20 }, // Limit to most recent 20 sessions
        });
      } catch (amplifyError) {
        // Amplify throws an exception when there are GraphQL errors, but the response might still contain valid data
        logger.warn('Amplify threw an exception due to GraphQL errors, checking for valid data:', amplifyError);

        // Check if the error object contains the actual response data
        if (amplifyError.data && amplifyError.data.listChatSessions) {
          logger.info('Found valid data in the error response, proceeding with processing');
          response = {
            data: amplifyError.data,
            errors: amplifyError.errors || [],
          };
        } else {
          // If there's no data in the error, re-throw to be handled by outer catch
          throw amplifyError;
        }
      }

      // Handle GraphQL errors gracefully - log them but continue processing valid data
      if (response.errors && response.errors.length > 0) {
        logger.warn(`Received ${response.errors.length} GraphQL errors in listChatSessions response:`, response.errors);
        logger.warn('Continuing to process valid data despite errors...');
      }

      // Get items array and filter out null values (corrupted items)
      const rawItems = response?.data?.listChatSessions?.items || [];
      const nonNullSessions = rawItems.filter((session) => session !== null);

      logger.debug(`Raw response: ${rawItems.length} total items, ${nonNullSessions.length} non-null items`);
      logger.debug('Non-null sessions data:', nonNullSessions);

      // Filter out any sessions with invalid or missing required fields
      const validSessions = nonNullSessions.filter((session) => {
        try {
          // Check if session has required fields
          if (!session || !session.sessionId || !session.title) {
            logger.warn('Filtering out session with missing required fields:', session);
            return false;
          }

          return true;
        } catch (e) {
          logger.warn(`Filtering out session with error: ${session?.sessionId || 'unknown'}`, e);
          return false;
        }
      });

      logger.debug(`Filtered to ${validSessions.length} valid sessions`);

      // Sort by updatedAt in descending order (newest first)
      const sortedSessions = [...validSessions].sort((a, b) => {
        try {
          // Try to parse dates and compare
          const dateA = a.updatedAt ? new Date(a.updatedAt) : new Date(0);
          const dateB = b.updatedAt ? new Date(b.updatedAt) : new Date(0);

          // Check if dates are valid
          if (Number.isNaN(dateA.getTime()) || Number.isNaN(dateB.getTime())) {
            // Fall back to string comparison if dates are invalid
            return (b.updatedAt || '').localeCompare(a.updatedAt || '');
          }

          return dateB.getTime() - dateA.getTime();
        } catch (e) {
          logger.warn('Error sorting sessions by date, using string comparison:', e);
          // Fall back to string comparison
          return (b.updatedAt || '').localeCompare(a.updatedAt || '');
        }
      });

      logger.debug('Final processed and sorted sessions:', sortedSessions);
      setChatSessions(sortedSessions);

      // Log summary of what we processed
      if (response.errors && response.errors.length > 0) {
        logger.info(
          `Successfully processed ${sortedSessions.length} valid sessions despite ${response.errors.length} GraphQL errors from corrupted items`,
        );
      } else {
        logger.info(`Successfully processed ${sortedSessions.length} sessions with no errors`);
      }
    } catch (err) {
      logger.error('Error fetching chat sessions:', err);
      // Only log as empty if it's a complete failure (network error, etc.)
      logger.error('Complete failure - setting empty history');
      setChatSessions([]);
    } finally {
      setIsLoadingHistory(false);
    }
  };

  // Fetch chat sessions when component mounts
  useEffect(() => {
    fetchChatSessions(true);
  }, []);

  const handleDropdownItemClick = async ({ detail }) => {
    console.log('Previous chat session clicked, detail:', detail);

    // Prevent dropdown item selection if a delete operation is in progress
    if (isDeletingSession) {
      console.log('Delete operation in progress, ignoring click');
      return;
    }

    const selectedSession = chatSessions.find((session) => session.sessionId === detail.id);
    console.log('Selected session:', selectedSession);

    if (selectedSession) {
      setSelectedOption({ value: selectedSession.sessionId, label: selectedSession.title });

      try {
        // Load the messages for this session
        const messagesResponse = await client.graphql({
          query: GET_AGENT_CHAT_MESSAGES,
          variables: { sessionId: selectedSession.sessionId },
        });

        const messages = messagesResponse?.data?.getChatMessages || [];
        console.log('Loaded messages for session:', messages);

        // Call the parent callback with session data and messages
        onSessionSelect(selectedSession, messages);
      } catch (error) {
        console.error('Failed to load messages for session:', error);
        logger.error('Failed to load messages for session:', error);
      }
    }
  };

  // Format date for display in dropdown
  const formatDate = (dateString) => {
    try {
      const date = new Date(dateString);
      // Check if date is valid
      if (Number.isNaN(date.getTime())) {
        return 'Unknown date';
      }
      return date.toLocaleString();
    } catch (e) {
      logger.warn(`Error formatting date: ${dateString}`, e);
      return 'Unknown date';
    }
  };

  // Create dropdown items with delete functionality
  const createDropdownItems = () => {
    if (chatSessions.length === 0) {
      return [{ text: 'No previous chat sessions found', disabled: true }];
    }

    return chatSessions.map((session) => {
      const displayText = session.title?.length > 50 ? `${session.title.substring(0, 50)}...` : session.title || 'Untitled Chat';
      const dateText = formatDate(session.updatedAt);

      return {
        id: session.sessionId,
        text: (
          <div style={{ display: 'flex', alignItems: 'center', width: '100%', minHeight: '40px' }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 'normal', marginBottom: '2px' }}>{displayText}</div>
              <div style={{ fontSize: '12px', color: '#5f6b7a' }}>
                {dateText} • {session.messageCount} messages
              </div>
            </div>
            <Button
              variant="icon"
              iconName="remove"
              onClick={async (e) => {
                e.preventDefault();
                e.stopPropagation();

                // Set flag to prevent dropdown item selection
                setIsDeletingSession(true);

                try {
                  await client.graphql({
                    query: DELETE_AGENT_CHAT_SESSION,
                    variables: {
                      sessionId: session.sessionId,
                    },
                  });

                  logger.debug('Successfully deleted session:', session.sessionId);

                  // Remove the deleted session from the local state
                  setChatSessions((prev) => prev.filter((historySession) => historySession.sessionId !== session.sessionId));

                  // If the deleted session was currently selected, clear the selection
                  if (selectedOption && selectedOption.value === session.sessionId) {
                    setSelectedOption(null);
                  }

                  // Notify parent component
                  onSessionDeleted(session.sessionId);
                } catch (err) {
                  logger.error('Error deleting session:', err);
                } finally {
                  // Reset the flag after a short delay to ensure event handling is complete
                  setTimeout(() => {
                    setIsDeletingSession(false);
                  }, 100);
                }
              }}
              ariaLabel={`Delete chat session: ${displayText}`}
            />
          </div>
        ),
        disabled: false,
      };
    });
  };

  return (
    <ButtonDropdown
      items={createDropdownItems()}
      onItemClick={handleDropdownItemClick}
      onFocus={() => fetchChatSessions()}
      loading={isLoadingHistory}
      disabled={disabled}
    >
      {(() => {
        if (!selectedOption) return 'Load previous chat';
        if (selectedOption.label?.length > 40) {
          return `${selectedOption.label.substring(0, 40)}...`;
        }
        return selectedOption.label || 'Selected chat';
      })()}
    </ButtonDropdown>
  );
};

AgentChatHistoryDropdown.propTypes = {
  onSessionSelect: PropTypes.func.isRequired,
  disabled: PropTypes.bool,
  onSessionDeleted: PropTypes.func,
};

export default AgentChatHistoryDropdown;
