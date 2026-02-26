// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import { React } from 'react';
import { useLocation } from 'react-router-dom';
import { SideNavigation } from '@cloudscape-design/components';
import useSettingsContext from '../../contexts/settings';

import {
  DOCUMENTS_PATH,
  DOCUMENTS_KB_QUERY_PATH,
  TEST_STUDIO_PATH,
  DEFAULT_PATH,
  UPLOAD_DOCUMENT_PATH,
  CONFIGURATION_PATH,
  DISCOVERY_PATH,
  AGENT_CHAT_PATH,
} from '../../routes/constants';

export const documentsNavHeader = { text: 'Tools', href: `#${DEFAULT_PATH}` };
export const documentsNavItems = [
  { type: 'link', text: 'Document List', href: `#${DOCUMENTS_PATH}` },
  { type: 'link', text: 'Document KB', href: `#${DOCUMENTS_KB_QUERY_PATH}` },
  { type: 'link', text: 'Upload Document(s)', href: `#${UPLOAD_DOCUMENT_PATH}` },
  { type: 'link', text: 'Discovery', href: `#${DISCOVERY_PATH}` },
  { type: 'link', text: 'View/Edit Configuration', href: `#${CONFIGURATION_PATH}` },
  { type: 'link', text: 'Agent Companion Chat', href: `#${AGENT_CHAT_PATH}` },
  {
    type: 'section',
    text: 'Test Studio',
    items: [
      { type: 'link', text: 'Test Sets', href: `#${TEST_STUDIO_PATH}?tab=sets` },
      { type: 'link', text: 'Test Executions', href: `#${TEST_STUDIO_PATH}?tab=executions` },
    ],
  },
  {
    type: 'section',
    text: 'Resources',
    items: [
      {
        type: 'link',
        text: 'README',
        href: 'https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws/blob/main/README.md',
        external: true,
      },
      {
        type: 'link',
        text: 'Source Code',
        href: 'https://github.com/aws-solutions-library-samples/accelerated-intelligent-document-processing-on-aws',
        external: true,
      },
    ],
  },
];

const defaultOnFollowHandler = (ev) => {
  // Prevent navigation for deployment info items (make them non-clickable)
  if (ev.detail.href === '#deployment-info') {
    ev.preventDefault();
    return;
  }
  // XXX keep the locked href for our demo pages
  // ev.preventDefault();
  console.log(ev);
};

/* eslint-disable react/prop-types */
const Navigation = ({ header = documentsNavHeader, items = documentsNavItems, onFollowHandler = defaultOnFollowHandler }) => {
  const location = useLocation();
  const path = location.pathname;
  let activeHref = `#${DEFAULT_PATH}`;
  const { settings } = useSettingsContext() || {};

  // Determine active link based on current path, most specific routes first
  if (path.includes(CONFIGURATION_PATH)) {
    activeHref = `#${CONFIGURATION_PATH}`;
  } else if (path.includes(DOCUMENTS_KB_QUERY_PATH)) {
    activeHref = `#${DOCUMENTS_KB_QUERY_PATH}`;
  } else if (path.includes(TEST_STUDIO_PATH)) {
    // Handle Test Studio sub-navigation
    const urlParams = new URLSearchParams(location.search);
    const tab = urlParams.get('tab');
    if (tab) {
      activeHref = `#${TEST_STUDIO_PATH}?tab=${tab}`;
    } else {
      activeHref = `#${TEST_STUDIO_PATH}?tab=sets`;
    }
  } else if (path.includes(UPLOAD_DOCUMENT_PATH)) {
    activeHref = `#${UPLOAD_DOCUMENT_PATH}`;
  } else if (path.includes(DISCOVERY_PATH)) {
    activeHref = `#${DISCOVERY_PATH}`;
  } else if (path.includes(DOCUMENTS_PATH)) {
    activeHref = `#${DOCUMENTS_PATH}`;
  } else if (path === AGENT_CHAT_PATH) {
    activeHref = `#${AGENT_CHAT_PATH}`;
  }

  // Create a copy of the items array to add the deployment info
  const navigationItems = [...(items || documentsNavItems)];

  // Add deployment info section if version, stack name, or build datetime is available
  if (settings?.Version || settings?.StackName || settings?.BuildDateTime || settings?.IDPPattern) {
    const deploymentInfoItems = [];

    if (settings?.StackName) {
      deploymentInfoItems.push({
        type: 'link',
        text: `Stack Name: ${settings.StackName}`,
        href: '#stackname',
      });
    }

    if (settings?.Version) {
      deploymentInfoItems.push({
        type: 'link',
        text: `Version: ${settings.Version}`,
        href: '#version',
      });
    }

    if (settings?.BuildDateTime) {
      deploymentInfoItems.push({
        type: 'link',
        text: `Build: ${settings.BuildDateTime}`,
        href: '#builddatetime',
      });
    }

    if (settings?.IDPPattern) {
      const pattern = settings.IDPPattern.split(' ')[0];
      deploymentInfoItems.push({
        type: 'link',
        text: `Pattern: ${pattern}`,
        href: '#idppattern',
      });
    }

    navigationItems.push({
      type: 'section',
      text: 'Deployment Info',
      items: deploymentInfoItems,
    });
  }

  return (
    <SideNavigation items={navigationItems} header={header || documentsNavHeader} activeHref={activeHref} onFollow={onFollowHandler} />
  );
};

export default Navigation;
