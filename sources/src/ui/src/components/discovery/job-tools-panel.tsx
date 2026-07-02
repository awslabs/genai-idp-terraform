// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const JobToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Discovery Job Details</h2>}
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
        </ul>
      </div>
    }
  >
    <div>
      <p>View detailed results from a discovery job run.</p>
      <h3>Details</h3>
      <ul>
        <li>View detected document types and their characteristics</li>
        <li>Inspect discovered fields, layouts, and structural patterns</li>
        <li>Review generated classification and extraction configuration suggestions</li>
        <li>Apply discovery results to your IDP configuration</li>
      </ul>
    </div>
  </HelpPanel>
);

export default JobToolsPanel;
