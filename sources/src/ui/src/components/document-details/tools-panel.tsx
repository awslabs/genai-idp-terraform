// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Document Details</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/web-ui/`} target="_blank" rel="noopener noreferrer">
              Web UI
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
          <li>
            <a href={`${DOCS_BASE_URL}/assessment/`} target="_blank" rel="noopener noreferrer">
              Assessment
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/human-review/`} target="_blank" rel="noopener noreferrer">
              Human Review
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>Inspect individual document processing results in detail.</p>
      <h3>Features</h3>
      <ul>
        <li>View document classification results and confidence scores</li>
        <li>Inspect extracted fields, values, and their assessment scores</li>
        <li>Review bounding box annotations overlaid on document pages</li>
        <li>Check human review status, reviewer notes, and correction history</li>
        <li>View raw OCR transcriptions and page-level content</li>
        <li>Examine rule validation and criteria validation results</li>
        <li>Access processing metadata including timestamps and configuration used</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
