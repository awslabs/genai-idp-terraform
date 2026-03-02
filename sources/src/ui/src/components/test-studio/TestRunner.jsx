// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { Container, Header, SpaceBetween, Button, FormField, Select, Alert, Textarea } from '@cloudscape-design/components';
import { generateClient } from 'aws-amplify/api';
import { ConsoleLogger } from 'aws-amplify/utils';
import START_TEST_RUN from '../../graphql/queries/startTestRun';
import GET_TEST_SETS from '../../graphql/queries/getTestSets';
import handlePrint from './PrintUtils';

const client = generateClient();
const logger = new ConsoleLogger('TestRunner');

const TestRunner = ({ onTestStart, onTestComplete, activeTestRuns }) => {
  const [testSets, setTestSets] = useState([]);
  const [selectedTestSet, setSelectedTestSet] = useState(null);
  const [context, setContext] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const loadTestSets = async () => {
    try {
      console.log('TestRunner: Loading test sets...');
      const result = await client.graphql({ query: GET_TEST_SETS });
      console.log('TestRunner: GraphQL result:', result);
      const testSetsData = result.data.getTestSets || [];
      console.log('TestRunner: Test sets data:', testSetsData);
      setTestSets(testSetsData);
    } catch (err) {
      console.error('TestRunner: Failed to load test sets:', err);
      setError(`Failed to load test sets: ${err.message}`);
    }
  };

  React.useEffect(() => {
    loadTestSets();
  }, []);

  const handleRunTest = async () => {
    if (!selectedTestSet) {
      setError('Please select a test set');
      return;
    }

    setLoading(true);
    try {
      const input = {
        testSetId: selectedTestSet.value,
        ...(context && { context }),
      };
      console.log('TestRunner: Starting test run with input:', input);

      const result = await client.graphql({
        query: START_TEST_RUN,
        variables: { input },
      });

      console.log('TestRunner: GraphQL result:', result);

      if (!result?.data?.startTestRun) {
        throw new Error('No response data from startTestRun mutation');
      }

      logger.info('Test run started:', result.data.startTestRun);
      onTestStart(result.data.startTestRun.testRunId, result.data.startTestRun.testSetName, context, result.data.startTestRun.filesCount);
      setError('');
    } catch (err) {
      logger.error('Failed to start test run:', err);
      console.error('TestRunner: Error details:', {
        message: err.message,
        errors: err.errors,
        networkError: err.networkError,
        graphQLErrors: err.graphQLErrors,
      });

      let errorMessage = 'Failed to start test run';
      if (err.errors && err.errors.length > 0) {
        errorMessage = err.errors.map((e) => e.message).join('; ');
      } else if (err.message) {
        errorMessage = err.message;
      }
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const testSetOptions = testSets
    .filter((testSet) => testSet.status === 'COMPLETED')
    .map((testSet) => ({
      label: `${testSet.name}${testSet.filePattern ? ` (${testSet.filePattern})` : ''} - ${testSet.fileCount} ${
        testSet.fileCount === 1 ? 'file' : 'files'
      }`,
      value: testSet.id,
      description: testSet.filePattern ? `Pattern: ${testSet.filePattern}` : 'Uploaded test set',
    }));

  return (
    <Container
      header={
        <Header
          variant="h2"
          description="Select a test set and execute test runs for document processing"
          actions={
            <SpaceBetween direction="horizontal" size="xs">
              <Button variant="primary" onClick={handleRunTest} loading={loading} disabled={!selectedTestSet}>
                Run Test
              </Button>
              <Button onClick={handlePrint} iconName="print">
                Print
              </Button>
            </SpaceBetween>
          }
        >
          Run Test Set
        </Header>
      }
    >
      <SpaceBetween size="l">
        {error && (
          <Alert type="error" dismissible onDismiss={() => setError('')}>
            {error}
          </Alert>
        )}

        <FormField label="Select Test Set" description="Choose an existing test set to run">
          <Select
            selectedOption={selectedTestSet}
            onChange={({ detail }) => setSelectedTestSet(detail.selectedOption)}
            options={testSetOptions}
            placeholder="Choose a test set..."
            empty="No test sets available"
          />
        </FormField>

        <FormField label="Context" description="Optional context information for this test run">
          <Textarea
            value={context}
            onChange={({ detail }) => setContext(detail.value)}
            placeholder="Enter context information..."
            rows={2}
          />
        </FormField>
      </SpaceBetween>
    </Container>
  );
};

TestRunner.propTypes = {
  onTestStart: PropTypes.func.isRequired,
  onTestComplete: PropTypes.func.isRequired,
  activeTestRuns: PropTypes.arrayOf(
    PropTypes.shape({
      testRunId: PropTypes.string.isRequired,
      testSetName: PropTypes.string.isRequired,
      startTime: PropTypes.instanceOf(Date).isRequired,
    }),
  ).isRequired,
};

TestRunner.defaultProps = {};

export default TestRunner;
