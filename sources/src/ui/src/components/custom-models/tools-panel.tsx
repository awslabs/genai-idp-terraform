// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Custom Models</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/custom-model-finetuning/`} target="_blank" rel="noopener noreferrer">
              Custom Model Fine-Tuning
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/nova-finetuning/`} target="_blank" rel="noopener noreferrer">
              Nova Fine-Tuning
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>Fine-tune custom models to improve document processing accuracy for your specific document types.</p>
      <h3>Features</h3>
      <ul>
        <li>Launch fine-tuning jobs using your document processing results as training data</li>
        <li>Track training job progress, status, and metrics</li>
        <li>Compare model performance before and after fine-tuning</li>
        <li>Manage fine-tuned model deployments and versions</li>
        <li>Supports Amazon Nova and other Bedrock model fine-tuning</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
