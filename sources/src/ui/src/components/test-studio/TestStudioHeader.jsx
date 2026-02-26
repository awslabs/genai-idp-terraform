// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import PropTypes from 'prop-types';
import { Header, SpaceBetween, Button } from '@cloudscape-design/components';
import handlePrint from './PrintUtils';

const TestStudioHeader = ({ title, description, showBackButton = true, showPrintButton = false, additionalActions = [], onBackClick }) => {
  const actions = [];

  if (showBackButton) {
    const handleBackClick = onBackClick || (() => window.location.replace('#/test-studio?tab=executions'));

    actions.push(
      <Button key="back" onClick={handleBackClick} iconName="arrow-left">
        Back to Test Results
      </Button>,
    );
  }

  actions.push(...additionalActions);

  if (showPrintButton) {
    actions.push(
      <Button key="print" onClick={handlePrint} iconName="print">
        Print
      </Button>,
    );
  }

  return (
    <Header
      variant="h2"
      actions={
        actions.length > 0 ? (
          <SpaceBetween direction="horizontal" size="xs">
            {actions}
          </SpaceBetween>
        ) : undefined
      }
    >
      {title}
      {description}
    </Header>
  );
};

TestStudioHeader.propTypes = {
  title: PropTypes.string.isRequired,
  description: PropTypes.node,
  showBackButton: PropTypes.bool,
  showPrintButton: PropTypes.bool,
  additionalActions: PropTypes.arrayOf(PropTypes.node),
  onBackClick: PropTypes.func,
};

export default TestStudioHeader;
