// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';
import { SUPPORTED_UPLOAD_FORMATS_LABEL } from '../common/constants';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Upload Documents</h2>}
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
            <a href={`${DOCS_BASE_URL}/ocr-image-sizing-guide/`} target="_blank" rel="noopener noreferrer">
              OCR &amp; Image Sizing Guide
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>Upload documents to be processed by the IDP system.</p>
      <h3>Details</h3>
      <ul>
        <li>{SUPPORTED_UPLOAD_FORMATS_LABEL}</li>
        <li>
          <strong>Prefix:</strong> Optionally add a prefix to organize your documents (e.g., &quot;invoices/&quot;, &quot;forms/2023/&quot;)
        </li>
        <li>
          After upload, documents are automatically added to the processing queue and appear in the Documents list when processing begins
        </li>
        <li>Multiple files can be uploaded simultaneously</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
