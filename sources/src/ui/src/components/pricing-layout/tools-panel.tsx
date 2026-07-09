// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Pricing</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/cost-calculator/`} target="_blank" rel="noopener noreferrer">
              Cost Calculator
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>View and manage service pricing used for document processing cost calculations.</p>
      <h3>Features</h3>
      <ul>
        <li>View current unit prices for AWS services used in document processing</li>
        <li>Edit pricing entries to reflect your account-specific pricing or negotiated rates</li>
        <li>Edit pricing configuration in YAML or JSON using the built-in code editor</li>
        <li>Pricing data is used by the cost calculator to estimate per-document processing costs</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
