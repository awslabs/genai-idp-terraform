// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Test Studio</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/test-studio/`} target="_blank" rel="noopener noreferrer">
              Test Studio
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/evaluation/`} target="_blank" rel="noopener noreferrer">
              Evaluation
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/evaluation-enhanced-reporting/`} target="_blank" rel="noopener noreferrer">
              Enhanced Reporting
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>Run tests, view results, and compare test outcomes to evaluate and improve document processing accuracy.</p>
      <h3>Features</h3>
      <ul>
        <li>
          <strong>Test Sets:</strong> Create and manage collections of test documents with expected results (ground truth)
        </li>
        <li>
          <strong>Executions:</strong> Run test sets against your current configuration and track progress in real time
        </li>
        <li>
          <strong>Results:</strong> Review detailed per-document and per-field accuracy metrics with enhanced reporting
        </li>
        <li>
          <strong>Comparison:</strong> Compare results across multiple test runs to measure the impact of configuration changes
        </li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
