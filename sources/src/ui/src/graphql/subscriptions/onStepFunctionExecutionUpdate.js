// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import gql from 'graphql-tag';

const onStepFunctionExecutionUpdate = gql`
  subscription OnStepFunctionExecutionUpdate($executionArn: String!) {
    onStepFunctionExecutionUpdate(executionArn: $executionArn) {
      executionArn
      status
      startDate
      stopDate
      input
      output
      steps {
        name
        type
        status
        startDate
        stopDate
        input
        output
        error
      }
    }
  }
`;

export default onStepFunctionExecutionUpdate;
