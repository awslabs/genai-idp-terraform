// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Discovery</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/discovery/`} target="_blank" rel="noopener noreferrer">
              Discovery
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/classification/`} target="_blank" rel="noopener noreferrer">
              Classification
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/extraction/`} target="_blank" rel="noopener noreferrer">
              Extraction
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>
        Run document discovery jobs to analyze document structure and content before configuring processing pipelines. Discovery helps you
        understand your documents and auto-generate initial configurations.
      </p>
      <h3>Features</h3>
      <ul>
        <li>Upload sample documents and run discovery analysis</li>
        <li>Automatically detect document types, layouts, and key fields</li>
        <li>Generate initial classification and extraction configurations</li>
        <li>Review discovery results to refine processing settings</li>
        <li>Track discovery job history and compare results across runs</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
