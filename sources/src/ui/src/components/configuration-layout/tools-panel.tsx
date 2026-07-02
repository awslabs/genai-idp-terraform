// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Configuration</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/configuration/`} target="_blank" rel="noopener noreferrer">
              Configuration
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/configuration-versions/`} target="_blank" rel="noopener noreferrer">
              Configuration Versions
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/idp-configuration-best-practices/`} target="_blank" rel="noopener noreferrer">
              Configuration Best Practices
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/json-schema-migration/`} target="_blank" rel="noopener noreferrer">
              JSON Schema Migration
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>
        Edit and manage the IDP processing configuration. Default values are set by the system during deployment. Any customized values will
        override the defaults.
      </p>
      <h3>Features</h3>
      <ul>
        <li>Edit configuration in YAML or JSON using the built-in code editor</li>
        <li>Use the visual Config Builder to construct configurations without writing code</li>
        <li>Manage configuration versions — compare, restore, or roll back changes</li>
        <li>Import pre-built configurations from the Configuration Library</li>
        <li>Sync configuration with BDA (Business Document Automation) projects</li>
        <li>Reset customized values back to system defaults</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
