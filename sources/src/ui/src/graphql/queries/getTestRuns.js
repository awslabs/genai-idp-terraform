const GET_TEST_RUNS = `
  query GetTestRuns($timePeriodHours: Int) {
    getTestRuns(timePeriodHours: $timePeriodHours) {
      testRunId
      testSetId
      testSetName
      status
      filesCount
      createdAt
      completedAt
      context
    }
  }
`;

export default GET_TEST_RUNS;
