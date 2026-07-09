// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Document Knowledge Base Query</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/knowledge-base/`} target="_blank" rel="noopener noreferrer">
              Knowledge Base
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>Query your document collection using natural language, powered by Amazon Bedrock Knowledge Bases.</p>
      <h3>Features</h3>
      <ul>
        <li>Ask questions about documents in your knowledge base</li>
        <li>Get responses with citations to source documents</li>
        <li>Follow document links to view original source material</li>
      </ul>
      <h3>Tips</h3>
      <ul>
        <li>Be specific in your questions to get more accurate answers</li>
        <li>Questions are context-aware — you can ask follow-up questions</li>
        <li>Results are based on indexed document content</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
