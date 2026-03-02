const GET_TEST_RUN_STATUS = `
  query GetTestRunStatus($testRunId: String!) {
    getTestRunStatus(testRunId: $testRunId) {
      testRunId
      status
      progress
      filesCount
      completedFiles
      failedFiles
      evaluatingFiles
    }
  }
`;

export default GET_TEST_RUN_STATUS;
