// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

/* eslint-disable react/prop-types */
import React, { useState, useRef } from 'react';
import { API, Logger } from 'aws-amplify';
import { Button, Container, SpaceBetween, FormField, Alert } from '@awsui/components-react';
import chatWithDocument from '../../graphql/queries/chatWithDocument';
import './ChatPanel.css';

const logger = new Logger('chatWithDocument');

const getChatResponse = async (s3Uri, prompt) => {
  logger.debug('s3URI:', s3Uri);
  const response = await API.graphql({ query: chatWithDocument, variables: { s3Uri, prompt } });
  // logger.debug('response:', response);
  return response;
};

const modelOptions = [
  { value: 'vanilla', label: 'Nova Pro' },
  { value: 'strawberry', label: 'Claude 3.7' },
];

const ChatPanel = (item) => {
  const [error, setError] = useState(null);
  const [chatQueries, setChatQueries] = useState([]);
  const textareaRef = useRef(null);
  const { objectKey } = item;
  let rowId = 0;

  function generateId() {
    rowId += 1;
    return rowId;
  }

  const handlePromptSubmit = () => {
    const prompt = textareaRef.current.value;

    const chatRequestData = {
      role: 'user',
      content: prompt,
    };

    setChatQueries((prevChatQueries) => [...prevChatQueries, chatRequestData]);

    textareaRef.current.value = '';

    // logger.debug('key:', objectKey);

    const chatResponse = getChatResponse(objectKey, prompt);

    chatResponse.then((r) => {
      // logger.debug('r:', r);
      const cResponse = JSON.parse(r.data.chatWithDocument);
      // logger.debug('cResponse:', cResponse);
      // logger.debug('content', cResponse.cr.content[0].text);

      const chatResponseData = {
        role: 'ai',
        content: cResponse.cr.content[0].text,
      };

      setChatQueries((prevChatQueries) => [...prevChatQueries, chatResponseData]);

      const maxScrollHeight = document.documentElement.scrollHeight;
      window.scrollTo(0, maxScrollHeight);
    });

    setError(null);
  };

  return (
    <div id="chatDiv">
      <SpaceBetween size="l">
        <Container header={<h2>Chat With the Document</h2>}>
          {error && (
            <Alert type="error" dismissible onDismiss={() => setError(null)}>
              {error}
            </Alert>
          )}

          {chatQueries.length > 0 ? (
            chatQueries.map((post) => (
              <div className="chat-message-container" key={generateId()}>
                {post.role === 'user' ? (
                  <div className="chat-user">
                    <p>{post.content}</p>
                  </div>
                ) : (
                  <div className="chat-assistant">
                    <p>{post.content}</p>
                  </div>
                )}
              </div>
            ))
          ) : (
            <p>To start chatting to this document, enter your message below.</p>
          )}

          <FormField label="Your message" className="chat-composer-container">
            <textarea name="postContent" ref={textareaRef} rows={6} className="chat-textarea" id="chatTextarea" />
          </FormField>

          <FormField label="Model">
            <select name="model" id="modelSelect">
              {modelOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </FormField>

          <Button variant="primary" onClick={handlePromptSubmit}>
            Send
          </Button>
        </Container>
      </SpaceBetween>
    </div>
  );
};

export default ChatPanel;
