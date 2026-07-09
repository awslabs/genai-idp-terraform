// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { HelpPanel, Icon } from '@cloudscape-design/components';

const DOCS_BASE_URL = 'https://aws-solutions-library-samples.github.io/accelerated-intelligent-document-processing-on-aws';

const ToolsPanel = (): React.JSX.Element => (
  <HelpPanel
    header={<h2>Capacity Planning</h2>}
    footer={
      <div>
        <h3>
          Learn more <Icon name="external" />
        </h3>
        <ul>
          <li>
            <a href={`${DOCS_BASE_URL}/capacity-planning/`} target="_blank" rel="noopener noreferrer">
              Capacity Planning
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/monitoring/`} target="_blank" rel="noopener noreferrer">
              Monitoring
            </a>
          </li>
          <li>
            <a href={`${DOCS_BASE_URL}/service-tiers/`} target="_blank" rel="noopener noreferrer">
              Service Tiers
            </a>
          </li>
        </ul>
      </div>
    }
  >
    <div>
      <p>Monitor and plan document processing capacity to ensure your system can handle current and projected workloads.</p>
      <h3>Features</h3>
      <ul>
        <li>View current processing throughput and utilization metrics</li>
        <li>Monitor AWS service quotas and usage against limits</li>
        <li>Set alerts for capacity thresholds to proactively manage scaling</li>
        <li>Plan capacity for anticipated workload increases</li>
        <li>Review service tier configurations and their impact on throughput</li>
      </ul>
    </div>
  </HelpPanel>
);

export default ToolsPanel;
