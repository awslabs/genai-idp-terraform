// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import PropTypes from 'prop-types';
import { SpaceBetween } from '@cloudscape-design/components';
import TestRunner from './TestRunner';
import TestResultsList from './TestResultsList';

const TestExecutions = ({
  timePeriodHours,
  setTimePeriodHours,
  selectedItems,
  setSelectedItems,
  preSelectedTestRunId,
  activeTestRuns,
  onTestStart,
  onTestComplete,
}) => {
  return (
    <SpaceBetween size="l">
      <TestRunner onTestStart={onTestStart} onTestComplete={onTestComplete} activeTestRuns={activeTestRuns} />
      <TestResultsList
        timePeriodHours={timePeriodHours}
        setTimePeriodHours={setTimePeriodHours}
        selectedItems={selectedItems}
        setSelectedItems={setSelectedItems}
        preSelectedTestRunId={preSelectedTestRunId}
        activeTestRuns={activeTestRuns}
        onTestComplete={onTestComplete}
      />
    </SpaceBetween>
  );
};

TestExecutions.propTypes = {
  timePeriodHours: PropTypes.number.isRequired,
  setTimePeriodHours: PropTypes.func.isRequired,
  selectedItems: PropTypes.arrayOf(
    PropTypes.shape({
      testRunId: PropTypes.string,
      testSetName: PropTypes.string,
    }),
  ).isRequired,
  setSelectedItems: PropTypes.func.isRequired,
  preSelectedTestRunId: PropTypes.string,
  activeTestRuns: PropTypes.arrayOf(
    PropTypes.shape({
      testRunId: PropTypes.string.isRequired,
      testSetName: PropTypes.string.isRequired,
      startTime: PropTypes.instanceOf(Date).isRequired,
    }),
  ).isRequired,
  onTestStart: PropTypes.func.isRequired,
  onTestComplete: PropTypes.func.isRequired,
};

export default TestExecutions;
