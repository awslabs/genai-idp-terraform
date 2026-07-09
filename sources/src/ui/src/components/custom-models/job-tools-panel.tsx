// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const JobToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Fine-Tuning Job Details</h2>}
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
        </ul>
      </div>
    }
  >
    <div>
      <p>View detailed information about a specific fine-tuning job.</p>
      <h3>Details</h3>
      <ul>
        <li>View training job status, progress, and configuration</li>
        <li>Monitor training metrics such as loss and accuracy</li>
        <li>Review training data details and hyperparameters used</li>
        <li>Access the fine-tuned model output for deployment</li>
      </ul>
    </div>
  </HelpPanel>
);

export default JobToolsPanel;
