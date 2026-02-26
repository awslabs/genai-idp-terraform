// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { AppLayout, Flashbar } from '@cloudscape-design/components';
import Navigation from '../genaiidp-layout/navigation';
import GenAIIDPTopNavigation from '../genai-idp-top-navigation/GenAIIDPTopNavigation';
import useNotifications from '../../hooks/use-notifications';
import useAppContext from '../../contexts/app';
import { appLayoutLabels } from '../common/labels';
import ToolsPanel from './tools-panel';

const AgentChatPageLayout = ({ children }) => {
  const { navigationOpen, setNavigationOpen } = useAppContext();
  const notifications = useNotifications();
  const [toolsOpen, setToolsOpen] = useState(true);

  return (
    <>
      <GenAIIDPTopNavigation />
      <AppLayout
        headerSelector="#top-navigation"
        navigation={<Navigation />}
        navigationOpen={navigationOpen}
        onNavigationChange={({ detail }) => setNavigationOpen(detail.open)}
        notifications={<Flashbar items={notifications} />}
        tools={<ToolsPanel />}
        toolsOpen={toolsOpen}
        onToolsChange={({ detail }) => setToolsOpen(detail.open)}
        toolsWidth={350}
        content={children}
        ariaLabels={appLayoutLabels}
      />
    </>
  );
};

AgentChatPageLayout.propTypes = {
  children: PropTypes.node.isRequired,
};

export default AgentChatPageLayout;
