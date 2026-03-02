// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import gql from 'graphql-tag';

export default gql`
  query GetConfiguration {
    getConfiguration {
      success
      Schema
      Default
      Custom
      error {
        type
        message
        validationErrors {
          field
          message
          type
        }
      }
    }
  }
`;
